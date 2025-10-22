//
//  MarkdownEditor.swift
//  InkSlate
//
//  Full WYSIWYG Markdown-style editor (UIKit UITextView inside SwiftUI)
//

import SwiftUI
import UIKit
import Foundation
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Theme

struct EditorTheme {
    static var baseFont: UIFont { UIFont.preferredFont(forTextStyle: .body) }
    static func font(size: CGFloat, weight: UIFont.Weight = .regular, italic: Bool = false) -> UIFont {
        var f = UIFont.systemFont(ofSize: size, weight: weight)
        if italic, let d = f.fontDescriptor.withSymbolicTraits(.traitItalic) {
            f = UIFont(descriptor: d, size: size)
        }
        return f
    }
    static var textColor: UIColor { .label }
    static var linkColor: UIColor { .systemBlue }
    static var codeBG: UIColor { .systemGray6 }
    static var quoteBG: UIColor { .systemGray6 }
    static var codeBlockBG: UIColor { .secondarySystemBackground }
}

// MARK: - Custom Attributes

extension NSAttributedString.Key {
    static let codeBlock = NSAttributedString.Key("codeBlockAttribute")
}

// MARK: - Markdown Actions

enum MarkdownAction: Int, CaseIterable, Hashable {
    case bold = 0, italic, strikethrough, code, underline
    case removeFormat
    case header1, header2, header3, header4, header5, header6
    case paragraph, horizontalRule
    case bulletList, numberedList, indent, outdent
    case alignLeft, alignCenter, alignRight, alignJustify
    case link, removeLink, quickLink, image, blockquote
    case undo, redo, find, findToggle
    case indentAction, outdentAction, codeBlock
    case textLarger, textSmaller, textColor, backgroundColor
    case fontFamily, viewSource, customCSS
}

// MARK: - Global editor state & notifications

private weak var activeCoordinator: MarkdownEditor.Coordinator?

extension Notification.Name {
    static let editorActiveStylesDidChange = Notification.Name("EditorActiveStylesDidChange")
}

// Which actions behave as persistent typing modes
private let persistentTypingActions: Set<MarkdownAction> = [
    .bold, .italic, .underline, .strikethrough, .code,
    .bulletList, .numberedList, .blockquote, .codeBlock
]

// MARK: - UIViewRepresentable

