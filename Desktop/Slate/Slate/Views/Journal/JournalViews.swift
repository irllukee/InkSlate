import SwiftUI
import UIKit
import SwiftData
import PhotosUI

// MARK: - Main Bookshelf View
struct BookshelfView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalBook.createdDate, order: .forward)
    private var books: [JournalBook]
    
    @State private var showingNewBookSheet = false
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ZStack {
                // Wooden bookshelf background
                Color(red: 0.55, green: 0.45, blue: 0.35)
                    .ignoresSafeArea()
                
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(books, id: \.id) { book in
                            NavigationLink(destination: JournalEntriesView(book: book)) {
                                BookSpineView(book: book)
                            }
                        }
                        
                        // Add new book button
                        Button {
                            showingNewBookSheet = true
                        } label: {
                            VStack {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                                Text("New Book")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            .frame(width: 100, height: 200)
                            .background(Color.gray.opacity(0.3))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 2)
                                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("My Journals")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingNewBookSheet) {
                NewBookView()
            }
        }
    }
}

// MARK: - Book Spine View
struct BookSpineView: View {
    let book: JournalBook
    
    var bookColor: Color {
        Color(hex: book.color) ?? .brown
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Spacer()
            
            // Book title (vertical)
            Text(book.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .rotationEffect(.degrees(-90))
                .fixedSize()
                .frame(maxHeight: .infinity)
            
            Spacer()
            
            // Last written date
            if let lastDate = book.lastWrittenDate {
                Text(lastDate, style: .date)
                    .font(.system(size: 8))
                    .foregroundColor(.white.opacity(0.8))
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
            }
            
            Spacer()
        }
        .frame(width: 100, height: 200)
        .background(
            ZStack {
                bookColor
                
                // Decorative pattern based on type
                if book.bookType == "dream" {
                    DreamBookPattern()
                } else {
                    RegularBookPattern()
                }
            }
        )
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.3), radius: 5, x: 2, y: 2)
        .overlay(
            // Book spine details
            VStack {
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 90, height: 2)
                    .padding(.top, 8)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 90, height: 2)
                    .padding(.bottom, 8)
            }
        )
    }
}

// MARK: - Dream Book Pattern
struct DreamBookPattern: View {
    var body: some View {
        ZStack {
            // Stars and moons
            ForEach(0..<8) { i in
                Image(systemName: i % 2 == 0 ? "moon.stars.fill" : "star.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.yellow.opacity(0.3))
                    .position(
                        x: CGFloat.random(in: 10...90),
                        y: CGFloat.random(in: 20...180)
                    )
            }
        }
    }
}

// MARK: - Regular Book Pattern
struct RegularBookPattern: View {
    var body: some View {
        ZStack {
            // Subtle lines pattern
            ForEach(0..<12) { i in
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 80, height: 1)
                    .position(x: 50, y: CGFloat(i * 16 + 10))
            }
        }
    }
}

