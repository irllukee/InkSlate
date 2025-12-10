//
//  MarkdownEditor.swift
//  InkSlate
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
    static let imageData = NSAttributedString.Key("imageDataAttribute")
    static let imageSizeMode = NSAttributedString.Key("imageSizeModeAttribute")
}

enum ImageSizeMode: String {
    case normal
    case compact
}

struct EditorContentParser {
    static func deserialize(_ text: String, maxWidth: CGFloat) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var lastIndex = text.startIndex
        
        let pattern = "\\[(IMG|IMG-C):([A-Za-z0-9+/=]+)\\]"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            
            for match in matches {
                if let beforeRange = Range(NSRange(location: text.distance(from: text.startIndex, to: lastIndex),
                                                   length: match.range.location - text.distance(from: text.startIndex, to: lastIndex)), in: text) {
                    let beforeText = String(text[beforeRange])
                    result.append(NSAttributedString(string: beforeText, attributes: [
                        .font: EditorTheme.baseFont,
                        .foregroundColor: EditorTheme.textColor
                    ]))
                }
                
                if match.numberOfRanges > 2,
                   let tokenRange = Range(match.range(at: 1), in: text),
                   let base64Range = Range(match.range(at: 2), in: text) {
                    let token = String(text[tokenRange])
                    let base64 = String(text[base64Range])
                    if let data = Data(base64Encoded: base64),
                       let image = UIImage(data: data) {
                        let attachment = NSTextAttachment()
                        let aspect = image.size.height / max(image.size.width, 1)
                        let isCompact = token == "IMG-C"
                        let targetWidth = isCompact ? min(maxWidth, 160) : min(image.size.width, maxWidth)
                        let width = max(24, targetWidth)
                        let height = width * aspect
                        attachment.image = image
                        attachment.bounds = CGRect(x: 0, y: 0, width: width, height: height)
                        
                        let node = NSMutableAttributedString(attachment: attachment)
                        node.addAttributes([
                            .imageData: base64,
                            .imageSizeMode: (isCompact ? ImageSizeMode.compact : .normal).rawValue
                        ], range: NSRange(location: 0, length: node.length))
                        result.append(node)
                    }
                }
                
                if let matchRange = Range(match.range, in: text) {
                    lastIndex = matchRange.upperBound
                }
            }
        }
        
        if lastIndex < text.endIndex {
            let remaining = String(text[lastIndex...])
            result.append(NSAttributedString(string: remaining, attributes: [
                .font: EditorTheme.baseFont,
                .foregroundColor: EditorTheme.textColor
            ]))
        }
        
        return result
    }
}

struct MarkdownSerialization {
    private static let attrPrefix = "⟪ATTR⟫"
    private static let attrSuffix = "⟪/ATTR⟫"
    
    static func serialize(_ attributed: NSAttributedString) -> String {
        let mutable = attributed as? NSMutableAttributedString ?? NSMutableAttributedString(attributedString: attributed)
        ensureImageMetadata(in: mutable)
        
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: mutable, requiringSecureCoding: false) else {
            return plainTextRepresentation(of: mutable)
        }
        
        let encoded = data.base64EncodedString()
        let plain = plainTextRepresentation(of: mutable)
        return attrPrefix + encoded + attrSuffix + plain
    }
    
    static func deserialize(_ text: String, maxWidth: CGFloat) -> (NSAttributedString, String)? {
        guard let components = components(from: text) else {
            return nil
        }
        
        let base64 = components.base64
        let plainText = components.plainText
        guard let data = Data(base64Encoded: base64) else { return nil }
        
        let allowedClasses: [AnyClass] = [
            NSAttributedString.self,
            NSMutableAttributedString.self,
            NSTextAttachment.self,
            UIColor.self,
            UIImage.self,
            UIFont.self,
            NSURL.self,
            NSData.self,
            NSDictionary.self,
            NSString.self,
            NSNumber.self,
            NSParagraphStyle.self,
            NSMutableParagraphStyle.self,
            NSTextTab.self,
            NSShadow.self
        ]
        
        guard let attributed = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: allowedClasses, from: data) as? NSAttributedString else {
            return nil
        }
        
        let mutable = NSMutableAttributedString(attributedString: attributed)
        ensureImageMetadata(in: mutable, maxWidth: maxWidth)
        return (mutable, plainText)
    }
    
    static func plainText(from serialized: String) -> String {
        if let components = components(from: serialized) {
            return components.plainText
        }
        let fallback = EditorContentParser.deserialize(serialized, maxWidth: 300)
        return plainTextRepresentation(of: fallback)
    }
    
    static func ensureImageMetadata(in attributed: NSMutableAttributedString, maxWidth: CGFloat? = nil) {
        let range = NSRange(location: 0, length: attributed.length)
        attributed.enumerateAttribute(.attachment, in: range, options: []) { value, r, _ in
            guard let attachment = value as? NSTextAttachment else { return }
            
            if attributed.attribute(.imageData, at: r.location, effectiveRange: nil) == nil,
               let data = attachmentImageData(attachment) {
                attributed.addAttribute(.imageData, value: data.base64EncodedString(), range: r)
            }
            
            var targetWidth: CGFloat = attachment.bounds.width
            if let maxWidth = maxWidth, maxWidth > 0 {
                let cappedMax = max(24, maxWidth)
                var mode = ImageSizeMode.normal
                if let raw = attributed.attribute(.imageSizeMode, at: r.location, effectiveRange: nil) as? String,
                   let parsed = ImageSizeMode(rawValue: raw) {
                    mode = parsed
                }
                targetWidth = adjustedWidth(for: attachment, mode: mode, maxWidth: cappedMax)
            }
            
            if targetWidth > 0, let image = attachment.image ?? attachment.image(forBounds: attachment.bounds, textContainer: nil, characterIndex: 0) {
                let aspect = image.size.height / max(image.size.width, 1)
                attachment.bounds = CGRect(x: 0, y: 0, width: targetWidth, height: targetWidth * aspect)
            }
        }
    }
    
    static func attachmentImageData(_ attachment: NSTextAttachment) -> Data? {
        if let fileData = attachment.fileWrapper?.regularFileContents {
            return fileData
        }
        if let image = attachment.image ?? attachment.image(forBounds: attachment.bounds, textContainer: nil, characterIndex: 0) {
            if image.hasAlpha { return image.pngData() }
            return image.jpegData(compressionQuality: 0.8)
        }
        return nil
    }
    
    private static func adjustedWidth(for attachment: NSTextAttachment, mode: ImageSizeMode, maxWidth: CGFloat) -> CGFloat {
        guard let image = attachment.image ?? attachment.image(forBounds: attachment.bounds, textContainer: nil, characterIndex: 0) else {
            return attachment.bounds.width
        }
        let candidate = mode == .compact ? min(maxWidth, 160) : min(image.size.width, maxWidth)
        return max(24, candidate)
    }
    
    private static func components(from text: String) -> (base64: String, plainText: String)? {
        guard
            let prefixRange = text.range(of: attrPrefix),
            let suffixRange = text.range(of: attrSuffix, range: prefixRange.upperBound..<text.endIndex)
        else { return nil }
        
        let base64 = String(text[prefixRange.upperBound..<suffixRange.lowerBound])
        let plain = String(text[suffixRange.upperBound...])
        return (base64, plain)
    }
    
    private static func plainTextRepresentation(of attributed: NSAttributedString) -> String {
        var result = ""
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length), options: []) { attrs, range, _ in
            if attrs[.attachment] != nil {
                result += "[Image]"
            } else {
                result += attributed.attributedSubstring(from: range).string
            }
        }
        return result
    }
}

