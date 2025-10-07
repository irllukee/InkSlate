//
//  RichTextEditor.swift
//  InkSlate
//
//  Created by Assistant on 10/3/25.
//

import SwiftUI
import UIKit

// MARK: - Rich Text Editor
struct RichTextEditor: View {
    @Binding var attributedText: NSAttributedString
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var currentAttributes: [NSAttributedString.Key: Any] = [:]
    @State private var undoStack: [NSAttributedString] = []
    @State private var redoStack: [NSAttributedString] = []
    @State private var maxUndoActions = 50
    @State private var keyboardHeight: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Text Editor (takes up available space)
            RichTextViewRepresentable(
                attributedText: $attributedText,
                selectedRange: $selectedRange,
                currentAttributes: $currentAttributes,
                undoStack: $undoStack,
                redoStack: $redoStack,
                maxUndoActions: maxUndoActions
            )
            
            // Enhanced Toolbar positioned above keyboard
            if keyboardHeight > 0 {
                EnhancedToolbar(
                    attributedText: $attributedText,
                    selectedRange: $selectedRange,
                    currentAttributes: $currentAttributes,
                    undoStack: $undoStack,
                    redoStack: $redoStack,
                    maxUndoActions: maxUndoActions
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut(duration: 0.3), value: keyboardHeight)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            if let keyboardFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = keyboardFrame.height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }
}

// MARK: - Enhanced Toolbar (Stock Notes Style)
struct EnhancedToolbar: View {
    @Binding var attributedText: NSAttributedString
    @Binding var selectedRange: NSRange
    @Binding var currentAttributes: [NSAttributedString.Key: Any]
    @Binding var undoStack: [NSAttributedString]
    @Binding var redoStack: [NSAttributedString]
    let maxUndoActions: Int
    
    // Cache computed properties to prevent state modification during view updates
    @State private var cachedIsBold: Bool = false
    @State private var cachedIsItalic: Bool = false
    @State private var cachedIsUnderlined: Bool = false
    @State private var cachedCurrentTextColor: Color = .primary
    @State private var cachedIsTextColored: Bool = false
    @State private var cachedIsHighlighted: Bool = false
    @State private var cachedAlignment: NSTextAlignment = .left
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Undo/Redo
                    ToolbarButton(
                        icon: "arrow.uturn.backward",
                        isEnabled: !undoStack.isEmpty,
                        action: { undo() }
                    )
                    
                    ToolbarButton(
                        icon: "arrow.uturn.forward",
                        isEnabled: !redoStack.isEmpty,
                        action: { redo() }
                    )
                    
                    Divider()
                        .frame(height: 20)
                        .background(Color(.separator))
                    
                    // Bold
                    ToolbarButton(
                        icon: "bold",
                        isSelected: cachedIsBold,
                        action: { toggleBold() }
                    )
                    
                    // Italic
                    ToolbarButton(
                        icon: "italic",
                        isSelected: cachedIsItalic,
                        action: { toggleItalic() }
                    )
                    
                    // Underline
                    ToolbarButton(
                        icon: "underline",
                        isSelected: cachedIsUnderlined,
                        action: { toggleUnderline() }
                    )
                    
                    Divider()
                        .frame(height: 20)
                        .background(Color(.separator))
                    
                    // Bullet List
                    ToolbarButton(
                        icon: "list.bullet",
                        isSelected: isBulletList,
                        action: { toggleBulletList() }
                    )
                    
                    // Indent
                    ToolbarButton(
                        icon: "increase.indent",
                        isEnabled: canIndent,
                        action: { indent() }
                    )
                    
                    // Outdent
                    ToolbarButton(
                        icon: "decrease.indent",
                        isEnabled: canOutdent,
                        action: { outdent() }
                    )
                    
                    Divider()
                        .frame(height: 20)
                        .background(Color(.separator))
                    
                    // Font Size
                    ToolbarButton(
                        icon: "textformat.size.smaller",
                        action: { decreaseFontSize() }
                    )
                    
                    ToolbarButton(
                        icon: "textformat.size.larger",
                        action: { increaseFontSize() }
                    )
                    
                    Divider()
                        .frame(height: 20)
                        .background(Color(.separator))
                    
