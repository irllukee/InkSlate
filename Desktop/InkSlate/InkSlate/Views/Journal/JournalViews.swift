import SwiftUI
import SwiftData

// MARK: - Main Journal View
struct BookshelfView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \JournalBook.createdDate, order: .forward)
    private var books: [JournalBook]
    
    @State private var showingNewJournal = false
    
    var body: some View {
        List {
            // Daily Journal (pinned at top)
            ForEach(books.filter { $0.isDailyJournal }) { book in
                NavigationLink(destination: EntriesListView(book: book)) {
                    JournalBookRow(book: book)
                }
            }
            .onDelete(perform: deleteBooks)
            
            // Other Journals
            ForEach(books.filter { !$0.isDailyJournal }) { book in
                NavigationLink(destination: EntriesListView(book: book)) {
                    JournalBookRow(book: book)
                }
            }
            .onDelete(perform: deleteBooks)
        }
        .navigationTitle("Journals")
        .toolbar {
            Button {
                showingNewJournal = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingNewJournal) {
            NewJournalView()
        }
        .onAppear {
            createDefaultDailyJournalIfNeeded()
        }
    }
    
    private func createDefaultDailyJournalIfNeeded() {
        let hasDailyJournal = books.contains { $0.isDailyJournal }
        if !hasDailyJournal {
            let dailyJournal = JournalBook(
                title: "Daily Journal",
                bookType: "regular",
                color: "#2E7D32",
                isDailyJournal: true
            )
            modelContext.insert(dailyJournal)
        }
    }
    
    private func deleteBooks(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(books[index])
        }
    }
}

// MARK: - Journal Book Row
struct JournalBookRow: View {
    let book: JournalBook
    
    var body: some View {
        HStack(spacing: 16) {
            // Journal Color Indicator
            Circle()
                .fill(Color(hex: book.color) ?? .gray)
                .frame(width: 12, height: 12)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(book.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if book.isDailyJournal {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(.green)
                            Text("Daily")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                
                if book.isDailyJournal {
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("\(book.currentStreak)")
                                .font(.caption)
                                .fontWeight(.medium)
                            Text("day streak")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if book.longestStreak > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                Text("Best: \(book.longestStreak)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                } else {
                    Text("\(book.entries?.count ?? 0) entries")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - New Journal
struct NewJournalView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loadingManager = LoadingStateManager()
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    @State private var title = ""
    @State private var selectedColor = "#2E7D32"
    
    private let colors = ["#2E7D32", "#1565C0", "#E65100", "#4A148C", "#C62828", "#F57F17"]
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Journal Name", text: $title)
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Button {
                                selectedColor = color
                            } label: {
                                Circle()
                                    .fill(Color(hex: color) ?? .gray)
                                    .frame(width: 36, height: 36)
                                    .overlay(
                                        Circle()
                                            .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 2)
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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        saveJournal()
                    }
                }
            }
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
    
    private func saveJournal() {
        loadingManager.startLoading(message: "Creating journal...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let journal = JournalBook(
                title: title.isEmpty ? "New Journal" : title,
                bookType: "regular",
                color: selectedColor,
                createdDate: Date()
            )
            modelContext.insert(journal)
            modelContext.saveWithDebounce(using: autoSaveManager)
            loadingManager.stopLoading()
            dismiss()
        }
    }
}

// MARK: - Entries List
struct EntriesListView: View {
    let book: JournalBook
    @Environment(\.modelContext) private var modelContext
    @State private var showingNewEntry = false
    
    var sortedEntries: [JournalEntry] {
        book.entries?.sorted { $0.createdDate > $1.createdDate } ?? []
    }
    
    var body: some View {
        List {
            ForEach(sortedEntries) { entry in
                NavigationLink(destination: EditEntryView(book: book, entry: entry)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.createdDate, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(entry.attributedContent.string.trimmingCharacters(in: .whitespacesAndNewlines))
                            .lineLimit(2)
                    }
                }
            }
            .onDelete(perform: deleteEntries)
        }
        .navigationTitle(book.title)
            .toolbar {
            Button {
                showingNewEntry = true
            } label: {
                Image(systemName: "plus")
            }
        }
        .sheet(isPresented: $showingNewEntry) {
            NewEntryView(book: book)
        }
    }
    
    private func deleteEntries(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedEntries[index])
        }
    }
}

// MARK: - New Entry
struct NewEntryView: View {
    let book: JournalBook
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loadingManager = LoadingStateManager()
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    @State private var text = ""
    @State private var selectedDate = Date()
    @State private var showingPromptPicker = false
    @State private var selectedPrompt = ""
    @State private var selectedPromptCategory = ""
    @State private var selectedPromptType: PromptType = .reflection
    @State private var wordCount = 0
    