struct MarkdownEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    @Binding var coordinatorRef: Coordinator?
    
    func makeUIView(context: Context) -> EditorTextView {
        let textView = EditorTextView()

        // Base appearance
        textView.backgroundColor = .systemBackground
        textView.textContainerInset = UIEdgeInsets(top: 13, left: 10, bottom: 13, right: 10)
        textView.alwaysBounceVertical = true
        textView.keyboardDismissMode = .interactive
        textView.adjustsFontForContentSizeCategory = true
        textView.layoutManager.allowsNonContiguousLayout = true
        textView.allowsEditingTextAttributes = true
        textView.dataDetectorTypes = [.link]
        textView.isScrollEnabled = true
        textView.isUserInteractionEnabled = true

        // Behavior
        textView.delegate = context.coordinator
        textView.pasteDelegate = context.coordinator
        textView.undoManager?.levelsOfUndo = 50

        // Drag & drop (images and plain text)
        textView.addInteraction(UIDropInteraction(delegate: context.coordinator))

        // Initial text
        let base = NSAttributedString(string: text, attributes: [
            .font: EditorTheme.baseFont,
            .foregroundColor: EditorTheme.textColor
        ])
        textView.attributedText = base
        
        // Keep references
        context.coordinator.textView = textView
        activeCoordinator = context.coordinator

        // Seed typing attributes and toolbar state
        context.coordinator.applyTypingAttributes(in: textView)
        NotificationCenter.default.post(name: .editorActiveStylesDidChange, object: nil,
                                        userInfo: ["styles": context.coordinator.currentActiveStyles(in: textView)])

        // Show keyboard immediately
        DispatchQueue.main.async { textView.becomeFirstResponder() }
        
        return textView
    }
    
    func updateUIView(_ uiView: EditorTextView, context: Context) {
        guard !uiView.isFirstResponder else { return } // prevent overwriting during active editing

        context.coordinator.textView = uiView
        if uiView.attributedText.string != text {
            let range = uiView.selectedRange
            uiView.attributedText = NSAttributedString(string: text, attributes: [
                .font: EditorTheme.baseFont,
                .foregroundColor: EditorTheme.textColor
            ])
            if range.location <= uiView.attributedText.length {
                uiView.selectedRange = range
            }
        }

        if uiView.selectedRange != selectedRange {
            uiView.selectedRange = selectedRange
        }
    }

    func makeCoordinator() -> Coordinator { 
        let coord = Coordinator(self)
        DispatchQueue.main.async {
            self.coordinatorRef = coord
        }
        return coord
    }
    
    // MARK: - Coordinator

    class Coordinator: NSObject, UITextViewDelegate, UITextPasteDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIDropInteractionDelegate {
        var parent: MarkdownEditor
        weak var textView: EditorTextView?
        private var isProgrammaticChange = false

        // Autosave debounce
        private var saveWorkItem: DispatchWorkItem?
        
        // Persistent typing modes (see persistentTypingActions)
        fileprivate var typingModes = Set<MarkdownAction>()

        init(_ parent: MarkdownEditor) { self.parent = parent }

        // MARK: Text changes
        
        func textViewDidChange(_ textView: UITextView) {
            guard !isProgrammaticChange else { return }
            parent.text = textView.attributedText.string
            parent.selectedRange = textView.selectedRange
            NotificationCenter.default.post(name: .editorActiveStylesDidChange, object: nil,
                                            userInfo: ["styles": currentActiveStyles(in: textView)])

            saveWorkItem?.cancel()
            let work = DispatchWorkItem { /* Persist here if desired */ }
            saveWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selectedRange = textView.selectedRange
            (textView as? EditorTextView)?.registerLinkMenuItems()
            NotificationCenter.default.post(name: .editorActiveStylesDidChange, object: nil,
                                            userInfo: ["styles": currentActiveStyles(in: textView)])
        }

        func textView(_ tv: UITextView, shouldChangeTextIn range: NSRange, replacementText string: String) -> Bool {
            if string == "\n" { if WysiwygActionHandler.handleReturn(in: tv as! EditorTextView) { return false } }
            return true
        }

        // MARK: Paste sanitization + image paste
        func textPasteConfigurationSupporting(_ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting, transform item: UITextPasteItem) {
            if item.itemProvider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                item.setDefaultResult()
            } else if item.itemProvider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                item.itemProvider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { obj, _ in
                    if let s = obj as? String { item.setResult(string: s) } else { item.setDefaultResult() }
                }
            } else if item.itemProvider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                item.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] obj, _ in
                    guard let img = obj as? UIImage, let tv = self?.textView else { return }
                    DispatchQueue.main.async { WysiwygActionHandler.insertImage(img, into: tv) }
                }
            } else {
                item.setDefaultResult()
            }
        }

        // MARK: Actions routing
        
        func handleMarkdownAction(_ action: MarkdownAction) {
            guard let tv = textView else { return }

            switch action {
            case .undo: tv.undoManager?.undo(); return
            case .redo: tv.undoManager?.redo(); return
            default: break
            }

            // Reset typing modes when removing formatting or switching block types
            if action == .removeFormat || action == .paragraph || action == .header1 || action == .header2 || action == .header3 {
                typingModes.removeAll()
                applyTypingAttributes(in: tv)
            }

            // Only group operations that make multiple changes
            let shouldGroup: Bool = {
                switch action {
                case .header1, .header2, .header3, .header4, .header5, .header6:
                    return true // Headers change font + paragraph style
                case .bulletList, .numberedList, .blockquote, .codeBlock:
                    return true // These modify line prefix + formatting
                case .removeFormat:
                    return true // Removes multiple attributes
                default:
                    return false // Simple toggles don't need grouping
                }
            }()

            if shouldGroup { tv.undoManager?.beginUndoGrouping() }
            isProgrammaticChange = true
            defer {
                isProgrammaticChange = false
                if shouldGroup { tv.undoManager?.endUndoGrouping() }
            }

            tv.undoManager?.setActionName(actionName(for: action))
                WysiwygActionHandler.apply(action, to: tv)

            // Sync to bindings & toolbar
            parent.text = tv.attributedText.string
            parent.selectedRange = tv.selectedRange
            NotificationCenter.default.post(name: .editorActiveStylesDidChange, object: nil,
                                            userInfo: ["styles": currentActiveStyles(in: tv)])
        }
        
        func topViewController() -> UIViewController? {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else { return nil }
            return window.rootViewController?.topMostViewController()
        }

        private func actionName(for action: MarkdownAction) -> String {
            switch action {
            case .bold: return "Bold"
            case .italic: return "Italic"
            case .underline: return "Underline"
            case .strikethrough: return "Strikethrough"
            case .code: return "Code"
            case .header1: return "Header 1"
            case .header2: return "Header 2"
            case .header3: return "Header 3"
            case .bulletList: return "Bullet List"
            case .numberedList: return "Numbered List"
            case .blockquote: return "Blockquote"
            case .indent, .indentAction: return "Indent"
            case .outdent, .outdentAction: return "Outdent"
            case .codeBlock: return "Code Block"
            case .image: return "Insert Image"
            case .find, .findToggle: return "Find"
            default: return "Edit"
            }
        }

        // MARK: Link prompt

        func promptForLink(_ textView: UITextView) {
            let alert = UIAlertController(title: "Add Link", message: nil, preferredStyle: .alert)
            alert.addTextField { 
                $0.placeholder = "https://example.com"
                $0.keyboardType = .URL
                $0.autocorrectionType = .no
                $0.autocapitalizationType = .none
            }
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
                guard let self = self else { return }
                
                var urlString = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                // Add https:// if no scheme present
                if !urlString.isEmpty && !urlString.contains("://") {
                    urlString = "https://" + urlString
                }
                
                // Validate URL
                guard !urlString.isEmpty, 
                      let url = URL(string: urlString),
                      url.scheme != nil else {
                    let errorAlert = UIAlertController(
                        title: "Invalid URL", 
                        message: "Please enter a valid URL (e.g., https://example.com)", 
                        preferredStyle: .alert
                    )
                    errorAlert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.topViewController()?.present(errorAlert, animated: true)
                    return
                }
                
                let sel = textView.selectedRange
                if sel.length == 0 {
                    // No selection - insert link text
                    let linkText = url.host ?? urlString
                let attr = NSMutableAttributedString(attributedString: textView.attributedText)
                    let insertion = NSAttributedString(string: linkText, attributes: [
                        .link: url,
                        .foregroundColor: EditorTheme.linkColor,
                        .underlineStyle: NSUnderlineStyle.single.rawValue
                    ])
                    attr.insert(insertion, at: sel.location)
                    textView.attributedText = attr
                    textView.selectedRange = NSRange(location: sel.location + insertion.length, length: 0)
                } else {
                    // Selection exists - apply link to selection
                    let attr = NSMutableAttributedString(attributedString: textView.attributedText)
                    attr.addAttribute(.link, value: url, range: sel)
                    attr.addAttribute(.foregroundColor, value: EditorTheme.linkColor, range: sel)
                    attr.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: sel)
                textView.attributedText = attr
                textView.selectedRange = sel
                }
            })
            topViewController()?.present(alert, animated: true)
        }

        // MARK: Image picker

        private func presentImagePicker() {
            guard textView != nil else { return }
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .photoLibrary
            topViewController()?.present(picker, animated: true)
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            picker.dismiss(animated: true)
            guard let img = (info[.editedImage] ?? info[.originalImage]) as? UIImage,
                  let tv = textView else { return }
            WysiwygActionHandler.insertImage(img, into: tv)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) }

        // MARK: UIDropInteractionDelegate

        func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
            return session.hasItemsConforming(toTypeIdentifiers: [UTType.image.identifier, UTType.text.identifier, UTType.plainText.identifier])
        }
        func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal { UIDropProposal(operation: .copy) }
        func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
            guard let tv = textView else { return }
            session.loadObjects(ofClass: UIImage.self) { items in
                if let images = items as? [UIImage], let img = images.first { WysiwygActionHandler.insertImage(img, into: tv) }
            }
        }

        // MARK: Helpers

        fileprivate func setTypingMode(_ action: MarkdownAction, enabled: Bool, in tv: UITextView) {
            if enabled { typingModes.insert(action) } else { typingModes.remove(action) }
            applyTypingAttributes(in: tv)
        }

        fileprivate func applyTypingAttributes(in tv: UITextView) {
            var attrs = tv.typingAttributes
            if attrs[.font] == nil { attrs[.font] = EditorTheme.baseFont }
            if attrs[.foregroundColor] == nil { attrs[.foregroundColor] = EditorTheme.textColor }

            let baseFont = (attrs[.font] as? UIFont) ?? EditorTheme.baseFont
            var descriptor = baseFont.fontDescriptor
            var traits: UIFontDescriptor.SymbolicTraits = []
            
            if typingModes.contains(.bold) { traits.insert(.traitBold) }
            if typingModes.contains(.italic) { traits.insert(.traitItalic) }
            
            // CRITICAL: Handle the case where withSymbolicTraits returns nil
            if let newDescriptor = descriptor.withSymbolicTraits(traits) {
                descriptor = newDescriptor
            }
            // If it returns nil, traits couldn't be combined - try a different approach
            else if !traits.isEmpty {
                // Fallback: create a new font with the desired traits
                if traits.contains(.traitBold) && traits.contains(.traitItalic) {
                    // For bold+italic, we need to explicitly create it
                    let boldFont = UIFont.systemFont(ofSize: baseFont.pointSize, weight: .bold)
                    if let italicDesc = boldFont.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) {
                        descriptor = italicDesc
                    } else {
                        // Ultimate fallback: use system font with weight
                        descriptor = UIFont.boldSystemFont(ofSize: baseFont.pointSize).fontDescriptor
                    }
                } else if traits.contains(.traitBold) {
                    descriptor = UIFont.boldSystemFont(ofSize: baseFont.pointSize).fontDescriptor
                } else if traits.contains(.traitItalic) {
                    descriptor = UIFont.italicSystemFont(ofSize: baseFont.pointSize).fontDescriptor
                }
            }
            
            let sized = UIFont(descriptor: descriptor, size: baseFont.pointSize)
            attrs[.font] = sized

            attrs[.underlineStyle] = typingModes.contains(.underline) ? NSUnderlineStyle.single.rawValue : nil
            attrs[.strikethroughStyle] = typingModes.contains(.strikethrough) ? NSUnderlineStyle.single.rawValue : nil

            if typingModes.contains(.code) {
                attrs[.backgroundColor] = EditorTheme.codeBG
                attrs[.font] = UIFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular)
            } else {
                attrs[.backgroundColor] = nil
            }

            tv.typingAttributes = attrs
        }

        fileprivate func currentActiveStyles(in tv: UITextView) -> Set<MarkdownAction> {
            var set = typingModes
            let idx = max(0, min(tv.selectedRange.location, max(0, tv.attributedText.length - 1)))
            let attrs = tv.attributedText.length > 0 ? tv.attributedText.attributes(at: idx, effectiveRange: nil) : tv.typingAttributes

            if let f = (attrs[.font] as? UIFont) {
                if f.fontDescriptor.symbolicTraits.contains(.traitBold) { set.insert(.bold) } else { set.remove(.bold) }
                if f.fontDescriptor.symbolicTraits.contains(.traitItalic) { set.insert(.italic) } else { set.remove(.italic) }
                if f.fontName.lowercased().contains("mono") || (attrs[.backgroundColor] as? UIColor) == EditorTheme.codeBG { set.insert(.code) } else { set.remove(.code) }
            }
            if (attrs[.underlineStyle] as? Int) == NSUnderlineStyle.single.rawValue { set.insert(.underline) } else { set.remove(.underline) }
            if (attrs[.strikethroughStyle] as? Int) == NSUnderlineStyle.single.rawValue { set.insert(.strikethrough) } else { set.remove(.strikethrough) }

            // Paragraph hints based on text prefixes
            let line = (tv as? EditorTextView)?.currentLineString() ?? ""
            if line.hasPrefix("• ") { set.insert(.bulletList) } else { set.remove(.bulletList) }
            if line.range(of: #"^\d+\. "#, options: .regularExpression) != nil { set.insert(.numberedList) } else { set.remove(.numberedList) }
            if line.hasPrefix("> ") { set.insert(.blockquote) } else { set.remove(.blockquote) }
            if line.hasPrefix("```") { set.insert(.codeBlock) } else { set.remove(.codeBlock) }

            return set
        }

        private func topViewController(base: UIViewController? = nil) -> UIViewController? {
            let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            let root = base ?? scene?.keyWindow?.rootViewController
            if let nav = root as? UINavigationController { return topViewController(base: nav.visibleViewController) }
            if let tab = root as? UITabBarController { return topViewController(base: tab.selectedViewController) }
            if let presented = root?.presentedViewController { return topViewController(base: presented) }
            return root
        }
    }
}