private extension UIImage {
    var hasAlpha: Bool {
        guard let alpha = cgImage?.alphaInfo else { return false }
        return alpha == .first || alpha == .last || alpha == .premultipliedFirst || alpha == .premultipliedLast
    }
}

// MARK: - Markdown Actions

enum MarkdownAction: Int, CaseIterable, Hashable {
    case bold = 0, italic, strikethrough, code, underline
    case removeFormat
    case header1, header2, header3
    case bulletList, numberedList, indent, outdent
    case alignLeft, alignCenter, alignRight
    case link, image, blockquote
    case undo, redo
    case imageToggleCompact
}

// MARK: - Global editor state & notifications

private struct ActiveEditorCoordinator {
    static weak var instance: MarkdownEditor.Coordinator?
}

private extension MarkdownEditor {
    static var activeCoordinator: Coordinator? {
        get { ActiveEditorCoordinator.instance }
        set { ActiveEditorCoordinator.instance = newValue }
    }
}

extension Notification.Name {
    static let editorActiveStylesDidChange = Notification.Name("EditorActiveStylesDidChange")
}

// MARK: - Helpers

private extension UITextView {
    func tsBegin() { textStorage.beginEditing() }
    func tsEnd() { textStorage.endEditing() }

    func replace(range: NSRange, with attributed: NSAttributedString) {
        textStorage.beginEditing()
        textStorage.replaceCharacters(in: range, with: attributed)
        textStorage.endEditing()
    }

    func setAttributes(_ attrs: [NSAttributedString.Key: Any], range: NSRange) {
        textStorage.beginEditing()
        textStorage.setAttributes(attrs, range: range)
        textStorage.endEditing()
    }

    func setAttributedStringUndoSafe(_ m: NSAttributedString) {
        textStorage.beginEditing()
        textStorage.setAttributedString(m)
        textStorage.endEditing()
    }
}

private extension UIViewController {
    func topMostViewController() -> UIViewController {
        if let presented = presentedViewController { return presented.topMostViewController() }
        if let nav = self as? UINavigationController { return nav.visibleViewController?.topMostViewController() ?? self }
        if let tab = self as? UITabBarController { return tab.selectedViewController?.topMostViewController() ?? self }
        return self
    }
}

private func currentTopVC() -> UIViewController? {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let win = scene.windows.first(where: { $0.isKeyWindow }) else { return nil }
    return win.rootViewController?.topMostViewController()
}

// MARK: - UIViewRepresentable

