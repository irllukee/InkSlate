import SwiftUI
import UIKit
import SwiftData
import PhotosUI

// MARK: - Main Journal View
struct BookshelfView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalBook.createdDate, order: .forward)
    private var books: [JournalBook]
    
    @State private var showingJournalTypeSelection = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.lg) {
                    ForEach(books, id: \.id) { book in
                        NavigationLink(destination: EntryEditorView(book: book, entry: nil)) {
                            JournalCardView(book: book)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingJournalTypeSelection = true
                    } label: {
                        Image(systemName: "plus")
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                    }
                }
            }
            .sheet(isPresented: $showingJournalTypeSelection) {
                JournalTypeSelectionView()
            }
        }
    }
}

// MARK: - Journal Card View
struct JournalCardView: View {
    let book: JournalBook
    @State private var showingEditJournal = false
    
    var bookColor: Color {
        Color(hex: book.color) ?? .brown
    }
    
    var entryCount: Int {
        book.entries?.count ?? 0
    }
    
    var formattedDate: String {
        if book.lastWrittenDate != Date.distantPast {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: book.lastWrittenDate)
        }
        return "No entries yet"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Journal icon
                ZStack {
                    Circle()
                        .fill(bookColor)
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: book.bookType == "dream" ? "moon.stars.fill" : "book.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(book.title)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Text(book.bookType == "dream" ? "Dream Journal" : "Regular Journal")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, DesignSystem.Spacing.sm)
                        .padding(.vertical, DesignSystem.Spacing.xs)
                        .background(
                            Capsule()
                                .fill(DesignSystem.Colors.surface)
                        )
                }
                
                Spacer()
                
                Button {
                    showingEditJournal = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.system(size: 14))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            
            HStack {
                Text("\(entryCount) \(entryCount == 1 ? "entry" : "entries")")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                
                Spacer()
                
                Text(formattedDate)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.border, lineWidth: 0.5)
                )
        )
        .sheet(isPresented: $showingEditJournal) {
            EditJournalView(book: book)
        }
    }
}


// MARK: - Journal Type Selection View
struct JournalTypeSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedType: String = "regular"
    @State private var showingNewJournalSheet = false
    
    private let journalTypes = [
        ("regular", "Regular Journal", "book.fill", "Keep track of daily thoughts, experiences, and reflections"),
        ("dream", "Dream Journal", "moon.stars.fill", "Record and analyze your dreams and sleep patterns")
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    Text("Choose Journal Type")
                        .font(DesignSystem.Typography.title2)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Select the type of journal you'd like to create")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                VStack(spacing: DesignSystem.Spacing.md) {
                    ForEach(journalTypes, id: \.0) { type, name, icon, description in
                        Button {
                            selectedType = type
                        } label: {
                            HStack(spacing: DesignSystem.Spacing.lg) {
                                ZStack {
                                    Circle()
                                        .fill(selectedType == type ? DesignSystem.Colors.accent : DesignSystem.Colors.surface)
                                        .frame(width: 60, height: 60)
                                    
                                    Image(systemName: icon)
                                        .font(.system(size: 24))
                                        .foregroundColor(selectedType == type ? DesignSystem.Colors.textInverse : DesignSystem.Colors.textPrimary)
                                }
                                
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                    Text(name)
                                        .font(DesignSystem.Typography.headline)
                                        .foregroundColor(selectedType == type ? DesignSystem.Colors.accent : DesignSystem.Colors.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    Text(description)
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
                                }
                                
                                if selectedType == type {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(DesignSystem.Colors.accent)
                                }
                            }
                            .padding(DesignSystem.Spacing.lg)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                    .fill(selectedType == type ? DesignSystem.Colors.accent.opacity(0.1) : DesignSystem.Colors.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                            .stroke(
                                                selectedType == type ? DesignSystem.Colors.accent : DesignSystem.Colors.border,
                                                lineWidth: selectedType == type ? 2 : 1
                                            )
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Spacer()
                
                Button {
                    showingNewJournalSheet = true
                } label: {
                    Text("Continue")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textInverse)
                        .frame(maxWidth: .infinity)
                        .padding(DesignSystem.Spacing.lg)
                        .background(DesignSystem.Colors.accent)
                        .cornerRadius(DesignSystem.CornerRadius.lg)
                }
                .disabled(selectedType.isEmpty)
            }
            .padding(DesignSystem.Spacing.xl)
            .navigationTitle("New Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingNewJournalSheet) {
                NewJournalView(selectedType: selectedType)
            }
        }
    }
}