                    // Text Color
                    Button(action: { toggleTextColor() }) {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(cachedCurrentTextColor)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(cachedIsTextColored ? Color.accentColor : Color(.systemGray5))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                                    )
                            )
                    }
                    
                    // Highlight
                    ToolbarButton(
                        icon: "highlighter",
                        isSelected: cachedIsHighlighted,
                        action: { toggleHighlight() }
                    )
                    
                    Divider()
                        .frame(height: 20)
                        .background(Color(.separator))
                    
                    // Alignment
                    ToolbarButton(
                        icon: "text.alignleft",
                        isSelected: cachedAlignment == .left,
                        action: { setAlignment(.left) }
                    )
                    
                    ToolbarButton(
                        icon: "text.aligncenter",
                        isSelected: cachedAlignment == .center,
                        action: { setAlignment(.center) }
                    )
                    
                    ToolbarButton(
                        icon: "text.alignright",
                        isSelected: cachedAlignment == .right,
                        action: { setAlignment(.right) }
                    )
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .overlay(
                // Top border line
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 0.5),
                alignment: .top
            )
        }
        .onAppear {
            updateCachedAttributes()
        }
        .onChange(of: selectedRange) { _ in
            updateCachedAttributes()
        }
    }
    
    // MARK: - Helper Functions
    private func updateCachedAttributes() {
        cachedIsBold = isBold()
        cachedIsItalic = isItalic()
        cachedIsUnderlined = isUnderlined()
        cachedCurrentTextColor = currentTextColor()
        cachedIsTextColored = isTextColored()
        cachedIsHighlighted = isHighlighted()
        cachedAlignment = alignment()
    }
    
    private func isBold() -> Bool {
        guard let font = currentAttributes[.font] as? UIFont else { return false }
        return font.fontDescriptor.symbolicTraits.contains(.traitBold)
    }
    
    private func isItalic() -> Bool {
        guard let font = currentAttributes[.font] as? UIFont else { return false }
        return font.fontDescriptor.symbolicTraits.contains(.traitItalic)
    }
    
    private func isUnderlined() -> Bool {
        return currentAttributes[.underlineStyle] != nil
    }
    
    private func currentTextColor() -> Color {
        if let color = currentAttributes[.foregroundColor] as? UIColor {
            return Color(color)
        }
        return .primary
    }
    
    private func isTextColored() -> Bool {
        return currentAttributes[.foregroundColor] != nil && 
               currentAttributes[.foregroundColor] as? UIColor != UIColor.label
    }
    
    private func isHighlighted() -> Bool {
        return currentAttributes[.backgroundColor] != nil
    }
    
    private func alignment() -> NSTextAlignment {
        if let paragraphStyle = currentAttributes[.paragraphStyle] as? NSParagraphStyle {
            return paragraphStyle.alignment
        }
        return .left
    }
    
    private var isBulletList: Bool {
        let text = attributedText.string
        let cursorPosition = selectedRange.location
        let lines = text.components(separatedBy: .newlines)
        var currentLineIndex = 0
        var currentPosition = 0
        
        for (index, line) in lines.enumerated() {
            let lineEndPosition = currentPosition + line.count
            if lineEndPosition >= cursorPosition {
                currentLineIndex = index
                break
            }
            currentPosition = lineEndPosition + 1 // +1 for newline character
        }
        
        if currentLineIndex < lines.count {
            let currentLine = lines[currentLineIndex]
            return currentLine.hasPrefix("• ") || currentLine.hasPrefix("◦ ") || currentLine.hasPrefix("▪ ")
        }
        return false
    }
    
    private var canIndent: Bool {
        let text = attributedText.string
        let cursorPosition = selectedRange.location
        let lines = text.components(separatedBy: .newlines)
        var currentPosition = 0
        var currentLineIndex = 0
        
        for (index, line) in lines.enumerated() {
            let lineEndPosition = currentPosition + line.count
            if lineEndPosition >= cursorPosition {
                currentLineIndex = index
                break
            }
            currentPosition = lineEndPosition + 1
        }
        
        if currentLineIndex < lines.count {
            let currentLine = lines[currentLineIndex]
            return !currentLine.isEmpty && (currentLine.hasPrefix("• ") || currentLine.hasPrefix("◦ ") || currentLine.hasPrefix("▪ ") || !currentLine.hasPrefix("    "))
        }
        return false
    }
    
    private var canOutdent: Bool {
        let text = attributedText.string
        let cursorPosition = selectedRange.location
        let lines = text.components(separatedBy: .newlines)
        var currentPosition = 0
        var currentLineIndex = 0
        
        for (index, line) in lines.enumerated() {
            let lineEndPosition = currentPosition + line.count
            if lineEndPosition >= cursorPosition {
                currentLineIndex = index
                break
            }
            currentPosition = lineEndPosition + 1
        }
        
        if currentLineIndex < lines.count {
            let currentLine = lines[currentLineIndex]
            return currentLine.hasPrefix("• ") || currentLine.hasPrefix("◦ ") || currentLine.hasPrefix("▪ ") || currentLine.hasPrefix("    ") || currentLine.hasPrefix("  ")
        }
        return false
    }
    
    // MARK: - Actions
    private func undo() {
        guard !undoStack.isEmpty else { return }
        
        let currentState = attributedText
        redoStack.append(currentState)
        
        if redoStack.count > maxUndoActions {
            redoStack.removeFirst()
        }
        
        attributedText = undoStack.removeLast()
    }
    
    private func redo() {
        guard !redoStack.isEmpty else { return }
        
        let currentState = attributedText
        undoStack.append(currentState)
        
        if undoStack.count > maxUndoActions {
            undoStack.removeFirst()
        }
        
        attributedText = redoStack.removeLast()
    }
    
    private func toggleBold() {
        saveUndoState()
        let currentFont = currentAttributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: 16)
        var traits = currentFont.fontDescriptor.symbolicTraits
        
        if traits.contains(.traitBold) {
            traits = traits.subtracting(.traitBold)
        } else {
            traits = traits.union(.traitBold)
        }
        
        if let newFontDescriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
            let newFont = UIFont(descriptor: newFontDescriptor, size: currentFont.pointSize)
            applyAttributes([.font: newFont])
        }
    }
    
    private func toggleItalic() {
        saveUndoState()
        let currentFont = currentAttributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: 16)
        var traits = currentFont.fontDescriptor.symbolicTraits
        
        if traits.contains(.traitItalic) {
            traits = traits.subtracting(.traitItalic)
        } else {
            traits = traits.union(.traitItalic)
        }
        
        if let newFontDescriptor = currentFont.fontDescriptor.withSymbolicTraits(traits) {
            let newFont = UIFont(descriptor: newFontDescriptor, size: currentFont.pointSize)
            applyAttributes([.font: newFont])
        }
    }
    
    private func toggleUnderline() {
        saveUndoState()
        let underlineStyle = isUnderlined() ? [] : NSUnderlineStyle.single
        applyAttributes([.underlineStyle: underlineStyle])
    }
    
    private func toggleBulletList() {
        saveUndoState()
        let text = attributedText.string
        let lines = text.components(separatedBy: .newlines)
        var newLines: [String] = []
        
        for (index, line) in lines.enumerated() {
            if index == getCurrentLineIndex() {
                if line.hasPrefix("• ") || line.hasPrefix("◦ ") || line.hasPrefix("▪ ") {
                    // Remove bullet point
                    let trimmedLine = String(line.dropFirst(2))
                    newLines.append(trimmedLine)
                } else {
                    // Add bullet point
                    newLines.append("• \(line)")
                }
            } else {
                newLines.append(line)
            }
        }
        
        let newText = newLines.joined(separator: "\n")
        attributedText = NSAttributedString(string: newText)
    }
    
    private func indent() {
        saveUndoState()
        let text = attributedText.string
        let lines = text.components(separatedBy: .newlines)
        var newLines: [String] = []
        
        for (index, line) in lines.enumerated() {
            if index == getCurrentLineIndex() {
                if line.hasPrefix("• ") {
                    newLines.append("◦ \(String(line.dropFirst(2)))")
                } else if line.hasPrefix("◦ ") {
                    newLines.append("▪ \(String(line.dropFirst(2)))")
                } else if line.hasPrefix("▪ ") {
                    newLines.append("    \(line)") // Convert to regular indentation
                } else if !line.isEmpty {
                    newLines.append("    \(line)") // 4 spaces for regular indentation
                } else {
                    newLines.append(line)
                }
            } else {
                newLines.append(line)
            }
        }
        
        let newText = newLines.joined(separator: "\n")
        attributedText = NSAttributedString(string: newText)
    }
    
    private func outdent() {
        saveUndoState()
        let text = attributedText.string
        let lines = text.components(separatedBy: .newlines)
        var newLines: [String] = []
        
        for (index, line) in lines.enumerated() {
            if index == getCurrentLineIndex() {
                if line.hasPrefix("▪ ") {
                    newLines.append("◦ \(String(line.dropFirst(2)))")
                } else if line.hasPrefix("◦ ") {
                    newLines.append("• \(String(line.dropFirst(2)))")
                } else if line.hasPrefix("• ") {
                    newLines.append(String(line.dropFirst(2)))
                } else if line.hasPrefix("    ") {
                    newLines.append(String(line.dropFirst(4)))
                } else if line.hasPrefix("  ") {
                    newLines.append(String(line.dropFirst(2)))
                } else {
                    newLines.append(line)
                }
            } else {
                newLines.append(line)
            }
        }
        
        let newText = newLines.joined(separator: "\n")
        attributedText = NSAttributedString(string: newText)
    }
    
    private func getCurrentLineIndex() -> Int {
        let text = attributedText.string
        let cursorPosition = selectedRange.location
        let lines = text.components(separatedBy: .newlines)
        var currentPosition = 0
        
        for (index, line) in lines.enumerated() {
            let lineEndPosition = currentPosition + line.count
            if lineEndPosition >= cursorPosition {
                return index
            }
            currentPosition = lineEndPosition + 1 // +1 for newline character
        }
        
        return lines.count - 1
    }
    
    private func decreaseFontSize() {
        saveUndoState()
        let currentFont = currentAttributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: 16)
        let newSize = max(8, currentFont.pointSize - 2)
        let newFont = currentFont.withSize(newSize)
        applyAttributes([.font: newFont])
    }
    
    private func increaseFontSize() {
        saveUndoState()
        let currentFont = currentAttributes[.font] as? UIFont ?? UIFont.systemFont(ofSize: 16)
        let newSize = min(72, currentFont.pointSize + 2)
        let newFont = currentFont.withSize(newSize)
        applyAttributes([.font: newFont])
    }
    
    private func toggleTextColor() {
        saveUndoState()
        let colors: [UIColor] = [.systemBlue, .systemRed, .systemGreen, .systemOrange, .systemPurple, .label]
        let currentColor = currentAttributes[.foregroundColor] as? UIColor ?? .label
        
        if let currentIndex = colors.firstIndex(of: currentColor) {
            let nextIndex = (currentIndex + 1) % colors.count
            applyAttributes([.foregroundColor: colors[nextIndex]])
        } else {
            applyAttributes([.foregroundColor: colors[0]])
        }
    }
    
    private func toggleHighlight() {
        saveUndoState()
        if isHighlighted() {
            applyAttributes([.backgroundColor: NSNull()])
        } else {
            applyAttributes([.backgroundColor: UIColor.systemYellow.withAlphaComponent(0.3)])
        }
    }
    
    private func setAlignment(_ alignment: NSTextAlignment) {
        saveUndoState()
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        applyAttributes([.paragraphStyle: paragraphStyle])
    }
    
    private func saveUndoState() {
        undoStack.append(attributedText)
        redoStack.removeAll() // Clear redo stack when new action is performed
        
        if undoStack.count > maxUndoActions {
            undoStack.removeFirst()
        }
    }
    
    private func applyAttributes(_ attributes: [NSAttributedString.Key: Any]) {
        let range = selectedRange.length > 0 ? selectedRange : NSRange(location: selectedRange.location, length: 0)
        let mutableString = NSMutableAttributedString(attributedString: attributedText)
        
        for (key, value) in attributes {
            if value is NSNull {
                mutableString.removeAttribute(key, range: range)
            } else {
                mutableString.addAttribute(key, value: value, range: range)
            }
        }
        
        DispatchQueue.main.async {
            attributedText = mutableString
        }
    }
}