struct MarkdownEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var selectedRange: NSRange
    @Binding var coordinatorRef: Coordinator?
    
    func makeUIView(context: Context) -> EditorTextView {
        let textView = EditorTextView()

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

        textView.linkTextAttributes = [
            .foregroundColor: EditorTheme.linkColor,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        textView.delegate = context.coordinator
        textView.pasteDelegate = context.coordinator
        textView.undoManager?.levelsOfUndo = 50

        textView.addInteraction(UIDropInteraction(delegate: context.coordinator))

        // Load text with images
        let attributed = context.coordinator.deserializeContent(text)
        textView.attributedText = attributed
        
        context.coordinator.textView = textView
        MarkdownEditor.activeCoordinator = context.coordinator

        context.coordinator.applyTypingAttributes(in: textView)
        NotificationCenter.default.post(name: .editorActiveStylesDidChange, object: nil,
                                        userInfo: ["styles": context.coordinator.currentActiveStyles(in: textView)])

        DispatchQueue.main.async { textView.becomeFirstResponder() }
        
        return textView
    }
    
    func updateUIView(_ uiView: EditorTextView, context: Context) {
        guard !uiView.isFirstResponder else { return }

        context.coordinator.textView = uiView
        let latest = context.coordinator.serializeContent(from: uiView.attributedText)
        guard latest != text else { return }

        DispatchQueue.main.async {
            let range = uiView.selectedRange
            let attributed = context.coordinator.deserializeContent(text)
            uiView.setAttributedStringUndoSafe(attributed)
            if range.location <= uiView.attributedText.length {
                uiView.selectedRange = range
            }
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

        private var saveWorkItem: DispatchWorkItem?
        private var styleCalculationWorkItem: DispatchWorkItem?
        private var imageCache = [Data: String]()
        private let imageCacheLock = NSLock()
        private let serializationQueue = DispatchQueue(label: "co.inkslate.markdownEditor.serialization", qos: .userInitiated)
        
        fileprivate var typingModes = Set<MarkdownAction>()

        init(_ parent: MarkdownEditor) { self.parent = parent }
        
        deinit {
            saveWorkItem?.cancel()
            styleCalculationWorkItem?.cancel()
            fontCache.removeAll()
        }

        // MARK: Serialization (save images as base64)
        
        func serializeContent(from attributed: NSAttributedString) -> String {
            let mutable = attributed as? NSMutableAttributedString ?? NSMutableAttributedString(attributedString: attributed)
            let serialized = MarkdownSerialization.serialize(mutable)
            
            mutable.enumerateAttribute(.imageData, in: NSRange(location: 0, length: mutable.length), options: []) { value, _, _ in
                if let encoded = value as? String, let data = Data(base64Encoded: encoded) {
                    imageCacheLock.lock()
                    imageCache[data] = encoded
                    imageCacheLock.unlock()
                }
            }
            return serialized
        }
        
        func deserializeContent(_ text: String) -> NSAttributedString {
            let availableWidth = max((textView?.bounds.width ?? 300) - 28, 60)
            if let (attr, _) = MarkdownSerialization.deserialize(text, maxWidth: availableWidth) {
                attr.enumerateAttribute(.imageData, in: NSRange(location: 0, length: attr.length), options: []) { value, _, _ in
                    if let encoded = value as? String, let data = Data(base64Encoded: encoded) {
                            imageCacheLock.lock()
                            imageCache[data] = encoded
                            imageCacheLock.unlock()
                    }
                }
                return attr
            }
            let fallback = EditorContentParser.deserialize(text, maxWidth: availableWidth)
            fallback.enumerateAttribute(.imageData, in: NSRange(location: 0, length: fallback.length), options: []) { value, _, _ in
                if let encoded = value as? String, let data = Data(base64Encoded: encoded) {
                        imageCacheLock.lock()
                        imageCache[data] = encoded
                        imageCacheLock.unlock()
                }
            }
            return fallback
        }

        // MARK: Text changes
        
        func textViewDidChange(_ textView: UITextView) {
            guard !isProgrammaticChange else { return }
            saveWorkItem?.cancel()

            let updateParent: () -> Void = { [weak self] in
                self?.serializeAndPublishContent(from: textView.attributedText)
            }

            if textView.undoManager?.isUndoing == true || textView.undoManager?.isRedoing == true {
                updateParent()
            } else {
                let item = DispatchWorkItem(block: updateParent)
                saveWorkItem = item
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: item)
            }

            parent.selectedRange = textView.selectedRange
            updateActiveStylesAsync(textView)
        }

        private func updateActiveStylesAsync(_ textView: UITextView) {
            styleCalculationWorkItem?.cancel()
            styleCalculationWorkItem = DispatchWorkItem { [weak self] in
                guard let strongSelf = self else { return }
                let styles = strongSelf.currentActiveStyles(in: textView)
                NotificationCenter.default.post(name: .editorActiveStylesDidChange,
                                                object: nil, userInfo: ["styles": styles])
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: styleCalculationWorkItem!)
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.selectedRange = textView.selectedRange
            (textView as? EditorTextView)?.registerLinkMenuItems()
            NotificationCenter.default.post(name: .editorActiveStylesDidChange, object: nil,
                                            userInfo: ["styles": currentActiveStyles(in: textView)])
        }

        func textView(_ tv: UITextView, shouldChangeTextIn range: NSRange, replacementText string: String) -> Bool {
            if string == "\n" {
                if let etv = tv as? EditorTextView, WysiwygActionHandler.handleReturn(in: etv) {
                    return false
                }
            }
            // Handle Tab key for indenting lists
            if string == "\t" {
                if let etv = tv as? EditorTextView {
                    WysiwygActionHandler.apply(.indent, to: etv)
                    return false
                }
            }
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
            case .undo:
                tv.undoManager?.undo()
                serializeAndPublishContent(from: tv.attributedText)
                parent.selectedRange = tv.selectedRange
                NotificationCenter.default.post(name: .editorActiveStylesDidChange,
                                                object: nil,
                                                userInfo: ["styles": currentActiveStyles(in: tv)])
                return
            case .redo:
                tv.undoManager?.redo()
                serializeAndPublishContent(from: tv.attributedText)
                parent.selectedRange = tv.selectedRange
                NotificationCenter.default.post(name: .editorActiveStylesDidChange,
                                                object: nil,
                                                userInfo: ["styles": currentActiveStyles(in: tv)])
                return
            case .imageToggleCompact:
                if WysiwygActionHandler.toggleImageSize(in: tv) {
                    serializeAndPublishContent(from: tv.attributedText)
                    parent.selectedRange = tv.selectedRange
                    NotificationCenter.default.post(name: .editorActiveStylesDidChange,
                                                    object: nil,
                                                    userInfo: ["styles": currentActiveStyles(in: tv)])
                }
                return
            default: break
            }

            if action == .removeFormat {
                typingModes.removeAll()
                applyTypingAttributes(in: tv)
            }

            isProgrammaticChange = true
            tv.undoManager?.beginUndoGrouping()
            
            WysiwygActionHandler.apply(action, to: tv)
            
            tv.undoManager?.endUndoGrouping()
                isProgrammaticChange = false

            serializeAndPublishContent(from: tv.attributedText)
            parent.selectedRange = tv.selectedRange
            NotificationCenter.default.post(name: .editorActiveStylesDidChange, object: nil,
                                            userInfo: ["styles": currentActiveStyles(in: tv)])
            
            if action == .image {
                presentImagePickerPublic()
            } else if action == .link {
                promptForLink(tv)
            }
        }
        
        func topViewController() -> UIViewController? { currentTopVC() }

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
                guard self != nil else { return }
                var urlString = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !urlString.isEmpty && !urlString.contains("://") { urlString = "https://" + urlString }
                guard !urlString.isEmpty, let url = URL(string: urlString), url.scheme != nil else { return }
                
                let sel = textView.selectedRange
                textView.undoManager?.beginUndoGrouping()
                if sel.length == 0 {
                    let linkText = URLComponents(url: url, resolvingAgainstBaseURL: false)?.host ?? urlString
                    let insertion = NSMutableAttributedString(string: linkText)
                    insertion.addAttributes([.link: url], range: NSRange(location: 0, length: insertion.length))
                    textView.replace(range: NSRange(location: sel.location, length: 0), with: insertion)
                    textView.selectedRange = NSRange(location: sel.location + insertion.length, length: 0)
                } else {
                    textView.textStorage.beginEditing()
                    textView.textStorage.addAttribute(.link, value: url, range: sel)
                    textView.textStorage.endEditing()
                    textView.selectedRange = sel
                }
                textView.undoManager?.endUndoGrouping()
            })
            currentTopVC()?.present(alert, animated: true)
        }

        // MARK: Image picker

        fileprivate func presentImagePickerPublic() { presentImagePicker() }

        private func presentImagePicker() {
            guard let tv = textView else { return }
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .photoLibrary
            picker.modalPresentationStyle = .popover

            if let pop = picker.popoverPresentationController {
                pop.sourceView = tv
                pop.sourceRect = CGRect(x: tv.bounds.midX, y: tv.bounds.midY, width: 0, height: 0)
                pop.permittedArrowDirections = []
            }
            currentTopVC()?.present(picker, animated: true)
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
            session.hasItemsConforming(toTypeIdentifiers: [UTType.image.identifier])
        }
        func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal { UIDropProposal(operation: .copy) }
        func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
            guard let tv = textView else { return }
            session.loadObjects(ofClass: UIImage.self) { items in
                if let images = items as? [UIImage] {
                    for img in images {
                        WysiwygActionHandler.insertImage(img, into: tv)
                    }
                }
            }
        }

        // MARK: Helpers

        fileprivate func setTypingMode(_ action: MarkdownAction, enabled: Bool, in tv: UITextView) {
            if enabled { typingModes.insert(action) } else { typingModes.remove(action) }
            applyTypingAttributes(in: tv)
        }

        private var fontCache: [String: UIFont] = [:]
        
        fileprivate func applyTypingAttributes(in tv: UITextView) {
            var attrs = tv.typingAttributes
            if attrs[.font] == nil { attrs[.font] = EditorTheme.baseFont }
            if attrs[.foregroundColor] == nil { attrs[.foregroundColor] = EditorTheme.textColor }

            let baseFont = (attrs[.font] as? UIFont) ?? EditorTheme.baseFont
            let cacheKey = "\(baseFont.pointSize)_\(typingModes.hashValue)"
            
            if let cachedFont = fontCache[cacheKey] {
                attrs[.font] = cachedFont
            } else {
                var traits: UIFontDescriptor.SymbolicTraits = []
                if typingModes.contains(.bold) { traits.insert(.traitBold) }
                if typingModes.contains(.italic) { traits.insert(.traitItalic) }
                
                let newFont: UIFont
                if traits.isEmpty {
                    newFont = baseFont
                } else if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(traits) {
                    newFont = UIFont(descriptor: descriptor, size: baseFont.pointSize)
                    } else {
                        newFont = baseFont
                }
                fontCache[cacheKey] = newFont
                attrs[.font] = newFont
            }

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
        
        private func serializeAndPublishContent(from attributed: NSAttributedString) {
            let snapshot = NSMutableAttributedString(attributedString: attributed)
            serializationQueue.async { [weak self] in
                guard let self = self else { return }
                let serialized = PerformanceLogger.measure(log: PerformanceMetrics.serialization, name: "SerializeNote") {
                    self.serializeContent(from: snapshot)
                }
                DispatchQueue.main.async {
                    self.parent.text = serialized
                }
            }
        }

        fileprivate func currentActiveStyles(in tv: UITextView) -> Set<MarkdownAction> {
            var set = typingModes
            let idx = max(0, min(tv.selectedRange.location, max(0, tv.attributedText.length - 1)))
            let attrs = tv.attributedText.length > 0 ? tv.attributedText.attributes(at: idx, effectiveRange: nil) : tv.typingAttributes

            if let f = (attrs[.font] as? UIFont) {
                let traits = f.fontDescriptor.symbolicTraits
                if traits.contains(.traitBold) { set.insert(.bold) } else { set.remove(.bold) }
                if traits.contains(.traitItalic) { set.insert(.italic) } else { set.remove(.italic) }
            }
            if (attrs[.underlineStyle] as? Int) == NSUnderlineStyle.single.rawValue { set.insert(.underline) } else { set.remove(.underline) }
            if (attrs[.strikethroughStyle] as? Int) == NSUnderlineStyle.single.rawValue { set.insert(.strikethrough) } else { set.remove(.strikethrough) }

            let line = (tv as? EditorTextView)?.currentLineString() ?? ""
            if line.range(of: #"^\s*• "#, options: .regularExpression) != nil { set.insert(.bulletList) } else { set.remove(.bulletList) }
            if line.range(of: #"^\s*\d+\. "#, options: .regularExpression) != nil { set.insert(.numberedList) } else { set.remove(.numberedList) }
            // Match nested blockquotes (>, >>, >>>, etc.)
            if line.range(of: #"^>+\s"#, options: .regularExpression) != nil { set.insert(.blockquote) } else { set.remove(.blockquote) }

            return set
        }
    }
}

// MARK: - Custom UITextView

final class EditorTextView: UITextView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        undoManager?.levelsOfUndo = 50
    }
 

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(editLink) || action == #selector(removeLink) { return currentLinkRange() != nil }
        return super.canPerformAction(action, withSender: sender)
    }

    @objc func editLink() {
        guard let r = currentLinkRange(),
              let url = attributedText.attribute(.link, at: r.location, effectiveRange: nil) as? URL else { return }
        let alert = UIAlertController(title: "Edit Link", message: nil, preferredStyle: .alert)
        alert.addTextField { tf in
            tf.text = url.absoluteString
            tf.keyboardType = .URL
            tf.autocorrectionType = .no
            tf.autocapitalizationType = .none
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let strongSelf = self else { return }
            var urlString = alert.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            // Auto-add https:// if no protocol specified
            if !urlString.isEmpty && !urlString.contains("://") { urlString = "https://" + urlString }
            guard !urlString.isEmpty, let newURL = URL(string: urlString), newURL.scheme != nil else { return }
            strongSelf.textStorage.beginEditing()
            strongSelf.textStorage.addAttribute(.link, value: newURL, range: r)
            strongSelf.textStorage.endEditing()
        })
        currentTopVC()?.present(alert, animated: true)
    }

    @objc func removeLink() {
        guard let r = currentLinkRange() else { return }
        textStorage.beginEditing()
        textStorage.removeAttribute(.link, range: r)
        textStorage.removeAttribute(.underlineStyle, range: r)
        textStorage.endEditing()
    }

    func registerLinkMenuItems() {
        if #available(iOS 16.0, *) {
            // System edit menu
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

    func currentLineRange() -> NSRange {
        let ns = attributedText.string as NSString
        let idx = min(selectedRange.location, ns.length)
        return ns.lineRange(for: NSRange(location: idx, length: 0))
    }
    func currentLineString() -> String {
        let ns = attributedText.string as NSString
        return ns.substring(with: currentLineRange())
    }
}