// MARK: - New Book View
struct NewBookView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var title = ""
    @State private var bookType: BookType = .regular
    @State private var selectedColor = Color.brown
    
    enum BookType: String, CaseIterable {
        case dream = "Dream Journal"
        case regular = "Regular Journal"
    }
    
    let dreamColors: [Color] = [
        Color(red: 0.2, green: 0.2, blue: 0.5),
        Color(red: 0.3, green: 0.1, blue: 0.4),
        Color(red: 0.1, green: 0.3, blue: 0.5),
        Color(red: 0.4, green: 0.2, blue: 0.5)
    ]
    
    let regularColors: [Color] = [
        Color(red: 0.6, green: 0.3, blue: 0.2),
        Color(red: 0.2, green: 0.5, blue: 0.3),
        Color(red: 0.7, green: 0.4, blue: 0.2),
        Color(red: 0.5, green: 0.2, blue: 0.2)
    ]
    
    var availableColors: [Color] {
        bookType == .dream ? dreamColors : regularColors
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Book Details") {
                    TextField("Book Title", text: $title)
                    
                    Picker("Type", selection: $bookType) {
                        ForEach(BookType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .onChange(of: bookType) { _, _ in
                        selectedColor = availableColors.first ?? .brown
                    }
                }
                
                Section("Choose Color") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(availableColors, id: \.self) { color in
                                Circle()
                                    .fill(color)
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section("Preview") {
                    HStack {
                        Spacer()
                        BookSpinePreview(title: title.isEmpty ? "Preview" : title, color: selectedColor, bookType: bookType)
                        Spacer()
                    }
                    .listRowBackground(Color(red: 0.55, green: 0.45, blue: 0.35))
                }
            }
            .navigationTitle("New Journal Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let book = JournalBook(
                            title: title,
                            bookType: bookType == .dream ? "dream" : "regular",
                            color: selectedColor.toHex()
                        )
                        modelContext.insert(book)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Book Spine Preview
struct BookSpinePreview: View {
    let title: String
    let color: Color
    let bookType: NewBookView.BookType
    
    var body: some View {
        VStack(spacing: 4) {
            Spacer()
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .rotationEffect(.degrees(-90))
                .fixedSize()
                .frame(maxHeight: .infinity)
            Spacer()
        }
        .frame(width: 80, height: 160)
        .background(
            ZStack {
                color
                if bookType == .dream {
                    DreamBookPattern()
                } else {
                    RegularBookPattern()
                }
            }
        )
        .cornerRadius(8)
        .shadow(radius: 5)
    }
}

// MARK: - Journal Entries View
struct JournalEntriesView: View {
    let book: JournalBook
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewEntry = false
    @State private var searchText = ""
    
    @Query private var allEntries: [JournalEntry]
    
    private var filteredEntries: [JournalEntry] {
        let entries = allEntries.filter { $0.book?.id == book.id }
        if searchText.isEmpty {
            return entries.sorted { ($0.date) > ($1.date) }
        }
        return entries.filter { entry in
            entry.content.string.localizedCaseInsensitiveContains(searchText)
        }.sorted { ($0.date) > ($1.date) }
    }
    
    var body: some View {
        List {
            ForEach(filteredEntries, id: \.id) { entry in
                NavigationLink(destination: EntryEditorView(book: book, entry: entry)) {
                    EntryRowView(entry: entry, isDream: book.bookType == "dream")
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    let entry = filteredEntries[index]
                    modelContext.delete(entry)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search entries")
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingNewEntry = true
                } label: {
                    Image(systemName: "square.and.pencil")
                }
            }
        }
        .sheet(isPresented: $showingNewEntry) {
            NavigationView {
                EntryEditorView(book: book, entry: nil)
            }
        }
    }
}

// MARK: - Entry Row View
struct EntryRowView: View {
    let entry: JournalEntry
    let isDream: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(entry.date, style: .date)
                    .font(.headline)
                
                Spacer()
                
                if isDream {
                    Image(systemName: "moon.stars.fill")
                        .foregroundColor(.purple)
                }
            }
            
            Text(entry.content.string)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            HStack(spacing: 12) {
                Label("\(entry.moodRating)/10", systemImage: "face.smiling")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Label("\(entry.sleepQuality)/10", systemImage: "bed.double")
                    .font(.caption)
                    .foregroundColor(.purple)
                
                if entry.isLucidDream {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(.yellow)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Entry Editor View
struct EntryEditorView: View {
    let book: JournalBook
    let entry: JournalEntry?
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @StateObject private var viewModel: EntryViewModel
    @State private var showingImagePicker = false
    @State private var showingPrompts = false
    
    init(book: JournalBook, entry: JournalEntry?) {
        self.book = book
        self.entry = entry
        _viewModel = StateObject(wrappedValue: EntryViewModel(entry: entry, isDream: book.bookType == "dream"))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Photo attachment
                if let image = viewModel.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                        .overlay(
                            Button {
                                viewModel.selectedImage = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                            }
                            .padding(8),
                            alignment: .topTrailing
                        )
                }
                
                Button {
                    showingImagePicker = true
                } label: {
                    Label("Add Photo", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Mood Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "face.smiling")
                        Text("Mood: \(Int(viewModel.moodRating))/10")
                            .font(.headline)
                    }
                    Slider(value: $viewModel.moodRating, in: 1...10, step: 1)
                        .tint(.blue)
                }
                .padding(.horizontal)
                
                // Sleep Quality Slider
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "bed.double")
                        Text("Sleep Quality: \(Int(viewModel.sleepQuality))/10")
                            .font(.headline)
                    }
                    Slider(value: $viewModel.sleepQuality, in: 1...10, step: 1)
                        .tint(.purple)
                }
                .padding(.horizontal)
                
                // Dream-specific fields
                if book.bookType == "dream" {
                    VStack(spacing: 16) {
                        // Bed time
                        DatePicker("Bed Time", selection: $viewModel.bedTime, displayedComponents: .hourAndMinute)
                            .padding(.horizontal)
                        
                        // Wake time
                        DatePicker("Wake Time", selection: $viewModel.wakeTime, displayedComponents: .hourAndMinute)
                            .padding(.horizontal)
                        
                        // Lucid dream toggle
                        Toggle(isOn: $viewModel.isLucidDream) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.yellow)
                                Text("Lucid Dream")
                            }
                        }
                        .padding(.horizontal)
                        
                        // Dream tags
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Dream Tags")
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(DreamTag.allCases, id: \.self) { tag in
                                        TagButton(
                                            tag: tag.rawValue,
                                            isSelected: viewModel.selectedTags.contains(tag.rawValue),
                                            action: { viewModel.toggleTag(tag.rawValue) }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Writing prompts button
                Button {
                    showingPrompts = true
                } label: {
                    Label("Get Writing Prompt", systemImage: "lightbulb")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                // Rich text editor
                JournalRichTextEditor(attributedText: $viewModel.attributedText, viewModel: viewModel.textViewModel)
                    .frame(height: 300)
                    .padding(.horizontal)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                
                // Dream interpretation (dreams only)
                if book.bookType == "dream" {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dream Interpretation Notes")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        TextEditor(text: $viewModel.interpretationNotes)
                            .frame(height: 150)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
        .navigationTitle(entry == nil ? "New Entry" : "Edit Entry")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveEntry()
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $viewModel.selectedImage)
        }
        .sheet(isPresented: $showingPrompts) {
            WritingPromptsView(isDream: book.bookType == "dream", onSelect: { prompt in
                viewModel.insertPrompt(prompt)
            })
        }
    }
    
    private func saveEntry() {
        if let existingEntry = entry {
            existingEntry.content = viewModel.attributedText
            existingEntry.moodRating = Int(viewModel.moodRating)
            existingEntry.sleepQuality = Int(viewModel.sleepQuality)
            existingEntry.bedTime = viewModel.bedTime
            existingEntry.wakeTime = viewModel.wakeTime
            existingEntry.isLucidDream = viewModel.isLucidDream
            existingEntry.dreamTags = viewModel.selectedTags.joined(separator: ",")
            existingEntry.interpretationNotes = viewModel.interpretationNotes
            
            if let photo = viewModel.selectedImage {
                existingEntry.photoData = photo.jpegData(compressionQuality: 0.8)
            }
        } else {
            let newEntry = JournalEntry(
                content: viewModel.attributedText,
                moodRating: Int(viewModel.moodRating),
                sleepQuality: Int(viewModel.sleepQuality),
                bedTime: viewModel.bedTime,
                wakeTime: viewModel.wakeTime,
                isLucidDream: viewModel.isLucidDream,
                dreamTags: viewModel.selectedTags.joined(separator: ","),
                interpretationNotes: viewModel.interpretationNotes,
                photoData: viewModel.selectedImage?.jpegData(compressionQuality: 0.8),
                book: book
            )
            modelContext.insert(newEntry)
        }
        
        book.lastWrittenDate = Date()
    }
}