// MARK: - New Journal View
struct NewJournalView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let selectedType: String
    @State private var title = ""
    @State private var selectedColor = "#2E7D32"
    @State private var createdJournal: JournalBook?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let colors = [
        "#2E7D32", // Green
        "#1565C0", // Blue  
        "#E65100", // Orange
        "#4A148C", // Purple
        "#37474F", // Dark Gray
        "#C62828", // Red
        "#F57F17", // Yellow
        "#6A1B9A"  // Deep Purple
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Journal Details")
                        .font(DesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Journal Title")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        ModernTaskTextField(
                            text: $title,
                            placeholder: "Enter journal title",
                            isFocused: .constant(false),
                            isMultiline: false
                        )
                    }
                }
                
                // Journal Type Display (read-only)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Journal Type")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    HStack {
                        Image(systemName: selectedType == "dream" ? "moon.stars.fill" : "book.fill")
                            .foregroundColor(DesignSystem.Colors.accent)
                            .frame(width: 24)
                        
                        Text(selectedType == "dream" ? "Dream Journal" : "Regular Journal")
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Spacer()
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .fill(DesignSystem.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
                            )
                    )
                }
                
                Section(header: Text("Color Theme")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                Circle()
                                    .fill(Color(hex: color) ?? .gray)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor == color ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createJournal()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .sheet(item: $createdJournal) { journal in
                EntryEditorView(book: journal, entry: nil)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createJournal() {
        let journal = JournalBook(
            title: title.isEmpty ? "New Journal" : title,
            bookType: selectedType,
            color: selectedColor,
            createdDate: Date()
        )
        
        modelContext.insert(journal)
        
        do {
            try modelContext.save()
            createdJournal = journal
        } catch {
            errorMessage = "Failed to create journal: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Edit Journal View
struct EditJournalView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let book: JournalBook
    @State private var title: String
    @State private var selectedColor: String
    
    private let colors = [
        "#2E7D32", // Green
        "#1565C0", // Blue  
        "#E65100", // Orange
        "#4A148C", // Purple
        "#37474F", // Dark Gray
        "#C62828", // Red
        "#F57F17", // Yellow
        "#6A1B9A"  // Deep Purple
    ]
    
    init(book: JournalBook) {
        self.book = book
        self._title = State(initialValue: book.title)
        self._selectedColor = State(initialValue: book.color)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Edit Journal")
                        .font(DesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Journal Title")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        ModernTaskTextField(
                            text: $title,
                            placeholder: "Enter journal title",
                            isFocused: .constant(false),
                            isMultiline: false
                        )
                    }
                }
                
                // Journal Type Display (read-only)
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Journal Type")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    HStack {
                        Image(systemName: book.bookType == "dream" ? "moon.stars.fill" : "book.fill")
                            .foregroundColor(DesignSystem.Colors.accent)
                            .frame(width: 24)
                        
                        Text(book.bookType == "dream" ? "Dream Journal" : "Regular Journal")
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Spacer()
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .fill(DesignSystem.Colors.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
                            )
                    )
                }
                
                Section(header: Text("Color Theme")) {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                Circle()
                                    .fill(Color(hex: color) ?? .gray)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor == color ? Color.blue : Color.clear, lineWidth: 3)
                                    )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Edit Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        updateJournal()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
    
    private func updateJournal() {
        book.title = title.isEmpty ? "Untitled Journal" : title
        book.color = selectedColor
        dismiss()
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
    @State private var showingError = false
    @State private var errorMessage = ""
    
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
                        
                        ModernTaskTextField(
                            text: $viewModel.interpretationNotes,
                            placeholder: "Add your dream interpretation notes...",
                            isFocused: .constant(false),
                            isMultiline: true
                        )
                        .frame(height: 150)
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
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
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
                existingEntry.photoData = photo.jpegData(compressionQuality: 0.8) ?? Data()
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
        
        // Save to model context
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Failed to save journal entry: \(error.localizedDescription)"
            showingError = true
        }
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
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(prompts, id: \.self) { prompt in
                        Button {
                            onSelect(prompt)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(prompt)
                                    .foregroundColor(.primary)
                                    .font(.body)
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text("Tap to use this prompt")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(DesignSystem.Colors.surface)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
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
        
        // Fix date initialization - use proper defaults for sleep times
        if let entry = entry {
            self.bedTime = entry.bedTime != Date.distantPast ? entry.bedTime : Date()
            self.wakeTime = entry.wakeTime != Date.distantPast ? entry.wakeTime : Date()
        } else {
            // Default sleep times for new entries
            let calendar = Calendar.current
            let now = Date()
            self.bedTime = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: now) ?? now
            self.wakeTime = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: now) ?? now
        }
        
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