// MARK: - Enhanced Toolbar Button
struct ToolbarButton: View {
    let icon: String
    var isSelected: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(
                    isSelected ? .white : 
                    isEnabled ? .primary : .secondary
                )
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            isSelected ? Color.accentColor : 
                            isEnabled ? Color(.systemGray5) : Color(.systemGray6)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                )
        }
        .disabled(!isEnabled)
    }
}

// MARK: - Enhanced Rich Text View Representable
struct RichTextViewRepresentable: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @Binding var selectedRange: NSRange
    @Binding var currentAttributes: [NSAttributedString.Key: Any]
    @Binding var undoStack: [NSAttributedString]
    @Binding var redoStack: [NSAttributedString]
    let maxUndoActions: Int
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 16)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 80, right: 16) // Extra bottom padding for toolbar
        textView.isScrollEnabled = true
        textView.alwaysBounceVertical = true
        textView.attributedText = attributedText
        textView.allowsEditingTextAttributes = true
        textView.keyboardDismissMode = .none // Prevent automatic keyboard dismissal
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != attributedText {
            uiView.attributedText = attributedText
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextViewRepresentable
        private var lastText = ""
        private var shouldSaveUndoState = true
        
        init(_ parent: RichTextViewRepresentable) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            let currentText = textView.text ?? ""
            
            // Handle bullet point continuation
            if currentText != lastText {
                handleBulletPointContinuation(textView: textView, currentText: currentText)
            }
            
            // Use DispatchQueue.main.async to avoid state modification during view updates
            DispatchQueue.main.async { [self] in
                parent.attributedText = textView.attributedText
                lastText = currentText
                
                // Save undo state for significant changes
                if shouldSaveUndoState {
                    saveUndoState()
                }
                shouldSaveUndoState = true
            }
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            // Use DispatchQueue.main.async to avoid state modification during view updates
            DispatchQueue.main.async { [self] in
                parent.selectedRange = textView.selectedRange
                updateCurrentAttributes()
            }
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Handle Enter key for bullet points
            if text == "\n" {
                return handleEnterKey(textView: textView, range: range)
            }
            
            return true
        }
        
        private func handleEnterKey(textView: UITextView, range: NSRange) -> Bool {
            let currentText = textView.text ?? ""
            let lines = currentText.components(separatedBy: .newlines)
            let cursorPosition = range.location
            
            // Find current line
            var currentPosition = 0
            var currentLineIndex = 0
            
            for (index, line) in lines.enumerated() {
                let lineEndPosition = currentPosition + line.count
                if lineEndPosition >= cursorPosition {
                    currentLineIndex = index
                    break
                }
                currentPosition = lineEndPosition + 1 // +1 for newline character
            }
            
            if currentLineIndex < lines.count {
                let currentLine = lines[currentLineIndex]
                
                // Check if current line starts with bullet point
                if currentLine.hasPrefix("• ") || currentLine.hasPrefix("◦ ") || currentLine.hasPrefix("▪ ") {
                    // Extract indentation level
                    let bulletChar = currentLine.prefix(2)
                    let insertText = "\n\(bulletChar)"
                    
                    // Insert the new bullet point
                    textView.text = (textView.text ?? "").replacingCharacters(in: Range(range, in: textView.text ?? "")!, with: insertText)
                    
                    // Move cursor to after the bullet point
                    let newPosition = range.location + insertText.count
                    textView.selectedRange = NSRange(location: newPosition, length: 0)
                    
                    return false // We handled the insertion
                }
            }
            
            return true // Allow normal Enter key behavior
        }
        
        private func handleBulletPointContinuation(textView: UITextView, currentText: String) {
            // This method can be expanded for more complex bullet point handling
            // For now, we rely on the Enter key handling above
        }
        
        private func updateCurrentAttributes() {
            if parent.selectedRange.length > 0 {
                parent.currentAttributes = parent.attributedText.attributes(at: parent.selectedRange.location, effectiveRange: nil)
            } else {
                parent.currentAttributes = [:]
            }
        }
        
        private func saveUndoState() {
            DispatchQueue.main.async { [self] in
                parent.undoStack.append(parent.attributedText)
                parent.redoStack.removeAll() // Clear redo stack when new action is performed
                
                if parent.undoStack.count > parent.maxUndoActions {
                    parent.undoStack.removeFirst()
                }
            }
        }
    }
}