// MARK: - WYSIWYG Action Handler

class WysiwygActionHandler {
    static func handleReturn(in textView: EditorTextView) -> Bool {
        let lineR = textView.currentLineRange()
        let ns = textView.attributedText.string as NSString
        let line = ns.substring(with: lineR)

        // Blockquote handling with nested levels
        if let match = line.range(of: #"^>+\s"#, options: .regularExpression) {
            let prefix = String(line[match])
            let content = String(line.dropFirst(prefix.count))
            if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let m = NSMutableAttributedString(attributedString: textView.attributedText)
                m.replaceCharacters(in: lineR, with: "")
                textView.setAttributedStringUndoSafe(m)
                textView.selectedRange = NSRange(location: lineR.location, length: 0)
                return true
            } else {
                textView.insertText("\n\(prefix)")
                return true
            }
        }

        // Check for indented bullets (with leading spaces)
        if let match = line.range(of: #"^(\s*)• "#, options: .regularExpression) {
            let indent = String(line[match]).dropLast(2) // Remove "• "
            let afterBullet = String(line.dropFirst(indent.count + 2))
            if afterBullet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let m = NSMutableAttributedString(attributedString: textView.attributedText)
                m.replaceCharacters(in: lineR, with: "")
                textView.setAttributedStringUndoSafe(m)
                textView.selectedRange = NSRange(location: lineR.location, length: 0)
                return true
            } else {
                textView.insertText("\n\(indent)• ")
                return true
            }
        }

        // Numbered list
        if let match = line.range(of: #"^(\s*)(\d+)\. "#, options: .regularExpression) {
            let nsLine = line as NSString
            let matchRange = NSRange(match, in: line)
            let prefix = nsLine.substring(with: matchRange)
            
            // Extract indent and number
            if let numMatch = prefix.range(of: #"\d+"#, options: .regularExpression) {
                let numStr = String(prefix[numMatch])
                let indent = String(prefix.prefix(while: { $0 == " " }))
                let after = String(line.dropFirst(prefix.count))
                
                if after.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let m = NSMutableAttributedString(attributedString: textView.attributedText)
                    m.replaceCharacters(in: lineR, with: "")
                    textView.setAttributedStringUndoSafe(m)
                    textView.selectedRange = NSRange(location: lineR.location, length: 0)
                    return true
                } else if let n = Int(numStr) {
                    textView.insertText("\n\(indent)\(n + 1). ")
                    return true
                }
            }
        }

        // Note: Simple "> " blockquote is handled by the nested blockquote regex above (^>+\s)
        return false
    }
    
    static func apply(_ action: MarkdownAction, to textView: UITextView) {
        guard let coord = MarkdownEditor.activeCoordinator else { return }
        let range = textView.selectedRange
        let hasSelection = range.length > 0

        // List actions
        if action == .bulletList || action == .numberedList || action == .blockquote {
            applyListAction(action, tv: textView)
            return
        }

        // Indent/outdent
        if action == .indent || action == .outdent {
            applyIndentAction(action, tv: textView)
            return
        }

        // Headers
        if action == .header1 || action == .header2 || action == .header3 {
            applyHeader(action, tv: textView)
            return
        }

        // Style toggles
        if hasSelection {
            let m = NSMutableAttributedString(attributedString: textView.attributedText)
            switch action {
            case .bold: toggleFontTrait(.traitBold, in: m, range: range)
            case .italic: toggleFontTrait(.traitItalic, in: m, range: range)
            case .underline: toggleSimple(.underlineStyle, value: NSUnderlineStyle.single.rawValue, in: m, range: range)
            case .strikethrough: toggleSimple(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, in: m, range: range)
            case .code: toggleInlineCode(in: m, range: range)
            case .removeFormat: removeAllFormatting(in: m, range: range)
            case .alignLeft: setTextAlignment(.left, in: m, range: range)
            case .alignCenter: setTextAlignment(.center, in: m, range: range)
            case .alignRight: setTextAlignment(.right, in: m, range: range)
            default: break
            }
            textView.setAttributedStringUndoSafe(m)
            textView.selectedRange = range
            coord.applyTypingAttributes(in: textView)
        } else {
            // Typing mode
            switch action {
            case .bold, .italic, .underline, .strikethrough, .code:
                let shouldEnable = !coord.typingModes.contains(action)
                coord.setTypingMode(action, enabled: shouldEnable, in: textView)
            case .alignLeft: setCaretAlignment(.left, in: textView)
            case .alignCenter: setCaretAlignment(.center, in: textView)
            case .alignRight: setCaretAlignment(.right, in: textView)
            default: break
            }
        }
    }

    // MARK: Headers

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
        
        // Handle empty text or invalid range
        guard m.length > 0, lineR.location < m.length else {
            // For empty text, just set typing attributes for the header
            var attrs = tv.typingAttributes
            attrs[.font] = UIFont.systemFont(ofSize: sizes.0, weight: sizes.1)
            let style = NSMutableParagraphStyle()
            style.lineSpacing = 6
            style.paragraphSpacingBefore = 8
            style.paragraphSpacing = 8
            attrs[.paragraphStyle] = style
            tv.typingAttributes = attrs
            return
        }
        
        let existingAttrs = m.attributes(at: lineR.location, effectiveRange: nil)
        var merged = existingAttrs
        merged[.font] = UIFont.systemFont(ofSize: sizes.0, weight: sizes.1)
        
        // Preserve existing paragraph style properties and just update spacing
        let existingStyle = existingAttrs[.paragraphStyle] as? NSParagraphStyle
        let style = (existingStyle?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        style.lineSpacing = 6
        style.paragraphSpacingBefore = 8
        style.paragraphSpacing = 8
        merged[.paragraphStyle] = style
        m.addAttributes(merged, range: lineR)
        
        tv.setAttributedStringUndoSafe(m)
        tv.selectedRange = NSRange(location: lineR.location, length: 0)
    }

    // MARK: Lists with proper indentation

    private static func applyListAction(_ action: MarkdownAction, tv: UITextView) {
        let range = tv.selectedRange
        let m = NSMutableAttributedString(attributedString: tv.attributedText)
        let ns = m.string as NSString
        let lineRange = ns.lineRange(for: range)
        let line = ns.substring(with: lineRange)
        
        // Get current indent level
        let currentIndent = line.prefix(while: { $0 == " " })
        
        // Track cursor adjustment
        var newCursorLocation = range.location
        
        switch action {
        case .bulletList:
            if line.range(of: #"^\s*• "#, options: .regularExpression) != nil {
                // Remove bullet
                if let bulletRange = line.range(of: #"^\s*• "#, options: .regularExpression) {
                    let nsRange = NSRange(bulletRange, in: line)
                    m.replaceCharacters(in: NSRange(location: lineRange.location + nsRange.location, 
                                                   length: nsRange.length), with: "")
                    // Adjust cursor - move back by the removed prefix length
                    newCursorLocation = max(lineRange.location, range.location - nsRange.length)
                }
            } else {
                // Add bullet with current indent
                let prefix = "\(currentIndent)• "
                m.insert(NSAttributedString(string: prefix), at: lineRange.location)
                // Position cursor after the bullet point
                newCursorLocation = lineRange.location + prefix.count
            }
            
        case .numberedList:
            if line.range(of: #"^\s*\d+\. "#, options: .regularExpression) != nil {
                // Remove number
                if let numRange = line.range(of: #"^\s*\d+\. "#, options: .regularExpression) {
                    let nsRange = NSRange(numRange, in: line)
                    m.replaceCharacters(in: NSRange(location: lineRange.location + nsRange.location,
                                                   length: nsRange.length), with: "")
                    // Adjust cursor - move back by the removed prefix length
                    newCursorLocation = max(lineRange.location, range.location - nsRange.length)
                }
            } else {
                // Add number with current indent
                let prefix = "\(currentIndent)1. "
                m.insert(NSAttributedString(string: prefix), at: lineRange.location)
                // Position cursor after the number
                newCursorLocation = lineRange.location + prefix.count
            }
            
        case .blockquote:
            if let _ = line.range(of: #"^>+\s"#, options: .regularExpression) {
                // Remove one level of blockquote
                if let quoteRange = line.range(of: #"^>\s"#, options: .regularExpression) {
                    let nsRange = NSRange(quoteRange, in: line)
                    m.replaceCharacters(in: NSRange(location: lineRange.location + nsRange.location, length: nsRange.length), with: "")
                    // Adjust cursor - move back by the removed prefix length
                    newCursorLocation = max(lineRange.location, range.location - nsRange.length)
                }
            } else {
                let prefix = "> "
                m.insert(NSAttributedString(string: prefix), at: lineRange.location)
                // Position cursor after the quote marker
                newCursorLocation = lineRange.location + prefix.count
            }
            
        default: break
        }
        
        tv.setAttributedStringUndoSafe(m)
        tv.selectedRange = NSRange(location: newCursorLocation, length: 0)
    }

    // MARK: Indent/Outdent with sub-bullets

    private static func applyIndentAction(_ action: MarkdownAction, tv: UITextView) {
        let range = tv.selectedRange
        let m = NSMutableAttributedString(attributedString: tv.attributedText)
        let ns = m.string as NSString
        let lineRange = ns.lineRange(for: range)
        let line = ns.substring(with: lineRange)
        
        let indentUnit = "    " // 4 spaces for sub-level
        
        if action == .indent {
            // Add indent
            if line.range(of: #"^\s*[•\d]"#, options: .regularExpression) != nil {
                // It's a list item, add indent at the start
                m.insert(NSAttributedString(string: indentUnit), at: lineRange.location)
                tv.setAttributedStringUndoSafe(m)
                tv.selectedRange = NSRange(location: range.location + indentUnit.count, length: 0)
            }
        } else if action == .outdent {
            // Remove indent
            let leadingSpaces = line.prefix(while: { $0 == " " })
            if leadingSpaces.count >= indentUnit.count {
                m.replaceCharacters(in: NSRange(location: lineRange.location, length: indentUnit.count), with: "")
                tv.setAttributedStringUndoSafe(m)
                tv.selectedRange = NSRange(location: max(0, range.location - indentUnit.count), length: 0)
            }
        }
    }

    // MARK: Alignment

    private static func setTextAlignment(_ alignment: NSTextAlignment, in m: NSMutableAttributedString, range: NSRange) {
        let ns = m.string as NSString
        let paraRange = ns.paragraphRange(for: range)
        
        // Get existing paragraph style or create new one
        let existingStyle = m.attribute(.paragraphStyle, at: paraRange.location, effectiveRange: nil) as? NSParagraphStyle
        let style = (existingStyle?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        style.alignment = alignment
        m.addAttribute(.paragraphStyle, value: style, range: paraRange)

        if let tv = MarkdownEditor.activeCoordinator?.textView {
            var attrs = tv.typingAttributes
            let existingTypingStyle = attrs[.paragraphStyle] as? NSParagraphStyle
            let typingStyle = (existingTypingStyle?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
            typingStyle.alignment = alignment
            attrs[.paragraphStyle] = typingStyle
            tv.typingAttributes = attrs
        }
    }
    
    private static func setCaretAlignment(_ alignment: NSTextAlignment, in tv: UITextView) {
        var attrs = tv.typingAttributes
        let existingStyle = attrs[.paragraphStyle] as? NSParagraphStyle
        let style = (existingStyle?.mutableCopy() as? NSMutableParagraphStyle) ?? NSMutableParagraphStyle()
        style.alignment = alignment
        attrs[.paragraphStyle] = style
        tv.typingAttributes = attrs
    }

    // MARK: Font traits

    private static func toggleFontTrait(_ trait: UIFontDescriptor.SymbolicTraits, 
                                       in m: NSMutableAttributedString, 
                                       range: NSRange) {
        m.enumerateAttribute(.font, in: range, options: []) { value, r, _ in
            let base = (value as? UIFont) ?? EditorTheme.baseFont
            var traits = base.fontDescriptor.symbolicTraits
            if traits.contains(trait) { traits.remove(trait) } else { traits.insert(trait) }
            
            let newFont: UIFont
            if let descriptor = base.fontDescriptor.withSymbolicTraits(traits) {
                newFont = UIFont(descriptor: descriptor, size: base.pointSize)
            } else {
                newFont = base
            }
            m.addAttribute(.font, value: newFont, range: r)
        }
    }

    private static func toggleSimple(_ key: NSAttributedString.Key, value: Any, in m: NSMutableAttributedString, range: NSRange) {
        m.enumerateAttribute(key, in: range, options: []) { existing, r, _ in
            if existing != nil { m.removeAttribute(key, range: r) }
            else { m.addAttribute(key, value: value, range: r) }
        }
    }

    private static func toggleInlineCode(in m: NSMutableAttributedString, range: NSRange) {
        m.enumerateAttributes(in: range, options: []) { attrs, r, _ in
            let hasMono = (attrs[.font] as? UIFont)?.fontName.lowercased().contains("mono") == true
            var a = attrs
            if hasMono {
                a[.backgroundColor] = nil
                if let f = a[.font] as? UIFont {
                    a[.font] = UIFont.systemFont(ofSize: f.pointSize)
                }
            } else {
                a[.backgroundColor] = EditorTheme.codeBG
                let base = (a[.font] as? UIFont) ?? EditorTheme.baseFont
                a[.font] = UIFont.monospacedSystemFont(ofSize: base.pointSize, weight: .regular)
            }
            m.setAttributes(a, range: r)
        }
    }

    private static func removeAllFormatting(in m: NSMutableAttributedString, range: NSRange) {
        m.setAttributes([
            .font: EditorTheme.baseFont,
            .foregroundColor: EditorTheme.textColor
        ], range: range)
    }

    // MARK: Images

    static func toggleImageSize(in tv: UITextView) -> Bool {
        guard tv.attributedText.length > 0 else { return false }
        let selection = tv.selectedRange
        var effectiveRange = NSRange(location: 0, length: 0)
        let candidateIndices: [Int] = {
            var indices = [selection.location]
            if selection.length > 0 { indices.append(selection.location + selection.length - 1) }
            if selection.location > 0 { indices.append(selection.location - 1) }
            return indices.compactMap {
                guard tv.attributedText.length > 0 else { return nil }
                return max(0, min($0, tv.attributedText.length - 1))
            }
        }()
        
        var attachment: NSTextAttachment?
        var resolvedIndex: Int?
        for candidate in candidateIndices {
            if let found = tv.attributedText.attribute(.attachment, at: candidate, effectiveRange: &effectiveRange) as? NSTextAttachment {
                attachment = found
                resolvedIndex = candidate
                break
            }
        }
        guard let targetAttachment = attachment, let index = resolvedIndex else { return false }
        
        let currentModeRaw = tv.attributedText.attribute(.imageSizeMode, at: index, effectiveRange: nil) as? String
        let currentMode = ImageSizeMode(rawValue: currentModeRaw ?? ImageSizeMode.normal.rawValue) ?? .normal
        let newMode: ImageSizeMode = (currentMode == .compact) ? .normal : .compact
        tv.undoManager?.beginUndoGrouping()
        guard updateAttachmentBounds(targetAttachment, mode: newMode, in: tv) else {
            tv.undoManager?.endUndoGrouping()
            return false
        }
        tv.textStorage.beginEditing()
        tv.textStorage.addAttribute(.imageSizeMode, value: newMode.rawValue, range: effectiveRange)
        tv.textStorage.endEditing()
        tv.undoManager?.endUndoGrouping()
        tv.setNeedsLayout()
        tv.layoutIfNeeded()
        return true
    }
    
    static func insertImage(_ image: UIImage, into tv: UITextView) {
        let maxW = tv.bounds.width - tv.textContainerInset.left - tv.textContainerInset.right - 8
        let aspect = image.size.height / max(image.size.width, 1)
        let w = max(24, min(image.size.width, maxW))
        let h = w * aspect
        let att = NSTextAttachment()
        att.image = image
        att.bounds = CGRect(x: 0, y: 0, width: w, height: h)
        
        let node = NSMutableAttributedString(attachment: att)
        if let data = (image.hasAlpha ? image.pngData() : image.jpegData(compressionQuality: 0.8)) {
            node.addAttribute(.imageData, value: data.base64EncodedString(), range: NSRange(location: 0, length: node.length))
        }
        node.addAttribute(.imageSizeMode, value: ImageSizeMode.normal.rawValue, range: NSRange(location: 0, length: node.length))
        
        tv.undoManager?.beginUndoGrouping()
        tv.replace(range: tv.selectedRange, with: node)
        tv.selectedRange = NSRange(location: tv.selectedRange.location + node.length, length: 0)
        tv.undoManager?.endUndoGrouping()
    }
    
    static func baseAttributes(from attributedString: NSAttributedString, at index: Int) -> [NSAttributedString.Key: Any] {
        guard attributedString.length > 0 else { return [.font: EditorTheme.baseFont, .foregroundColor: EditorTheme.textColor] }
        let safeIndex = min(index, max(0, attributedString.length - 1))
        var attrs = attributedString.attributes(at: safeIndex, effectiveRange: nil)
        if attrs[.font] == nil { attrs[.font] = EditorTheme.baseFont }
        if attrs[.foregroundColor] == nil { attrs[.foregroundColor] = EditorTheme.textColor }
        return attrs
    }
    
    private static func updateAttachmentBounds(_ attachment: NSTextAttachment, mode: ImageSizeMode, in tv: UITextView) -> Bool {
        guard let image = attachment.image ?? attachment.image(forBounds: attachment.bounds, textContainer: tv.textContainer, characterIndex: 0) else {
            return false
        }
        let maxW = tv.bounds.width - tv.textContainerInset.left - tv.textContainerInset.right - 8
        let targetWidth = mode == .compact ? min(maxW, 160) : min(image.size.width, maxW)
        let width = max(24, targetWidth)
        let height = width * (image.size.height / max(image.size.width, 1))
        attachment.bounds = CGRect(x: 0, y: 0, width: width, height: height)
        return true
    }
}

// MARK: - SwiftUI Toolbar (Cleaner Layout)

struct MarkdownToolbarView: View {
    weak var coordinator: MarkdownEditor.Coordinator?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                // Basic formatting
                HStack(spacing: 6) {
                    toolbarButton("B", .bold, hint: "Bold")
                    toolbarButton("I", .italic, hint: "Italic")
                    toolbarButton("U", .underline, hint: "Underline")
                    toolbarButton("S", .strikethrough, hint: "Strikethrough")
                }
                
                Divider().frame(height: 24)
                
                // Headers menu
                Menu {
                    Button("Header 1") { coordinator?.handleMarkdownAction(.header1) }
                    Button("Header 2") { coordinator?.handleMarkdownAction(.header2) }
                    Button("Header 3") { coordinator?.handleMarkdownAction(.header3) }
                } label: {
                    Text("H")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray5))
                        .cornerRadius(6)
                }
                
                Divider().frame(height: 24)
                
                // Lists
                HStack(spacing: 6) {
                    toolbarButton("•", .bulletList, hint: "Bullet List")
                    toolbarButton("1.", .numberedList, hint: "Numbered List")
                    toolbarButton("→", .indent, hint: "Indent")
                    toolbarButton("←", .outdent, hint: "Outdent")
                }
                
                Divider().frame(height: 24)
                
                // Alignment menu
                Menu {
                    Button(action: { coordinator?.handleMarkdownAction(.alignLeft) }) {
                        Label("Align Left", systemImage: "text.alignleft")
                    }
                    Button(action: { coordinator?.handleMarkdownAction(.alignCenter) }) {
                        Label("Align Center", systemImage: "text.aligncenter")
                    }
                    Button(action: { coordinator?.handleMarkdownAction(.alignRight) }) {
                        Label("Align Right", systemImage: "text.alignright")
                    }
                } label: {
                    Image(systemName: "text.alignleft")
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray5))
                        .cornerRadius(6)
                }
                
                Divider().frame(height: 24)
                
                // Insert menu
                Menu {
                    Button(action: { coordinator?.handleMarkdownAction(.link) }) {
                        Label("Link", systemImage: "link")
                    }
                    Button(action: { coordinator?.handleMarkdownAction(.image) }) {
                        Label("Image", systemImage: "photo")
                    }
                    Button(action: { coordinator?.handleMarkdownAction(.imageToggleCompact) }) {
                        Label("Toggle Image Size", systemImage: "arrow.up.left.and.down.right")
                    }
                    Button(action: { coordinator?.handleMarkdownAction(.blockquote) }) {
                        Label("Quote", systemImage: "quote.bubble")
                    }
                    Button(action: { coordinator?.handleMarkdownAction(.code) }) {
                        Label("Code", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                } label: {
                    Image(systemName: "plus.circle")
                        .frame(width: 32, height: 32)
                        .background(Color(.systemGray5))
                        .cornerRadius(6)
                }
                
                Divider().frame(height: 24)
                
                // Tools
                HStack(spacing: 6) {
                    toolbarButton("↶", .undo, hint: "Undo")
                    toolbarButton("↷", .redo, hint: "Redo")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
        .frame(height: 44)
    }
    
    private func toolbarButton(_ title: String, _ action: MarkdownAction, hint: String) -> some View {
        ToolbarButton(title: title, action: action, coordinator: coordinator, accessibilityHint: hint)
    }
}

struct ToolbarButton: View {
    let title: String
    let action: MarkdownAction
    weak var coordinator: MarkdownEditor.Coordinator?
    @State private var isSelected = false
    var accessibilityHint: String?
    
    var body: some View {
        Button {
            coordinator?.handleMarkdownAction(action)  
        } label: {
            Text(title)
        .font(.system(size: 16, weight: .medium))
                .frame(width: 32, height: 32)
                .foregroundColor(isSelected ? .white : .primary)
                .background(isSelected ? Color.blue : Color(.systemGray5))
        .cornerRadius(6)
        }
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint ?? "")
        .accessibilityAddTraits(.isButton)
        .dynamicTypeSize(.large ... .xxxLarge)
        .onReceive(NotificationCenter.default.publisher(for: .editorActiveStylesDidChange)) { note in
            if let set = note.userInfo?["styles"] as? Set<MarkdownAction> { 
                isSelected = set.contains(action) 
            }
        }
    }
}