//
//  NotesViews.swift
//  Slate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Notes Feature Views

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [Note]
    @Query private var folders: [Folder]
    @StateObject private var notesManager = NotesManager()
    @State private var searchText = ""
    @State private var showingNewNote = false
    @State private var selectedNote: Note?
    @State private var showingFolderSheet = false
    
    var filteredNotes: [Note] {
        let folderFiltered = notesManager.selectedFolder == nil ? 
            notes : 
            notes.filter { $0.folder?.id == notesManager.selectedFolder?.id }
        
        if searchText.isEmpty {
            return folderFiltered.sorted { ($0.modifiedDate) > ($1.modifiedDate) }
        }
        
        return folderFiltered.filter { note in
            note.title.localizedCaseInsensitiveContains(searchText) ||
            note.attributedContent.string.localizedCaseInsensitiveContains(searchText)
        }.sorted { ($0.modifiedDate) > ($1.modifiedDate) }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredNotes, id: \.id) { note in
                    NavigationLink(destination: RichTextEditorView(note: note)) {
                        NoteRowView(note: note)
                    }
                }
                .onDelete(perform: deleteNotes)
            }
            .searchable(text: $searchText, prompt: "Search notes")
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("All Notes") {
                            notesManager.selectedFolder = nil
                        }
                        Divider()
                        ForEach(folders, id: \.id) { folder in
                            Button(folder.name) {
                                notesManager.selectedFolder = folder
                            }
                        }
                        Divider()
                        Button("New Folder") {
                            showingFolderSheet = true
                        }
                    } label: {
                        Label("Folders", systemImage: "folder")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        let newNote = notesManager.createNote(with: modelContext)
                        selectedNote = newNote
                        showingNewNote = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $showingFolderSheet) {
                NewFolderView(notesManager: notesManager)
            }
            .sheet(item: $selectedNote) { note in
                NavigationView {
                    RichTextEditorView(note: note)
                }
            }
            
            if filteredNotes.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "note.text")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
                    Text("No Notes Yet")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Text("Tap the + button to create your first note")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    
    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            let note = filteredNotes[index]
            notesManager.deleteNote(note, with: modelContext)
        }
    }
}