// MARK: - Custom UITextView for find bar host + link menu + image reflow

final class EditorTextView: UITextView {
    private var findBar: FindReplaceBar?
    private var findBarBottomConstraint: NSLayoutConstraint?
    private var lastLayoutWidth: CGFloat = 0

    // Keep find bar above keyboard using keyboardLayoutGuide (iOS 15+)
    func toggleFindBar(show: Bool?) {
        let shouldShow: Bool = {
            if let s = show { return s }
            return findBar == nil
        }()

        if shouldShow {
        if findBar == nil {
            let bar = FindReplaceBar()
            bar.translatesAutoresizingMaskIntoConstraints = false
            addSubview(bar)

                let kbdGuide = keyboardLayoutGuide
                findBarBottomConstraint = bar.bottomAnchor.constraint(equalTo: kbdGuide.topAnchor)
            NSLayoutConstraint.activate([
                bar.leadingAnchor.constraint(equalTo: leadingAnchor),
                bar.trailingAnchor.constraint(equalTo: trailingAnchor),
                    findBarBottomConstraint!
            ])

                bar.onFindNext = { [weak self] query in self?.findNext(query: query) }
                bar.onReplace = { [weak self] query, replacement in self?.replaceCurrent(query: query, replacement: replacement) }
                bar.onClose = { [weak self] in self?.toggleFindBar(show: false) }
            findBar = bar
            }
            let extra = findBar?.bounds.height ?? 52
            contentInset.bottom = extra + 4
            verticalScrollIndicatorInsets.bottom = extra + 4
        } else {
            findBar?.removeFromSuperview(); findBar = nil
            contentInset.bottom = 0
            verticalScrollIndicatorInsets.bottom = 0
        }
    }

    private func findNext(query: String) {
        guard !query.isEmpty else { return }
        let s = attributedText.string as NSString
        let start = selectedRange.location + selectedRange.length
        let searchRange = NSRange(location: start, length: max(0, s.length - start))
        let firstRange = s.range(of: query, options: .caseInsensitive, range: searchRange)
        let secondRange = s.range(of: query, options: .caseInsensitive, range: NSRange(location: 0, length: s.length))
        if let r = (firstRange.location != NSNotFound ? firstRange : nil) ?? (secondRange.location != NSNotFound ? secondRange : nil) {
            selectedRange = r; scrollRangeToVisible(r)
        }
    }

    private func replaceCurrent(query: String, replacement: String) {
        guard !query.isEmpty else { return }
        let s = attributedText.string as NSString
        let r = selectedRange
        if r.length > 0, s.substring(with: r).localizedCaseInsensitiveContains(query) {
            let m = NSMutableAttributedString(attributedString: attributedText)
            m.replaceCharacters(in: r, with: NSAttributedString(string: replacement, attributes: WysiwygActionHandler.baseAttributes(from: attributedText, at: r.location)))
            attributedText = m
            selectedRange = NSRange(location: r.location + (replacement as NSString).length, length: 0)
        } else {
            findNext(query: query)
        }
    }

    // Recompute image attachment sizes on rotation/layout changes with a dirty flag
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Only recalculate when width actually changes
        let currentWidth = bounds.width - textContainerInset.left - textContainerInset.right - 8
        guard abs(currentWidth - lastLayoutWidth) > 1 else { return }
        lastLayoutWidth = currentWidth
        
        guard let att = self.attributedText else { return }
        let m = NSMutableAttributedString(attributedString: att)
        var didModify = false
        
        m.enumerateAttribute(.attachment, in: NSRange(location: 0, length: m.length)) { value, _, _ in
            guard let ta = value as? NSTextAttachment,
                  let img = ta.image ?? ta.image(forBounds: ta.bounds, textContainer: nil, characterIndex: 0) else { return }
            
                let aspect = img.size.height / img.size.width
            let width = min(img.size.width, currentWidth)
                let height = width * aspect
            
            if abs(ta.bounds.width - width) > 0.5 {
                    ta.bounds = CGRect(x: 0, y: 0, width: width, height: height)
                    didModify = true
                }
            }
        