// MARK: - Tag Button
struct TagButton: View {
    let tag: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(tag)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.purple : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

// MARK: - Writing Prompts View
struct WritingPromptsView: View {
    @Environment(\.dismiss) var dismiss
    let isDream: Bool
    let onSelect: (String) -> Void
    
    let dreamPrompts = [
        "Describe the setting of your dream in detail...",
        "What emotions did you feel during this dream?",
        "Were there any recurring symbols or themes?",
        "How did the dream make you feel when you woke up?",
        "What do you think this dream might mean?"
    ]
    
    let regularPrompts = [
        "What am I grateful for today?",
        "What challenged me today and how did I handle it?",
        "What did I learn about myself today?",
        "What are my goals for tomorrow?",
        "Describe a moment that made me smile today..."
    ]
    
    var prompts: [String] {
        isDream ? dreamPrompts : regularPrompts
    }
    
    var body: some View {
        NavigationView {
            List(prompts, id: \.self) { prompt in
                Button {
                    onSelect(prompt)
                    dismiss()
                } label: {
                    Text(prompt)
                        .foregroundColor(.primary)
                }
            }
            .navigationTitle("Writing Prompts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Entry View Model
class EntryViewModel: ObservableObject {
    @Published var attributedText: NSAttributedString
    @Published var moodRating: Double
    @Published var sleepQuality: Double
    @Published var bedTime: Date
    @Published var wakeTime: Date
    @Published var isLucidDream: Bool
    @Published var selectedTags: [String] = []
    @Published var interpretationNotes: String
    @Published var selectedImage: UIImage?
    
    let textViewModel: JournalRichTextViewModel
    private let isDream: Bool
    
    init(entry: JournalEntry?, isDream: Bool) {
        self.isDream = isDream
        let initialContent = entry?.content ?? NSAttributedString(string: "")
        self.attributedText = initialContent
        self.moodRating = Double(entry?.moodRating ?? 5)
        self.sleepQuality = Double(entry?.sleepQuality ?? 5)
        self.bedTime = entry?.bedTime ?? Date()
        self.wakeTime = entry?.wakeTime ?? Date()
        self.isLucidDream = entry?.isLucidDream ?? false
        self.interpretationNotes = entry?.interpretationNotes ?? ""
        self.textViewModel = JournalRichTextViewModel(attributedString: initialContent)
        
        if let tags = entry?.dreamTags, !tags.isEmpty {
            self.selectedTags = tags.components(separatedBy: ",")
        }
        
        if let photoData = entry?.photoData {
            self.selectedImage = UIImage(data: photoData)
        }
    }
    
    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) {
            selectedTags.removeAll { $0 == tag }
        } else {
            selectedTags.append(tag)
        }
    }
    
    func insertPrompt(_ prompt: String) {
        let currentText = textViewModel.attributedText.string
        let newText = currentText.isEmpty ? prompt : currentText + "\n\n" + prompt
        attributedText = NSAttributedString(string: newText)
        textViewModel.attributedText = attributedText
    }
}

// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Color Extension
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String {
        let components = UIColor(self).cgColor.components
        let r = components?[0] ?? 0
        let g = components?[1] ?? 0
        let b = components?[2] ?? 0
        return String(format: "#%02lX%02lX%02lX", lroundf(Float(r * 255)), lroundf(Float(g * 255)), lroundf(Float(b * 255)))
    }
}

// MARK: - Journal Rich Text View Model
class JournalRichTextViewModel: ObservableObject {
    @Published var attributedText: NSAttributedString
    weak var textView: UITextView?
    
    init(attributedString: NSAttributedString) {
        self.attributedText = attributedString
    }
}

// MARK: - Journal Rich Text Editor
struct JournalRichTextEditor: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    var viewModel: JournalRichTextViewModel
    
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
            uiView.selectedRange = selectedRange
        }
        viewModel.textView = uiView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: JournalRichTextEditor
        
        init(_ parent: JournalRichTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.attributedText = textView.attributedText
            parent.viewModel.textView = textView
        }
        
        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.viewModel.textView = textView
        }
    }
}