// MARK: - Note Row View
struct NoteRowView: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title)
                .font(.headline)
                .lineLimit(1)
            
            Text(note.attributedContent.string)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack {
                if let folder = note.folder {
                    Label(folder.name, systemImage: "folder.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                Text(note.modifiedDate, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - New Folder View
struct NewFolderView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var folderName = ""
    let notesManager: NotesManager
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Folder Name", text: $folderName)
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        notesManager.createFolder(name: folderName, with: modelContext)
                        dismiss()
                    }
                    .disabled(folderName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Rich Text Editor View
struct RichTextEditorView: View {
    var note: Note
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel: RichTextViewModel
    @State private var noteTitle: String
    @State private var selectedColor: Color = .black
    @State private var showingFolderPicker = false
    
    init(note: Note) {
        self.note = note
        _noteTitle = State(initialValue: note.title)
        _viewModel = StateObject(wrappedValue: RichTextViewModel(note: note))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Title Field
            TextField("Title", text: $noteTitle)
                .font(.title2)
                .fontWeight(.bold)
                .padding()
                .background(Color(.systemGray6))
            
            // Text Editor
            RichTextEditor(attributedText: $viewModel.attributedText, viewModel: viewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .overlay(
            // Native iOS-style formatting toolbar that appears above keyboard
            VStack {
                Spacer()
                if viewModel.isKeyboardVisible {
                    FormattingToolbarView(viewModel: viewModel)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.isKeyboardVisible)
        )
        .navigationTitle("Edit Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button("Move to...") {
                        showingFolderPicker = true
                    }
                    
                    Button(role: .destructive) {
                        modelContext.delete(note)
                        try? modelContext.save()
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    saveNote()
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingFolderPicker) {
            FolderPickerView(note: note)
        }
        .onDisappear {
            saveNote()
        }
    }
    
    private func saveNote() {
        note.title = noteTitle
        note.attributedContent = viewModel.attributedText
        note.modifiedDate = Date()
        try? modelContext.save()
    }
}

// MARK: - Folder Picker View
struct FolderPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var folders: [Folder]
    let note: Note
    
    var body: some View {
        NavigationView {
            List {
                Button("No Folder") {
                    note.folder = nil
                    try? modelContext.save()
                    dismiss()
                }
                
                ForEach(folders, id: \.id) { folder in
                    Button {
                        note.folder = folder
                        try? modelContext.save()
                        dismiss()
                    } label: {
                        HStack {
                            Label(folder.name, systemImage: "folder.fill")
                            Spacer()
                            if note.folder?.id == folder.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Move to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Formatting Toolbar View
struct FormattingToolbarView: View {
    @ObservedObject var viewModel: RichTextViewModel
    @State private var selectedColor = Color.primary
    @State private var showColorPicker = false
    @State private var showFontSizeMenu = false
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Bold, Italic, Underline, Strikethrough
                FormatButton(icon: "bold", isActive: viewModel.isBold) {
                    viewModel.toggleBold()
                }
                
                FormatButton(icon: "italic", isActive: viewModel.isItalic) {
                    viewModel.toggleItalic()
                }
                
                FormatButton(icon: "underline", isActive: viewModel.isUnderline) {
                    viewModel.toggleUnderline()
                }
                
                FormatButton(icon: "strikethrough", isActive: viewModel.isStrikethrough) {
                    viewModel.toggleStrikethrough()
                }
                
                Divider()
                    .frame(height: 24)
                
                // Font Size
                Menu {
                    Button("Small") { viewModel.setFontSize(14) }
                    Button("Normal") { viewModel.setFontSize(17) }
                    Button("Large") { viewModel.setFontSize(22) }
                    Button("Huge") { viewModel.setFontSize(28) }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "textformat.size")
                        Text("\(Int(viewModel.currentFontSize))")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                
                // Text Color
                ColorPicker("Text Color", selection: $selectedColor)
                    .labelsHidden()
                    .frame(width: 32, height: 32)
                    .onChange(of: selectedColor) { _, newColor in
                        viewModel.setTextColor(newColor)
                    }
                
                Divider()
                    .frame(height: 24)
                
                // Bullet Lists
                FormatButton(icon: "list.bullet", isActive: viewModel.isBulletList) {
                    viewModel.toggleBulletList()
                }
                
                FormatButton(icon: "list.number", isActive: viewModel.isNumberedList) {
                    viewModel.toggleNumberedList()
                }
                
                Divider()
                    .frame(height: 24)
                
                // Text Alignment
                FormatButton(icon: "text.alignleft", isActive: viewModel.alignment == .left) {
                    viewModel.setAlignment(.left)
                }
                
                FormatButton(icon: "text.aligncenter", isActive: viewModel.alignment == .center) {
                    viewModel.setAlignment(.center)
                }
                
                FormatButton(icon: "text.alignright", isActive: viewModel.alignment == .right) {
                    viewModel.setAlignment(.right)
                }
                
                Divider()
                    .frame(height: 24)
                
                // Undo/Redo
                FormatButton(icon: "arrow.uturn.backward", isActive: false) {
                    viewModel.undo()
                }
                .disabled(!viewModel.canUndo)
                
                FormatButton(icon: "arrow.uturn.forward", isActive: false) {
                    viewModel.redo()
                }
                .disabled(!viewModel.canRedo)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .top
        )
    }
}

// MARK: - Format Button Component
struct FormatButton: View {
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isActive ? .white : .primary)
                .frame(width: 44, height: 44)
                .background(isActive ? Color.accentColor : Color.clear)
                .cornerRadius(8)
        }
        .disabled(!isActive && icon.contains("arrow.uturn"))
    }
}

// MARK: - UITextView Wrapper
struct RichTextEditor: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var viewModel: RichTextViewModel
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 17)
        textView.isScrollEnabled = true
        textView.isEditable = true
        textView.isUserInteractionEnabled = true
        textView.backgroundColor = .systemBackground
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        textView.allowsEditingTextAttributes = true
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != attributedText {
            let selectedRange = uiView.selectedRange
            uiView.attributedText = attributedText
            if selectedRange.location <= uiView.attributedText.length {
                uiView.selectedRange = selectedRange
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextEditor
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.attributedText = textView.attributedText
            parent.viewModel.textView = textView
            // Use async to avoid publishing during view updates
            DispatchQueue.main.async { [weak self] in
                self?.parent.viewModel.updateCurrentAttributes()
            }
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.viewModel.textView = textView
            // Use async to avoid publishing during view updates
            DispatchQueue.main.async { [weak self] in
                self?.parent.viewModel.updateCurrentAttributes()
            }
        }
        
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // Handle bullet point auto-continuation
            if text == "\n" {
                let currentLine = getCurrentLine(textView: textView, at: range.location)
                let bulletPattern = "^\\s*[•▪▫]\\s+"
                let numberPattern = "^\\s*\\d+\\.\\s+"
                
                if let regex = try? NSRegularExpression(pattern: bulletPattern) {
                    let matches = regex.matches(in: currentLine, range: NSRange(location: 0, length: currentLine.count))
                    if !matches.isEmpty {
                        // Continue bullet point
                        let bulletText = "• "
                        DispatchQueue.main.async {
                            textView.insertText(bulletText)
                        }
                        return false
                    }
                }
                
                if let regex = try? NSRegularExpression(pattern: numberPattern) {
                    let matches = regex.matches(in: currentLine, range: NSRange(location: 0, length: currentLine.count))
                    if !matches.isEmpty {
                        // Continue numbered list
                        let numberMatch = matches[0]
                        let numberText = (currentLine as NSString).substring(with: numberMatch.range)
                        let nextNumber = getNextNumber(from: numberText)
                        let newNumberText = "\(nextNumber). "
                        DispatchQueue.main.async {
                            textView.insertText(newNumberText)
                        }
                        return false
                    }
                }
            }
            
            return true
        }
        
        private func getCurrentLine(textView: UITextView, at location: Int) -> String {
            let text = textView.text as NSString
            let lineRange = text.lineRange(for: NSRange(location: location, length: 0))
            return text.substring(with: lineRange)
        }
        
        private func getNextNumber(from numberText: String) -> Int {
            let numberPattern = "\\d+"
            if let regex = try? NSRegularExpression(pattern: numberPattern),
               let match = regex.firstMatch(in: numberText, range: NSRange(location: 0, length: numberText.count)) {
                let numberString = (numberText as NSString).substring(with: match.range)
                return (Int(numberString) ?? 1) + 1
            }
            return 2
        }
    }
}

// MARK: - View Model
class RichTextViewModel: ObservableObject {
    @Published var attributedText: NSAttributedString
    @Published var isBold = false
    @Published var isItalic = false
    @Published var isUnderline = false
    @Published var isStrikethrough = false
    @Published var isBulletList = false
    @Published var isNumberedList = false
    @Published var currentFontSize: CGFloat = 17
    @Published var alignment: NSTextAlignment = .left
    @Published var canUndo = false
    @Published var canRedo = false
    @Published var isKeyboardVisible = false
    
    // Formatting state for future typing
    @Published var boldState = false
    @Published var italicState = false
    @Published var underlineState = false
    @Published var strikethroughState = false
    @Published var textColorState: UIColor = .label
    @Published var fontSizeState: CGFloat = 17
    @Published var alignmentState: NSTextAlignment = .left
    
    weak var textView: UITextView?
    private let note: Note
    
    init(note: Note) {
        self.note = note
        self.attributedText = note.attributedContent
        setupKeyboardObservers()
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillShowNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isKeyboardVisible = true
        }
        
        NotificationCenter.default.addObserver(
            forName: UIResponder.keyboardWillHideNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.isKeyboardVisible = false
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func updateCurrentAttributes() {
        guard let textView = textView else { return }
        
        canUndo = textView.undoManager?.canUndo ?? false
        canRedo = textView.undoManager?.canRedo ?? false
        
        let selectedRange = textView.selectedRange
        let length = textView.attributedText.length
        
        guard length > 0 else {
            resetAttributes()
            return
        }
        
        let location = min(selectedRange.location, length - 1)
        let attributes = textView.attributedText.attributes(at: location, effectiveRange: nil)
        
        if let font = attributes[.font] as? UIFont {
            isBold = font.fontDescriptor.symbolicTraits.contains(.traitBold)
            isItalic = font.fontDescriptor.symbolicTraits.contains(.traitItalic)
            
            // Validate font size to prevent NaN
            let fontSize = font.pointSize.isFinite && font.pointSize > 0 ? font.pointSize : 17
            currentFontSize = fontSize
            
            // Update state variables when cursor is in text
            if selectedRange.length == 0 {
                boldState = isBold
                italicState = isItalic
                fontSizeState = fontSize
            }
        }
        
        isUnderline = (attributes[.underlineStyle] as? Int) == NSUnderlineStyle.single.rawValue
        isStrikethrough = (attributes[.strikethroughStyle] as? Int) == NSUnderlineStyle.single.rawValue
        
        if selectedRange.length == 0 {
            underlineState = isUnderline
            strikethroughState = isStrikethrough
        }
        
        if let paragraphStyle = attributes[.paragraphStyle] as? NSParagraphStyle {
            alignment = paragraphStyle.alignment
            if selectedRange.length == 0 {
                alignmentState = alignment
            }
        }
        
        if let color = attributes[.foregroundColor] as? UIColor {
            if selectedRange.length == 0 {
                textColorState = color
            }
        }
    }
    
    func resetAttributes() {
        isBold = false
        isItalic = false
        isUnderline = false
        isStrikethrough = false
        currentFontSize = 17
        alignment = .left
        
        // Also reset state variables
        boldState = false
        italicState = false
        underlineState = false
        strikethroughState = false
        fontSizeState = 17
        alignmentState = .left
        textColorState = .label
    }
    
    func undo() {
        guard let textView = textView else { return }
        if textView.undoManager?.canUndo == true {
            textView.undoManager?.undo()
            DispatchQueue.main.async {
                self.updateCurrentAttributes()
            }
        }
    }
    
    func redo() {
        guard let textView = textView else { return }
        if textView.undoManager?.canRedo == true {
            textView.undoManager?.redo()
            DispatchQueue.main.async {
                self.updateCurrentAttributes()
            }
        }
    }
    
    
    func toggleBold() {
        guard let textView = textView else { return }
        let range = textView.selectedRange
        
        if range.length > 0 {
            // Apply to selected text
            applyFontTrait(.traitBold)
        } else {
            // Toggle state for future typing
            boldState.toggle()
            isBold = boldState
            updateTypingAttributes()
        }
    }
    
    func toggleItalic() {
        guard let textView = textView else { return }
        let range = textView.selectedRange
        
        if range.length > 0 {
            // Apply to selected text
            applyFontTrait(.traitItalic)
        } else {
            // Toggle state for future typing
            italicState.toggle()
            isItalic = italicState
            updateTypingAttributes()
        }
    }
    
    func toggleUnderline() {
        guard let textView = textView else { return }
        let range = textView.selectedRange
        
        if range.length > 0 {
            // Apply to selected text
            let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
            let currentValue = mutableAttr.attribute(.underlineStyle, at: range.location, effectiveRange: nil) as? Int
            
            if currentValue == NSUnderlineStyle.single.rawValue {
                mutableAttr.removeAttribute(.underlineStyle, range: range)
            } else {
                mutableAttr.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
            
            attributedText = mutableAttr
            updateCurrentAttributes()
        } else {
            // Toggle state for future typing
            underlineState.toggle()
            isUnderline = underlineState
            updateTypingAttributes()
        }
    }
    
    func toggleStrikethrough() {
        guard let textView = textView else { return }
        let range = textView.selectedRange
        
        if range.length > 0 {
            // Apply to selected text
            let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
            let currentValue = mutableAttr.attribute(.strikethroughStyle, at: range.location, effectiveRange: nil) as? Int
            
            if currentValue == NSUnderlineStyle.single.rawValue {
                mutableAttr.removeAttribute(.strikethroughStyle, range: range)
            } else {
                mutableAttr.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            }
            
            attributedText = mutableAttr
            updateCurrentAttributes()
        } else {
            // Toggle state for future typing
            strikethroughState.toggle()
            isStrikethrough = strikethroughState
            updateTypingAttributes()
        }
    }
    
    func setFontSize(_ size: CGFloat) {
        guard let textView = textView else { return }
        let range = textView.selectedRange
        
        // Validate font size to prevent NaN
        let validSize = size.isFinite && size > 0 ? max(8, min(72, size)) : 17
        
        fontSizeState = validSize
        currentFontSize = validSize
        
        if range.length > 0 {
            // Apply to selected text
            let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
            
            mutableAttr.enumerateAttribute(.font, in: range) { value, subRange, _ in
                if let font = value as? UIFont {
                    let newFont = font.withSize(validSize)
                    mutableAttr.addAttribute(.font, value: newFont, range: subRange)
                }
            }
            
            attributedText = mutableAttr
        } else {
            // Update typing attributes for future text
            updateTypingAttributes()
        }
    }
    
    func setTextColor(_ color: Color) {
        guard let textView = textView else { return }
        let range = textView.selectedRange
        
        textColorState = UIColor(color)
        
        if range.length > 0 {
            // Apply to selected text
            let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
            mutableAttr.addAttribute(.foregroundColor, value: UIColor(color), range: range)
            attributedText = mutableAttr
        } else {
            // Update typing attributes for future text
            updateTypingAttributes()
        }
    }
    
    func setAlignment(_ newAlignment: NSTextAlignment) {
        guard let textView = textView else { return }
        let range = textView.selectedRange
        
        alignmentState = newAlignment
        alignment = newAlignment
        
        let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = newAlignment
        
        let paragraphRange = (mutableAttr.string as NSString).paragraphRange(for: range)
        mutableAttr.addAttribute(.paragraphStyle, value: paragraphStyle, range: paragraphRange)
        
        attributedText = mutableAttr
        updateTypingAttributes()
    }
    
    func toggleBulletList() {
        guard let textView = textView else { return }
        let range = textView.selectedRange
        
        let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
        let paragraphRange = (mutableAttr.string as NSString).paragraphRange(for: range)
        let paragraphText = (mutableAttr.string as NSString).substring(with: paragraphRange)
        
        if paragraphText.hasPrefix("• ") {
            let newText = paragraphText.replacingOccurrences(of: "• ", with: "")
            mutableAttr.replaceCharacters(in: paragraphRange, with: newText)
        } else {
            let newText = "• " + paragraphText
            mutableAttr.replaceCharacters(in: paragraphRange, with: newText)
        }
        
        attributedText = mutableAttr
    }
    
    func toggleNumberedList() {
        guard let textView = textView else { return }
        let range = textView.selectedRange
        
        let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
        let paragraphRange = (mutableAttr.string as NSString).paragraphRange(for: range)
        let paragraphText = (mutableAttr.string as NSString).substring(with: paragraphRange)
        
        let numberPattern = "^\\d+\\. "
        if let regex = try? NSRegularExpression(pattern: numberPattern),
           regex.firstMatch(in: paragraphText, range: NSRange(location: 0, length: paragraphText.count)) != nil {
            let newText = paragraphText.replacingOccurrences(of: regex.pattern, with: "", options: .regularExpression)
            mutableAttr.replaceCharacters(in: paragraphRange, with: newText)
        } else {
            let newText = "1. " + paragraphText
            mutableAttr.replaceCharacters(in: paragraphRange, with: newText)
        }
        
        attributedText = mutableAttr
    }
    
    private func applyFontTrait(_ trait: UIFontDescriptor.SymbolicTraits) {
        guard let textView = textView else { return }
        let range = textView.selectedRange
        
        if range.length == 0 { return }
        
        let mutableAttr = NSMutableAttributedString(attributedString: textView.attributedText)
        
        mutableAttr.enumerateAttribute(.font, in: range) { value, subRange, _ in
            guard let font = value as? UIFont else { return }
            
            var traits = font.fontDescriptor.symbolicTraits
            if traits.contains(trait) {
                traits.remove(trait)
            } else {
                traits.insert(trait)
            }
            
            // Validate font size to prevent NaN
            let fontSize = font.pointSize.isFinite && font.pointSize > 0 ? font.pointSize : 17
            
            if let newDescriptor = font.fontDescriptor.withSymbolicTraits(traits) {
                let newFont = UIFont(descriptor: newDescriptor, size: fontSize)
                mutableAttr.addAttribute(.font, value: newFont, range: subRange)
            }
        }
        
        attributedText = mutableAttr
        // Use async to avoid publishing during view updates
        DispatchQueue.main.async {
            self.updateCurrentAttributes()
        }
    }
    
    // MARK: - Typing Attributes
    func updateTypingAttributes() {
        guard let textView = textView else { return }
        
        var attributes: [NSAttributedString.Key: Any] = [:]
        
        // Create font with current traits
        var fontTraits: UIFontDescriptor.SymbolicTraits = []
        if boldState { fontTraits.insert(.traitBold) }
        if italicState { fontTraits.insert(.traitItalic) }
        
        // Validate font size to prevent NaN
        let validFontSize = fontSizeState.isFinite && fontSizeState > 0 ? max(8, min(72, fontSizeState)) : 17
        let baseFont = UIFont.systemFont(ofSize: validFontSize)
        
        if fontTraits.isEmpty {
            attributes[.font] = baseFont
        } else {
            if let descriptor = baseFont.fontDescriptor.withSymbolicTraits(fontTraits) {
                attributes[.font] = UIFont(descriptor: descriptor, size: validFontSize)
            } else {
                attributes[.font] = baseFont
            }
        }
        
        // Add other attributes
        attributes[.foregroundColor] = textColorState
        
        if underlineState {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        
        if strikethroughState {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        
        // Paragraph style
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignmentState
        attributes[.paragraphStyle] = paragraphStyle
        
        textView.typingAttributes = attributes
    }
}