        if didModify { self.attributedText = m }
    }

    func visibleGlyphRange() -> NSRange {
        let lm = layoutManager; let tc = textContainer
        let rect = CGRect(origin: contentOffset, size: bounds.size).insetBy(dx: 0, dy: -200)
        return lm.glyphRange(forBoundingRect: rect, in: tc)
    }
    func visibleCharacterRange() -> NSRange {
        let g = visibleGlyphRange(); return layoutManager.characterRange(forGlyphRange: g, actualGlyphRange: nil)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            NotificationCenter.default.addObserver(self, selector: #selector(kbWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        } else {
            NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillHideNotification, object: nil)
        }
    }
    @objc private func kbWillHide(_ note: Notification) {
        findBar?.removeFromSuperview(); findBar = nil
        contentInset.bottom = 0; verticalScrollIndicatorInsets.bottom = 0
    }

    // MARK: Link context menu

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(editLink) || action == #selector(removeLink) { return currentLinkRange() != nil }
        return super.canPerformAction(action, withSender: sender)
    }

    @objc func editLink() {
        guard let r = currentLinkRange(),
              let url = attributedText.attribute(.link, at: r.location, effectiveRange: nil) as? URL else { return }
        let alert = UIAlertController(title: "Edit Link", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in tf.text = url.absoluteString }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self, let s = alert.textFields?.first?.text, let newURL = URL(string: s) else { return }
            let m = NSMutableAttributedString(attributedString: self.attributedText)
            m.addAttribute(.link, value: newURL, range: r)
            self.attributedText = m
        })
        topViewController()?.present(alert, animated: true)
    }

    @objc func removeLink() {
        guard let r = currentLinkRange() else { return }
        let m = NSMutableAttributedString(attributedString: attributedText)
        m.removeAttribute(.link, range: r)
        m.removeAttribute(.underlineStyle, range: r)
        m.addAttribute(.foregroundColor, value: EditorTheme.textColor, range: r)
        attributedText = m
    }

    func registerLinkMenuItems() {
        if #available(iOS 16.0, *) {
            // System edit menu is fine; no custom items needed
        } else {
            UIMenuController.shared.menuItems = [
                UIMenuItem(title: "Edit Link", action: #selector(editLink)),
                UIMenuItem(title: "Remove Link", action: #selector(removeLink))
            ]
        }
    }

    private func currentLinkRange() -> NSRange? {
        guard attributedText.length > 0 else { return nil }
        let idx = max(0, min(selectedRange.location, attributedText.length - 1))
        var r = NSRange(location: 0, length: 0)
        if attributedText.attribute(.link, at: idx, effectiveRange: &r) != nil { return r }
        return nil
    }

    // Line utilities used by handlers
    func currentLineRange() -> NSRange {
        let ns = attributedText.string as NSString
        let idx = min(selectedRange.location, ns.length)
        return ns.lineRange(for: NSRange(location: idx, length: 0))
    }
    func currentLineString() -> String {
        let ns = attributedText.string as NSString
        return ns.substring(with: currentLineRange())
    }

    private func topViewController(base: UIViewController? = nil) -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let root = base ?? scene?.keyWindow?.rootViewController
        if let nav = root as? UINavigationController { return topViewController(base: nav.visibleViewController) }
        if let tab = root as? UITabBarController { return topViewController(base: tab.selectedViewController) }
        if let presented = root?.presentedViewController { return topViewController(base: presented) }
        return root
    }
}

// MARK: - Simple Find/Replace bar view

final class FindReplaceBar: UIView {
    let findField = UITextField()
    let replaceField = UITextField()
    let findNextBtn = UIButton(type: .system)
    let replaceBtn = UIButton(type: .system)
    let closeBtn = UIButton(type: .system)

    var onFindNext: ((String) -> Void)?
    var onReplace: ((String, String) -> Void)?
    var onClose: (() -> Void)?

    override init(frame: CGRect) { super.init(frame: frame); setup() }
    required init?(coder: NSCoder) { super.init(coder: coder); setup() }

    private func setup() {
        backgroundColor = UIColor.systemGray6
        layer.borderColor = UIColor.separator.cgColor
        layer.borderWidth = 0.5

        findField.placeholder = "Find"
        replaceField.placeholder = "Replace"
        [findField, replaceField].forEach {
            $0.borderStyle = .roundedRect
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.clearButtonMode = .whileEditing
            addSubview($0)
        }

        findNextBtn.setTitle("Find Next", for: .normal)
        replaceBtn.setTitle("Replace", for: .normal)
        closeBtn.setTitle("✕", for: .normal)
        [findNextBtn, replaceBtn, closeBtn].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; addSubview($0) }

        findNextBtn.addAction(UIAction { [weak self] _ in
            guard let q = self?.findField.text else { return }
            self?.onFindNext?(q)
        }, for: .touchUpInside)
        replaceBtn.addAction(UIAction { [weak self] _ in
            guard let q = self?.findField.text, let r = self?.replaceField.text else { return }
            self?.onReplace?(q, r)
        }, for: .touchUpInside)
        closeBtn.addAction(UIAction { [weak self] _ in self?.onClose?() }, for: .touchUpInside)

        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 54),

            findField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            findField.centerYAnchor.constraint(equalTo: centerYAnchor),
            findField.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.30),

            replaceField.leadingAnchor.constraint(equalTo: findField.trailingAnchor, constant: 8),
            replaceField.centerYAnchor.constraint(equalTo: centerYAnchor),
            replaceField.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.30),

            findNextBtn.leadingAnchor.constraint(equalTo: replaceField.trailingAnchor, constant: 8),
            findNextBtn.centerYAnchor.constraint(equalTo: centerYAnchor),

            replaceBtn.leadingAnchor.constraint(equalTo: findNextBtn.trailingAnchor, constant: 8),
            replaceBtn.centerYAnchor.constraint(equalTo: centerYAnchor),

            closeBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            closeBtn.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }
}

// MARK: - WYSIWYG Action Handler

class WysiwygActionHandler {
    // Return behavior for lists, quotes, code fences
    static func handleReturn(in textView: EditorTextView) -> Bool {
        let lineR = textView.currentLineRange()
        let ns = textView.attributedText.string as NSString
        let line = ns.substring(with: lineR)

        // Bullet list
        if line.hasPrefix("• ") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "•" || trimmed == "• " || trimmed == "•" {
                let m = NSMutableAttributedString(attributedString: textView.attributedText)
                m.replaceCharacters(in: lineR, with: "")
                textView.attributedText = m
                textView.selectedRange = NSRange(location: lineR.location, length: 0)
                return true
            } else {
                textView.insertText("\n• ")
                return true
            }
        }