    private let promptData = JournalPromptData.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with date picker and word count
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Date")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                .datePickerStyle(CompactDatePickerStyle())
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Words")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(wordCount)")
                                .font(.headline)
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal, 16)
                    
                    // Prompt section
                    if !selectedPrompt.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Writing Prompt")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Spacer()
                                Button("Change") {
                                    showingPromptPicker = true
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            
                            Text(selectedPrompt)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.08))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                    } else {
                        Button {
                            showingPromptPicker = true
                        } label: {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundColor(.blue)
                                Text("Get a Writing Prompt")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                            .padding(16)
                            .background(Color.blue.opacity(0.08))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                
                // Text editor
                VStack(spacing: 0) {
                    TextEditor(text: $text)
                        .font(.body)
                        .padding(16)
                        .onChange(of: text) { _, newValue in
                            wordCount = newValue.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
                        }
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("New Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.black)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveEntry()
                    }
                    .disabled(text.isEmpty)
                    .foregroundColor(text.isEmpty ? .gray : .blue)
                }
            }
        }
        .sheet(isPresented: $showingPromptPicker) {
            PromptPickerView(
                selectedPrompt: $selectedPrompt,
                selectedPromptCategory: $selectedPromptCategory,
                selectedPromptType: $selectedPromptType
            )
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
    
    private func saveEntry() {
        loadingManager.startLoading(message: "Saving entry...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let attributedString = NSAttributedString(string: text)
            let entry = JournalEntry(
                content: attributedString,
                createdDate: selectedDate,
                moodRating: 5,
                sleepQuality: 5,
                bedTime: Date(),
                wakeTime: Date(),
                isLucidDream: false,
                dreamTags: "",
                interpretationNotes: "",
                photoData: nil,
                book: book,
                wordCount: wordCount,
                usedPrompt: selectedPrompt,
                promptCategory: selectedPromptCategory
            )
            modelContext.insert(entry)
            
            // Update streak for daily journals
            if book.isDailyJournal {
                book.updateStreak(for: selectedDate)
            } else {
                book.lastWrittenDate = selectedDate
            }
            
            modelContext.saveWithDebounce(using: autoSaveManager)
            loadingManager.stopLoading()
            dismiss()
        }
    }
}

// MARK: - Edit Entry
struct EditEntryView: View {
    let book: JournalBook
    let entry: JournalEntry
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loadingManager = LoadingStateManager()
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    @State private var text: String
    
    init(book: JournalBook, entry: JournalEntry) {
        self.book = book
        self.entry = entry
        _text = State(initialValue: entry.attributedContent.string)
    }
    
    var body: some View {
        NavigationView {
            TextEditor(text: $text)
                .padding()
                .navigationTitle("Edit Entry")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveEntry()
                        }
                    }
                }
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
    
    private func saveEntry() {
        loadingManager.startLoading(message: "Saving changes...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            entry.attributedContent = NSAttributedString(string: text)
            book.lastWrittenDate = Date()
            modelContext.saveWithDebounce(using: autoSaveManager)
            loadingManager.stopLoading()
            dismiss()
        }
    }
}

// MARK: - Prompt Picker View
struct PromptPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedPrompt: String
    @Binding var selectedPromptCategory: String
    @Binding var selectedPromptType: PromptType
    
    @State private var selectedCategory: PromptCategory = .reflection
    @State private var showingPrompts = false
    
    private let promptData = JournalPromptData.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Category Selector
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Choose a Category")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(PromptCategory.allCases, id: \.self) { category in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedCategory = category
                                        showingPrompts = true
                                    }
                                }) {
                                    VStack(spacing: 8) {
                                        Image(systemName: category.icon)
                                            .font(.title2)
                                            .foregroundColor(Color(hex: category.color) ?? .blue)
                                        
                                        Text(category.rawValue)
                                            .font(.caption)
                                            .multilineTextAlignment(.center)
                                            .foregroundColor(.primary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .padding(.horizontal, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color(.systemGray6))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: category.color) ?? .blue, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                .contentShape(Rectangle())
                            }
                        }
                    }
                    
                    // Random Prompt Button
                    Button(action: {
                        let prompt = promptData.getRandomPrompt(category: selectedCategory, type: .reflection)
                        selectedPrompt = prompt
                        selectedPromptCategory = selectedCategory.rawValue
                        selectedPromptType = .reflection
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "shuffle")
                            Text("Get Random Prompt")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .contentShape(Rectangle())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Writing Prompts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.black)
                }
            }
        }
        .sheet(isPresented: $showingPrompts) {
            PromptCategoryView(
                category: selectedCategory,
                selectedPrompt: $selectedPrompt,
                selectedPromptCategory: $selectedPromptCategory,
                selectedPromptType: $selectedPromptType
            )
        }
    }
}

// MARK: - Prompt Category View
struct PromptCategoryView: View {
    let category: PromptCategory
    @Environment(\.dismiss) var dismiss
    @Binding var selectedPrompt: String
    @Binding var selectedPromptCategory: String
    @Binding var selectedPromptType: PromptType
    
    private let promptData = JournalPromptData.shared
    
    var prompts: [String] {
        promptData.getAllPrompts(for: category, type: .reflection)
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(prompts, id: \.self) { prompt in
                    Button(action: {
                        selectedPrompt = prompt
                        selectedPromptCategory = category.rawValue
                        selectedPromptType = .reflection
                        dismiss()
                    }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(prompt)
                                .font(.body)
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)
                            
                            HStack {
                                Image(systemName: category.icon)
                                    .font(.caption)
                                    .foregroundColor(Color(hex: category.color) ?? .blue)
                                
                                Text(category.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle(category.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                        .foregroundColor(.black)
                }
            }
        }
    }
}