        // Numbered list
        if let match = line.range(of: #"^(\d+)\. "#, options: .regularExpression) {
            let nsLine = line as NSString
            let matchRange = NSRange(match, in: line)
            
            // Extract just the number part correctly
            let prefix = nsLine.substring(with: matchRange) // e.g., "1. "
            let numStr = prefix.replacingOccurrences(of: ". ", with: "").trimmingCharacters(in: .whitespaces)
            
            let after = String(line.dropFirst(prefix.count))
            if after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Empty line - remove numbering
                let m = NSMutableAttributedString(attributedString: textView.attributedText)
                m.replaceCharacters(in: lineR, with: "")
                textView.attributedText = m
                textView.selectedRange = NSRange(location: lineR.location, length: 0)
                return true
            } else {
                // Continue numbering
                if let n = Int(numStr) {
                    textView.insertText("\n\(n + 1). ")
                    return true
                }
            }
        }

        // Blockquote
        if line.hasPrefix("> ") {
            let after = String(line.dropFirst(2))
            if after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let m = NSMutableAttributedString(attributedString: textView.attributedText)
                m.replaceCharacters(in: lineR, with: "")
                textView.attributedText = m
                textView.selectedRange = NSRange(location: lineR.location, length: 0)
                return true
            } else {
                textView.insertText("\n> ")
                return true
            }
        }

        return false
    }
    
    static func apply(_ action: MarkdownAction, to textView: UITextView) {
        guard let coord = activeCoordinator else { return }
        let range = textView.selectedRange
        let hasSelection = range.length > 0

        // Paragraph-like actions
        if action == .bulletList || action == .numberedList || action == .blockquote || action == .codeBlock {
            applyParagraphAction(action, tv: textView)
            let currentlyOn = coord.typingModes.contains(action)
            coord.setTypingMode(action, enabled: !currentlyOn, in: textView)
            NotificationCenter.default.post(name: .editorActiveStylesDidChange, object: nil,
                                            userInfo: ["styles": coord.currentActiveStyles(in: textView)])
            return
        }

        // Header actions -> real font sizing/weight applied to paragraph
        if action == .header1 || action == .header2 || action == .header3 {
            applyHeader(action, tv: textView)
            NotificationCenter.default.post(name: .editorActiveStylesDidChange, object: nil,
                                            userInfo: ["styles": coord.currentActiveStyles(in: textView)])
            return
        }

        if hasSelection {
            let m = NSMutableAttributedString(attributedString: textView.attributedText)
        switch action {
            case .bold: toggleFontTrait(.traitBold, in: m, range: range)
            case .italic: toggleFontTrait(.traitItalic, in: m, range: range)
            case .underline: toggleSimple(.underlineStyle, value: NSUnderlineStyle.single.rawValue, in: m, range: range)
            case .strikethrough: toggleSimple(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, in: m, range: range)
            case .code: toggleInlineCode(in: m, range: range)
            case .removeFormat: removeAllFormatting(in: m, range: range)
            case .textColor: promptForTextColor(textView)
            case .backgroundColor: promptForBackgroundColor(textView)
            case .alignLeft: setTextAlignment(.left, in: m, range: range)
            case .alignCenter: setTextAlignment(.center, in: m, range: range)
            case .alignRight: setTextAlignment(.right, in: m, range: range)
            case .alignJustify: setTextAlignment(.justified, in: m, range: range)
            case .horizontalRule: insertHorizontalRule(in: m, range: range)
            case .paragraph: setParagraph(in: m, range: range)
            case .header4: applyHeader(level: 4, in: m, range: range)
            case .header5: applyHeader(level: 5, in: m, range: range)
            case .header6: applyHeader(level: 6, in: m, range: range)
            case .quickLink: createQuickLink(in: m, range: range)
            case .removeLink: removeLink(in: m, range: range)
            case .fontFamily: promptForFontFamily(textView)
            case .viewSource: toggleSourceView(textView)
            case .indent, .indentAction: indent(in: m, around: range)
            case .outdent, .outdentAction: outdent(in: m, around: range)
        case .link:
                if let coord = activeCoordinator {
                    coord.promptForLink(textView)
                }
                return
        case .image:
                // TODO: Implement image picker
                print("Image picker not yet implemented")
                return
            default: break
            }
            textView.attributedText = m
            textView.selectedRange = NSRange(location: range.location, length: range.length)
            coord.applyTypingAttributes(in: textView)
        } else {
            // No selection: this becomes a persistent typing mode
            let shouldEnable = !coord.typingModes.contains(action)
            coord.setTypingMode(action, enabled: shouldEnable, in: textView)
        }
    }

    // MARK: Headers (real paragraph formatting)

    private static func applyHeader(_ action: MarkdownAction, tv: UITextView) {
        let sizes: (CGFloat, UIFont.Weight) = {
            switch action {
            case .header1: return (28, .bold)
            case .header2: return (22, .semibold)
            case .header3: return (18, .semibold)
            default: return (EditorTheme.baseFont.pointSize, .regular)
            }
        }()
        
        let lineR = (tv as? EditorTextView)?.currentLineRange() ?? tv.selectedRange
        let m = NSMutableAttributedString(attributedString: tv.attributedText)
        
        // Enumerate all attributes to preserve paragraph styles
        m.enumerateAttributes(in: lineR, options: []) { attrs, r, _ in
            // Preserve existing paragraph style or create new one
            let existingStyle = attrs[.paragraphStyle] as? NSParagraphStyle
            let newStyle = (existingStyle?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            
            // Only update header-specific spacing
            newStyle.lineSpacing = 6
            newStyle.paragraphSpacingBefore = 8
            newStyle.paragraphSpacing = 8
            // Note: alignment, indentation, etc. are preserved automatically
            
            let newFont = UIFont.systemFont(ofSize: sizes.0, weight: sizes.1)
            m.addAttributes([.font: newFont, .paragraphStyle: newStyle], range: r)
        }
        
        tv.attributedText = m
        tv.selectedRange = NSRange(location: lineR.location, length: 0)
    }

    // MARK: Attribute toggles

    private static func toggleFontTrait(_ trait: UIFontDescriptor.SymbolicTraits, 
                                       in m: NSMutableAttributedString, 
                                       range: NSRange) {
        // Toggle trait individually per range (like Word does)
        m.enumerateAttribute(.font, in: range, options: []) { value, r, _ in
            let base = (value as? UIFont) ?? EditorTheme.baseFont
            var traits = base.fontDescriptor.symbolicTraits
            
            // Toggle individually per range
            if traits.contains(trait) {
                traits.remove(trait)
            } else {
                traits.insert(trait)
            }
            
            // Robust font creation with proper fallback handling
            let newFont: UIFont
            if let descriptor = base.fontDescriptor.withSymbolicTraits(traits) {
                newFont = UIFont(descriptor: descriptor, size: base.pointSize)
            } else {
                // Fallback: manually combine traits when withSymbolicTraits fails
                if traits.contains(.traitBold) && traits.contains(.traitItalic) {
                    // For bold+italic combination
                    let boldFont = UIFont.systemFont(ofSize: base.pointSize, weight: .bold)
                    if let italicDescriptor = boldFont.fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) {
                        newFont = UIFont(descriptor: italicDescriptor, size: base.pointSize)
                    } else {
                        // Ultimate fallback
                        newFont = UIFont.boldSystemFont(ofSize: base.pointSize)
                    }
                } else if traits.contains(.traitBold) {
                    newFont = UIFont.boldSystemFont(ofSize: base.pointSize)
                } else if traits.contains(.traitItalic) {
                    newFont = UIFont.italicSystemFont(ofSize: base.pointSize)
                } else {
                    newFont = UIFont.systemFont(ofSize: base.pointSize)
                }
            }
            m.addAttribute(.font, value: newFont, range: r)
        }
    }

    private static func toggleSimple(_ key: NSAttributedString.Key, value: Any, in m: NSMutableAttributedString, range: NSRange) {
        // Toggle individually per range
        m.enumerateAttribute(key, in: range, options: []) { existing, r, _ in
            if existing != nil {
                // Remove if present in this range
                m.removeAttribute(key, range: r)
            } else {
                // Add if not present in this range
                m.addAttribute(key, value: value, range: r)
            }
        }
    }

    private static func toggleInlineCode(in m: NSMutableAttributedString, range: NSRange) {
        // Toggle individually per range
        m.enumerateAttributes(in: range, options: []) { attrs, r, _ in
            let hasCode = (attrs[.backgroundColor] as? UIColor) == EditorTheme.codeBG
            
            var a = attrs
            if hasCode {
                // Remove code formatting from this range
                a[.backgroundColor] = nil
                if let f = a[.font] as? UIFont {
                    // Restore non-monospace font, preserving size
                    a[.font] = UIFont.systemFont(ofSize: f.pointSize)
                }
            } else {
                // Add code formatting to this range
                a[.backgroundColor] = EditorTheme.codeBG
                let base = (a[.font] as? UIFont) ?? EditorTheme.baseFont
                a[.font] = UIFont.monospacedSystemFont(ofSize: base.pointSize, weight: .regular)
            }
            m.setAttributes(a, range: r)
        }
    }

    // MARK: Indent/Outdent

    private static func indent(in m: NSMutableAttributedString, around range: NSRange) {
        m.enumerateAttribute(.paragraphStyle, in: range) { value, r, _ in
            let style = (value as? NSMutableParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            style.headIndent += 20
            style.firstLineHeadIndent += 20
            m.addAttribute(.paragraphStyle, value: style, range: r)
        }
    }

    private static func outdent(in m: NSMutableAttributedString, around range: NSRange) {
        m.enumerateAttribute(.paragraphStyle, in: range) { value, r, _ in
            let style = (value as? NSMutableParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            style.headIndent = max(0, style.headIndent - 20)
            style.firstLineHeadIndent = max(0, style.firstLineHeadIndent - 20)
            m.addAttribute(.paragraphStyle, value: style, range: r)
        }
    }

    // MARK: Paragraph actions (bullets, numbered, quote, code block)

    private static func applyParagraphAction(_ action: MarkdownAction, tv: UITextView) {
        let range = tv.selectedRange
        let m = NSMutableAttributedString(attributedString: tv.attributedText)
        let ns = m.string as NSString
        let lineRange = ns.lineRange(for: range)

        func togglePrefix(_ prefix: String) {
            let current = ns.substring(with: lineRange)
            if current.hasPrefix(prefix) {
                m.replaceCharacters(in: NSRange(location: lineRange.location, length: prefix.count), with: "")
                tv.attributedText = m
                tv.selectedRange = NSRange(location: range.location - prefix.count, length: range.length)
            } else {
                m.insert(NSAttributedString(string: prefix), at: lineRange.location)
                tv.attributedText = m
                tv.selectedRange = NSRange(location: range.location + prefix.count, length: range.length)
            }
        }

        switch action {
        case .bulletList: togglePrefix("• ")
        case .numberedList:
            let current = ns.substring(with: lineRange)
            if let r = current.range(of: #"^\d+\. "#, options: .regularExpression) {
                let len = current.distance(from: r.lowerBound, to: r.upperBound)
                m.replaceCharacters(in: NSRange(location: lineRange.location, length: len), with: "")
                tv.attributedText = m
                tv.selectedRange = NSRange(location: range.location - len, length: range.length)
            } else { togglePrefix("1. ") }
        case .blockquote: togglePrefix("> ")
        case .codeBlock:
            let lineRange = ns.lineRange(for: range)
            let paragraphRange = NSRange(location: lineRange.location, length: lineRange.length)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: EditorTheme.baseFont.pointSize, weight: .regular),
                .backgroundColor: EditorTheme.codeBlockBG,
                .codeBlock: NSNumber(value: true)  // Use NSNumber for Obj-C compatibility
            ]

            var hasCodeBlock = false
            m.enumerateAttribute(.codeBlock, in: paragraphRange, options: []) { value, _, stop in
                if let isCodeBlock = value as? NSNumber, isCodeBlock.boolValue {
                    hasCodeBlock = true
                    stop.pointee = true
                }
            }

            if hasCodeBlock {
                // Remove block styling
                m.removeAttribute(.codeBlock, range: paragraphRange)
                m.removeAttribute(.backgroundColor, range: paragraphRange)
                m.enumerateAttribute(.font, in: paragraphRange, options: []) { value, r, _ in
                    let f = (value as? UIFont) ?? EditorTheme.baseFont
                    m.addAttribute(.font, value: EditorTheme.baseFont, range: r)
                }
            } else {
                m.addAttributes(attrs, range: paragraphRange)
            }

            tv.attributedText = m
            tv.selectedRange = NSRange(location: range.location, length: range.length)
        default: break
        }
        
        // Fix cursor jump on undo after bullet list insert
        tv.layoutManager.ensureLayout(for: tv.textContainer)
    }

    // MARK: Utility

    static func insertImage(_ image: UIImage, into textView: UITextView) {
        let attachment = NSTextAttachment(); attachment.image = image
        let attributedString = NSAttributedString(attachment: attachment)
        let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
        mutableText.insert(attributedString, at: textView.selectedRange.location)
        textView.attributedText = mutableText
    }
    
    static func applyLink(in attributedString: NSMutableAttributedString, range: NSRange, urlString: String) {
        attributedString.addAttribute(.link, value: urlString, range: range)
    }
    
    static func baseAttributes(from attributedString: NSAttributedString, at index: Int) -> [NSAttributedString.Key: Any] {
        guard attributedString.length > 0 else { return [.font: EditorTheme.baseFont, .foregroundColor: EditorTheme.textColor] }
        let safeIndex = min(index, max(0, attributedString.length - 1))
        var attrs = attributedString.attributes(at: safeIndex, effectiveRange: nil)
        if attrs[.font] == nil { attrs[.font] = EditorTheme.baseFont }
        if attrs[.foregroundColor] == nil { attrs[.foregroundColor] = EditorTheme.textColor }
        return attrs
    }
    
    // MARK: Advanced Formatting Methods
    
    
    private static func removeAllFormatting(in m: NSMutableAttributedString, range: NSRange) {
        let attributesToRemove: [NSAttributedString.Key] = [
            .font, .foregroundColor, .backgroundColor, .underlineStyle, .strikethroughStyle,
            .baselineOffset, .paragraphStyle, .link
        ]
        
        for attribute in attributesToRemove {
            m.removeAttribute(attribute, range: range)
        }
        
        // Reset to base attributes
        m.addAttribute(.font, value: EditorTheme.baseFont, range: range)
        m.addAttribute(.foregroundColor, value: EditorTheme.textColor, range: range)
    }
    
    private static func setTextAlignment(_ alignment: NSTextAlignment, in m: NSMutableAttributedString, range: NSRange) {
        m.enumerateAttribute(.paragraphStyle, in: range, options: []) { value, r, _ in
            let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            style.alignment = alignment
            m.addAttribute(.paragraphStyle, value: style, range: r)
        }
    }
    
    private static func insertHorizontalRule(in m: NSMutableAttributedString, range: NSRange) {
        let hrText = NSAttributedString(string: "\n---\n", attributes: [
            .font: EditorTheme.baseFont,
            .foregroundColor: EditorTheme.textColor
        ])
        m.insert(hrText, at: range.location)
    }
    
    private static func setParagraph(in m: NSMutableAttributedString, range: NSRange) {
        m.enumerateAttribute(.paragraphStyle, in: range, options: []) { value, r, _ in
            let style = (value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle ?? NSMutableParagraphStyle()
            style.lineSpacing = 2
            // Don't override alignment or indentation
            m.addAttribute(.paragraphStyle, value: style, range: r)
        }
    }
    
    private static func applyHeader(level: Int, in m: NSMutableAttributedString, range: NSRange) {
        let sizes: [CGFloat] = [0, 28, 22, 18, 16, 14, 12]
        let weights: [UIFont.Weight] = [.regular, .bold, .semibold, .semibold, .medium, .medium, .medium]
        
        let size = sizes[min(level, sizes.count - 1)]
        let weight = weights[min(level, weights.count - 1)]

        m.enumerateAttributes(in: range, options: []) { attrs, r, _ in
            let existingStyle = attrs[.paragraphStyle] as? NSParagraphStyle
            let newStyle = (existingStyle?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            
            newStyle.lineSpacing = 6
            newStyle.paragraphSpacingBefore = 8
            newStyle.paragraphSpacing = 8
            
            let newFont = UIFont.systemFont(ofSize: size, weight: weight)
            m.addAttributes([.font: newFont, .paragraphStyle: newStyle], range: r)
        }
    }
    
    private static func createQuickLink(in m: NSMutableAttributedString, range: NSRange) {
        let selectedText = m.attributedSubstring(from: range).string
        var urlString = selectedText
        
        // Auto-detect URL patterns
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") && !urlString.hasPrefix("mailto:") {
            if urlString.contains("@") {
                urlString = "mailto:" + urlString
            } else if urlString.hasPrefix("#") {
                // Anchor link
            } else {
                urlString = "https://" + urlString
            }
        }
        
        m.addAttribute(.link, value: urlString, range: range)
        m.addAttribute(.foregroundColor, value: EditorTheme.linkColor, range: range)
    }
    
    private static func removeLink(in m: NSMutableAttributedString, range: NSRange) {
        m.removeAttribute(.link, range: range)
        m.removeAttribute(.foregroundColor, range: range)
    }
    
    // MARK: Color and Font Prompts
    
    private static func promptForTextColor(_ textView: UITextView) {
        // This would integrate with iOS color picker
        // For now, we'll use a simple color selection
        let alert = UIAlertController(title: "Text Color", message: "Select a color", preferredStyle: .actionSheet)
        
        let colors: [(String, UIColor)] = [
            ("Black", .label),
            ("Red", .systemRed),
            ("Blue", .systemBlue),
            ("Green", .systemGreen),
            ("Orange", .systemOrange),
            ("Purple", .systemPurple)
        ]
        
        for (name, color) in colors {
            alert.addAction(UIAlertAction(title: name, style: .default) { _ in
                applyTextColor(color, to: textView)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let coordinator = activeCoordinator {
            coordinator.topViewController()?.present(alert, animated: true)
        }
    }
    
    private static func promptForBackgroundColor(_ textView: UITextView) {
        let alert = UIAlertController(title: "Background Color", message: "Select a background color", preferredStyle: .actionSheet)
        
        let colors: [(String, UIColor)] = [
            ("None", .clear),
            ("Yellow", .systemYellow),
            ("Green", .systemGreen),
            ("Blue", .systemBlue),
            ("Red", .systemRed),
            ("Gray", .systemGray)
        ]
        
        for (name, color) in colors {
            alert.addAction(UIAlertAction(title: name, style: .default) { _ in
                applyBackgroundColor(color, to: textView)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let coordinator = activeCoordinator {
            coordinator.topViewController()?.present(alert, animated: true)
        }
    }
    
    private static func promptForFontFamily(_ textView: UITextView) {
        let alert = UIAlertController(title: "Font Family", message: "Select a font", preferredStyle: .actionSheet)
        
        let fonts: [(String, String)] = [
            ("System", "System"),
            ("Times", "Times New Roman"),
            ("Helvetica", "Helvetica"),
            ("Courier", "Courier New"),
            ("Georgia", "Georgia")
        ]
        
        for (name, fontName) in fonts {
            alert.addAction(UIAlertAction(title: name, style: .default) { _ in
                applyFontFamily(fontName, to: textView)
            })
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let coordinator = activeCoordinator {
            coordinator.topViewController()?.present(alert, animated: true)
        }
    }
    
    private static func applyTextColor(_ color: UIColor, to textView: UITextView) {
        let range = textView.selectedRange
        let m = NSMutableAttributedString(attributedString: textView.attributedText)
        m.addAttribute(.foregroundColor, value: color, range: range)
        textView.attributedText = m
    }
    
    private static func applyBackgroundColor(_ color: UIColor, to textView: UITextView) {
        let range = textView.selectedRange
        let m = NSMutableAttributedString(attributedString: textView.attributedText)
        if color == .clear {
            m.removeAttribute(.backgroundColor, range: range)
        } else {
            m.addAttribute(.backgroundColor, value: color, range: range)
        }
        textView.attributedText = m
    }
    
    private static func applyFontFamily(_ fontName: String, to textView: UITextView) {
        let range = textView.selectedRange
        let m = NSMutableAttributedString(attributedString: textView.attributedText)
        
        m.enumerateAttribute(.font, in: range, options: []) { value, r, _ in
            guard let currentFont = value as? UIFont else { return }
            var desc = currentFont.fontDescriptor
            
            // Keep symbolic traits (bold, italic)
            let traits = desc.symbolicTraits
            let newFont: UIFont
            if fontName == "System" {
                newFont = UIFont(descriptor: desc.withSymbolicTraits(traits) ?? desc, size: currentFont.pointSize)
            } else if let customDesc = UIFont(name: fontName, size: currentFont.pointSize)?.fontDescriptor {
                let combined = customDesc.withSymbolicTraits(traits) ?? customDesc
                newFont = UIFont(descriptor: combined, size: currentFont.pointSize)
            } else {
                newFont = currentFont
            }
            m.addAttribute(.font, value: newFont, range: r)
        }
        
        textView.attributedText = m
    }
    
    private static func toggleSourceView(_ textView: UITextView) {
        // This would toggle between WYSIWYG and HTML source view
        // Implementation would depend on your UI structure
        print("Toggle source view - implement based on your UI needs")
    }
    
    // MARK: Command State Checking (like ZSSRichTextEditor's isCommandEnabled)
    
    static func isFormattingActive(_ action: MarkdownAction, in textView: UITextView) -> Bool {
        let range = textView.selectedRange
        guard range.length > 0 else { return false }
        guard let attributedString = textView.attributedText else { return false }
        
        var hasFormatting = false
        
        switch action {
        case .bold:
            attributedString.enumerateAttribute(.font, in: range, options: []) { value, _, _ in
                if let font = value as? UIFont, font.fontDescriptor.symbolicTraits.contains(.traitBold) {
                    hasFormatting = true
                }
            }
        case .italic:
            attributedString.enumerateAttribute(.font, in: range, options: []) { value, _, _ in
                if let font = value as? UIFont, font.fontDescriptor.symbolicTraits.contains(.traitItalic) {
                    hasFormatting = true
                }
            }
        case .underline:
            attributedString.enumerateAttribute(.underlineStyle, in: range, options: []) { value, _, _ in
                if value != nil { hasFormatting = true }
            }
        case .strikethrough:
            attributedString.enumerateAttribute(.strikethroughStyle, in: range, options: []) { value, _, _ in
                if value != nil { hasFormatting = true }
            }
        case .code:
            attributedString.enumerateAttribute(.backgroundColor, in: range, options: []) { value, _, _ in
                if (value as? UIColor) == EditorTheme.codeBG { hasFormatting = true }
            }
        case .textColor:
            attributedString.enumerateAttribute(.foregroundColor, in: range, options: []) { value, _, _ in
                if let color = value as? UIColor, color != EditorTheme.textColor { hasFormatting = true }
            }
        case .backgroundColor:
            attributedString.enumerateAttribute(.backgroundColor, in: range, options: []) { value, _, _ in
                if value != nil { hasFormatting = true }
            }
        case .alignLeft, .alignCenter, .alignRight, .alignJustify:
            attributedString.enumerateAttribute(.paragraphStyle, in: range, options: []) { value, _, _ in
                if let style = value as? NSParagraphStyle {
                    let alignment = style.alignment
                    let expectedAlignment: NSTextAlignment = {
                        switch action {
                        case .alignLeft: return .left
                        case .alignCenter: return .center
                        case .alignRight: return .right
                        case .alignJustify: return .justified
                        default: return .left
                        }
                    }()
                    if alignment == expectedAlignment { hasFormatting = true }
                }
            }
        default:
            break
        }
        
        return hasFormatting
    }
}

// MARK: - UIViewController Extension

extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presented = presentedViewController {
            return presented.topMostViewController()
        }
        
        if let navigation = self as? UINavigationController {
            return navigation.visibleViewController?.topMostViewController() ?? self
        }
        
        if let tab = self as? UITabBarController {
            return tab.selectedViewController?.topMostViewController() ?? self
        }
        
        return self
    }
}

private extension NSRange { func toOptional() -> NSRange? { location == NSNotFound ? nil : self } }

// MARK: - SwiftUI Toolbar

struct MarkdownToolbarView: View {
    weak var coordinator: MarkdownEditor.Coordinator?
    
    private func button(_ title: String, action: MarkdownAction) -> ToolbarButton {
        ToolbarButton(title: title, action: action, coordinator: coordinator)
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Text Formatting Group
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        button("B", action: .bold)
                        button("I", action: .italic)
                        button("U", action: .underline)
                        button("S", action: .strikethrough)
                    }
                    HStack(spacing: 8) {
                        button("Code", action: .code)
                        button("Clear", action: .removeFormat)
                    }
                }
                
                Divider()
                    .frame(height: 30)
                
                // Text Size & Style Group
                VStack(spacing: 4) {
                    TextSizePicker(coordinator: coordinator)
                    HStack(spacing: 8) {
                        button("A", action: .textColor)
                        button("BG", action: .backgroundColor)
                    }
                }
                
                Divider()
                    .frame(height: 30)
                
                // Lists & Structure Group
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        button("•", action: .bulletList)
                        button("1.", action: .numberedList)
                        button(">", action: .blockquote)
                    }
                    HStack(spacing: 8) {
                        button("→", action: .indent)
                        button("←", action: .outdent)
                        button("—", action: .horizontalRule)
                    }
                }
                
                Divider()
                    .frame(height: 30)
                
                // Alignment Group
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        button("◀", action: .alignLeft)
                        button("◐", action: .alignCenter)
                        button("▶", action: .alignRight)
                        button("◈", action: .alignJustify)
                    }
                }
                
                Divider()
                    .frame(height: 30)
                
                // Links & Media Group
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        button("Link", action: .link)
                        button("Image", action: .image)
                    }
                }
                
                Divider()
                    .frame(height: 30)
                
                // Actions Group
                VStack(spacing: 4) {
                    HStack(spacing: 8) {
                        button("↶", action: .undo)
                        button("↷", action: .redo)
                        button("Find", action: .find)
                    }
                }
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 44)
        .background(Color(.systemGray6))
    }
}

struct TextSizePicker: View {
    weak var coordinator: MarkdownEditor.Coordinator?
    @State private var selectedSize: String = "Body"
    
    private let textSizes = [
        ("H1", "Header 1"),
        ("H2", "Header 2"), 
        ("H3", "Header 3"),
        ("H4", "Header 4"),
        ("H5", "Header 5"),
        ("H6", "Header 6"),
        ("Body", "Body Text")
    ]
    
    var body: some View {
        Menu {
            ForEach(textSizes, id: \.0) { size, label in
                Button(label) {
                    selectedSize = size
                    applyTextSize(size)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedSize)
                    .font(.system(size: 14, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemGray5))
            .cornerRadius(6)
        }
    }
    
    private func applyTextSize(_ size: String) {
        guard let coordinator = coordinator else { return }
        
        let action: MarkdownAction
        switch size {
        case "H1": action = .header1
        case "H2": action = .header2
        case "H3": action = .header3
        case "H4": action = .header4
        case "H5": action = .header5
        case "H6": action = .header6
        default: action = .paragraph
        }
        
        coordinator.handleMarkdownAction(action)
    }
}

struct ToolbarButton: View {
    let title: String
    let action: MarkdownAction
    weak var coordinator: MarkdownEditor.Coordinator?
    @State private var isSelected = false
    
    var body: some View {
        Button(title) { 
            coordinator?.handleMarkdownAction(action)  // ✅ Use the passed coordinator!
        }
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(isSelected ? .blue : .primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.12) : Color.clear)
        .cornerRadius(6)
        .onReceive(NotificationCenter.default.publisher(for: .editorActiveStylesDidChange)) { note in
            if let set = note.userInfo?["styles"] as? Set<MarkdownAction> { 
                isSelected = set.contains(action) 
    }
}
    }
}