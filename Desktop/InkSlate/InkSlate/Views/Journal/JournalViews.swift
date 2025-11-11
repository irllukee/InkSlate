//
//  JournalViews.swift
//  InkSlate
//

import SwiftUI
import CoreData

// MARK: - JournalBook Extensions
extension JournalBook {
    var isDailyJournal: Bool {
        title?.localizedCaseInsensitiveContains("daily") == true
    }
    
    var lastWrittenDate: Date? {
        entries?
            .allObjects
            .compactMap { ($0 as? JournalEntry)?.createdDate }
            .max()
    }
    
    var currentStreak: Int {
        guard let entries = entries?.allObjects as? [JournalEntry],
              !entries.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let entryDates = Set(entries.compactMap { entry -> Date? in
            guard let date = entry.createdDate else { return nil }
            return calendar.startOfDay(for: date)
        })
        
        guard !entryDates.isEmpty else { return 0 }
        
        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        
        if !entryDates.contains(cursor),
           let previous = calendar.date(byAdding: .day, value: -1, to: cursor) {
            cursor = previous
        }
        
        while entryDates.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }
        
        return streak
    }
    
    var longestStreak: Int {
        guard let entries = entries?.allObjects as? [JournalEntry],
              !entries.isEmpty else { return 0 }
        
        // Get all unique dates with entries (normalized to start of day)
        let calendar = Calendar.current
        let entryDates = Set(entries.compactMap { entry -> Date? in
            guard let date = entry.createdDate else { return nil }
            return calendar.startOfDay(for: date)
        })
        
        guard !entryDates.isEmpty else { return 0 }
        
        // Sort dates in ascending order
        let sortedDates = entryDates.sorted(by: <)
        
        // Calculate longest consecutive streak
        var longestStreak = 1
        var currentStreak = 1
        
        for i in 1..<sortedDates.count {
            let currentDate = sortedDates[i]
            let previousDate = sortedDates[i - 1]
            
            if let nextExpectedDate = calendar.date(byAdding: .day, value: 1, to: previousDate),
               calendar.isDate(currentDate, inSameDayAs: nextExpectedDate) {
                // Consecutive day
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                // Gap found, reset current streak
                currentStreak = 1
            }
        }
        
        return longestStreak
    }
    
    func updateStreak(for date: Date) {
        // Streaks are calculated dynamically from entries
        // This method is kept for potential future use if we need to cache streak values
        // For now, streaks are calculated on-demand via computed properties
    }
}

fileprivate struct JournalPromptMetadata: Codable {
    let prompt: String
    let category: String
    let type: String
}

fileprivate let promptMetadataEncoder = JSONEncoder()
fileprivate let promptMetadataDecoder = JSONDecoder()

extension JournalEntry {
    fileprivate var promptMetadata: JournalPromptMetadata? {
        guard let tags,
              let data = tags.data(using: .utf8),
              let metadata = try? promptMetadataDecoder.decode(JournalPromptMetadata.self, from: data) else {
            return nil
        }
        return metadata
    }
}

// MARK: - Bookshelf View
struct BookshelfView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \JournalBook.createdDate, ascending: true)]
    ) private var books: FetchedResults<JournalBook>
    
    @State private var showingNewJournal = false
    @State private var isRefreshing = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                if books.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        Text("No Journals Yet")
                            .font(DesignSystem.Typography.title2)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        Text("Create your first journal to start writing.")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Button("Create Journal") {
                            lightHaptic()
                            showingNewJournal = true
                        }
                        .minimalistButton(variant: .primary, size: .medium)
                    }
                    .padding()
                } else {
                    ScrollView {
                        RefreshControl(isRefreshing: $isRefreshing) {
                            refreshData()
                        }
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            ForEach(books) { book in
                                NavigationLink {
                                    EntriesListView(book: book)
                                } label: {
                                    JournalBookCard(book: book)
                                }
                                .buttonStyle(.plain)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    if !book.isDailyJournal {
                                        Button(role: .destructive) {
                                            deleteBook(book)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
        }
        .navigationTitle("Journals")
        .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                        lightHaptic()
                showingNewJournal = true
            } label: {
                        Image(systemName: "plus.circle.fill")
                            .tint(DesignSystem.Colors.accent)
                    }
                }
        }
        .sheet(isPresented: $showingNewJournal) {
            NewJournalView()
                    .presentationDetents([.fraction(0.5), .large])
                    .presentationDragIndicator(.visible)
        }
        .onAppear {
            createDefaultDailyJournalIfNeeded()
            }
        }
    }
    
    private func refreshData() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            try? viewContext.save()
            isRefreshing = false
        }
    }
    
    private func deleteBook(_ book: JournalBook) {
        withAnimation {
            viewContext.delete(book)
            try? viewContext.save()
            lightHaptic()
        }
    }
    
    private func createDefaultDailyJournalIfNeeded() {
        guard !books.contains(where: { $0.isDailyJournal }) else { return }
            let dailyJournal = JournalBook(context: viewContext)
            dailyJournal.title = "Daily Journal"
            dailyJournal.color = "#2E7D32"
            dailyJournal.id = UUID()
            dailyJournal.createdDate = Date()
            dailyJournal.modifiedDate = Date()
        try? viewContext.save()
    }
}

// MARK: - Journal Book Card
struct JournalBookCard: View {
    let book: JournalBook
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
            Circle()
                    .fill(Color(hex: book.color ?? "#007AFF") ?? DesignSystem.Colors.accent)
                    .frame(width: 10, height: 10)
            
                    Text(book.title ?? "Untitled")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    if book.isDailyJournal {
                    Label("Daily", systemImage: "calendar")
                        .labelStyle(.titleAndIcon)
                        .font(DesignSystem.Typography.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(DesignSystem.Colors.backgroundTertiary)
                        .cornerRadius(DesignSystem.CornerRadius.sm)
                    }
                    
                    Spacer()
                }
                
                if book.isDailyJournal {
                HStack(spacing: DesignSystem.Spacing.lg) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundColor(.orange)
                        Text("\(book.currentStreak) day streak")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        if book.longestStreak > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(.yellow)
                                Text("Best: \(book.longestStreak)")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                    }
                    Spacer()
                }
            } else {
                Text("\(book.entries?.count ?? 0) entries")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .minimalistCard(.elevated)
    }
}

// MARK: - New Journal View
struct NewJournalView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var loadingManager = LoadingStateManager()
    @State private var title = ""
    @State private var selectedColor = "#2E7D32"
    
    private let colors = [
        "#2E7D32", "#1565C0", "#E65100",
        "#4A148C", "#C62828", "#F57F17"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Journal Name")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        TextField("Enter name", text: $title)
                            .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Color")
                            .font(DesignSystem.Typography.callout)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6)) {
                        ForEach(colors, id: \.self) { color in
                            Button {
                                selectedColor = color
                                    lightHaptic()
                            } label: {
                                Circle()
                                    .fill(Color(hex: color) ?? .gray)
                                        .frame(width: 32, height: 32)
                                    .overlay(
                                            Circle().stroke(
                                                selectedColor == color ? DesignSystem.Colors.textPrimary : .clear,
                                                lineWidth: 2
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Button {
                        createJournal()
                    } label: {
                        Text("Create Journal")
                            .font(DesignSystem.Typography.headline)
                    }
                    .minimalistButton(variant: .primary, size: .large)
                    .disabled(title.isEmpty)
                    .opacity(title.isEmpty ? 0.5 : 1.0)
                }
                .padding(DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("New Journal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.accent)
                }
            }
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
    
    private func createJournal() {
        loadingManager.startLoading(message: "Creating...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let journal = JournalBook(context: viewContext)
            journal.title = title.isEmpty ? "New Journal" : title
            journal.color = selectedColor
            journal.id = UUID()
            journal.createdDate = Date()
            journal.modifiedDate = Date()
            viewContext.insert(journal)
            try? viewContext.save()
                loadingManager.stopLoading()
                dismiss()
            lightHaptic()
        }
    }
}

// MARK: - Entries List View
struct EntriesListView: View {
    let book: JournalBook
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var loadingManager = LoadingStateManager()
    @State private var showingNewEntry = false
    @State private var newEntryText = ""
    @State private var wordCount = 0
    @State private var isRefreshing = false
    @FocusState private var isComposerFocused: Bool
    
    var accentColor: Color { Color(hex: book.color ?? "#007AFF") ?? DesignSystem.Colors.accent }
    
    var sortedEntries: [JournalEntry] {
        guard let entries = book.entries else { return [] }
        return (entries.allObjects as? [JournalEntry])?.sorted {
            ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast)
        } ?? []
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                DesignSystem.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    RefreshControl(isRefreshing: $isRefreshing) {
                        refreshData()
                    }
                    VStack(spacing: DesignSystem.Spacing.md) {
                        if book.isDailyJournal {
                            TodayQuickEntryCard(
                                text: $newEntryText,
                                wordCount: $wordCount,
                                accentColor: accentColor,
                                onCommit: saveInlineEntry
                            )
                            .focused($isComposerFocused)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .padding(.top, DesignSystem.Spacing.lg)
                        }
                        
                        if sortedEntries.isEmpty {
                            EmptyEntriesState(accentColor: accentColor)
                                .padding(DesignSystem.Spacing.lg)
                        } else {
                            ForEach(sortedEntries) { entry in
                                NavigationLink {
                                    EditEntryView(book: book, entry: entry)
                                } label: {
                                    EntryRow(entry: entry)
                                }
                                .buttonStyle(.plain)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        delete(entry)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, DesignSystem.Spacing.lg)
                }
        }
        .navigationTitle(book.title ?? "Journal")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                        lightHaptic()
                showingNewEntry = true
            } label: {
                        Image(systemName: "plus.circle.fill")
                            .tint(accentColor)
                    }
                }
            }
            .sheet(isPresented: $showingNewEntry) {
                NewEntryView(book: book)
                    .presentationDetents([.fraction(0.5), .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
    
    private func saveInlineEntry() {
        guard !newEntryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let entry = JournalEntry(context: viewContext)
        entry.content = newEntryText
        entry.createdDate = Date()
        entry.modifiedDate = Date()
        entry.id = UUID()
        entry.book = book
        viewContext.insert(entry)
        withAnimation(.spring) { try? viewContext.save() }
        newEntryText = ""
        wordCount = 0
        isComposerFocused = false
        lightHaptic()
    }
    
    private func delete(_ entry: JournalEntry) {
        withAnimation {
            viewContext.delete(entry)
            try? viewContext.save()
            lightHaptic()
        }
    }
    
    private func refreshData() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            try? viewContext.save()
            isRefreshing = false
        }
    }
}

// MARK: - Today Quick Entry Card
struct TodayQuickEntryCard: View {
    @Binding var text: String
    @Binding var wordCount: Int
    var accentColor: Color
    var onCommit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Today")
                    .font(DesignSystem.Typography.title3)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                Spacer()
                Text("\(wordCount) words")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            TextEditor(text: $text)
                .font(DesignSystem.Typography.body)
                .frame(minHeight: 120)
                .padding(DesignSystem.Spacing.md)
                .background(DesignSystem.Colors.surface)
                .cornerRadius(DesignSystem.CornerRadius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .stroke(DesignSystem.Colors.border, lineWidth: 0.5)
                )
                .onChange(of: text) { _, newValue in
                    wordCount = newValue
                        .components(separatedBy: .whitespacesAndNewlines)
                        .filter { !$0.isEmpty }
                        .count
                }
            
            HStack {
                Spacer()
                Button {
                    onCommit()
                } label: {
                    Label("Save Entry", systemImage: "square.and.arrow.down.fill")
                        .labelStyle(.titleAndIcon)
                        .font(DesignSystem.Typography.button)
                        .foregroundColor(DesignSystem.Colors.textInverse)
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(accentColor)
                        .cornerRadius(DesignSystem.CornerRadius.lg)
                }
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(text.isEmpty ? 0.5 : 1.0)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .minimalistCard(.outlined)
    }
}

// MARK: - Entry Row
struct EntryRow: View {
    let entry: JournalEntry
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(entry.createdDate ?? Date(), style: .date)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            Text((entry.content ?? "").trimmingCharacters(in: .whitespacesAndNewlines))
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .lineLimit(3)
            if let metadata = entry.promptMetadata {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.accent)
                    Text(metadata.prompt)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .minimalistCard(.elevated)
    }
}

// MARK: - Empty Entries State
struct EmptyEntriesState: View {
    var accentColor: Color
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            Text("No Entries Yet")
                .font(DesignSystem.Typography.title2)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            Text("Start writing your first entry.")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

// MARK: - New Entry View
struct NewEntryView: View {
    let book: JournalBook
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var loadingManager = LoadingStateManager()
    @State private var text = ""
    @State private var wordCount = 0
    @State private var date = Date()
    @State private var selectedPrompt = ""
    @State private var selectedPromptCategory = PromptCategory.reflection.rawValue
    @State private var selectedPromptType: PromptType = .reflection
    @State private var showingPromptPicker = false
    
    var accentColor: Color { Color(hex: book.color ?? "#007AFF") ?? DesignSystem.Colors.accent }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                        Text("Prompt")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        if !selectedPrompt.isEmpty {
                            Button("Clear") {
                                selectedPrompt = ""
                                selectedPromptCategory = PromptCategory.reflection.rawValue
                                selectedPromptType = .reflection
                            }
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.accent)
                        }
                    }
                    
                    if selectedPrompt.isEmpty {
                        Button {
                            showingPromptPicker = true
                            lightHaptic()
                        } label: {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Choose Writing Prompt")
                                    .fontWeight(.medium)
                            }
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textInverse)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .frame(maxWidth: .infinity)
                            .background(accentColor)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                        }
                        .buttonStyle(.plain)
                    } else {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text(selectedPrompt)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .multilineTextAlignment(.leading)
                            
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "tag")
                                    .font(.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Text(selectedPromptCategory.capitalized)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Spacer()
                                Button("Change Prompt") {
                                    showingPromptPicker = true
                                    lightHaptic()
                                }
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.accent)
                            }
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.surface)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.backgroundTertiary)
                .cornerRadius(DesignSystem.CornerRadius.md)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    HStack {
                            Text("Date")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        Spacer()
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                    }
                    
                            HStack {
                        Text("Words")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                Spacer()
                        Text("\(wordCount)")
                            .font(DesignSystem.Typography.caption)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.backgroundTertiary)
                .cornerRadius(DesignSystem.CornerRadius.md)
                
                TextEditor(text: $text)
                    .font(DesignSystem.Typography.body)
                    .padding()
                    .background(DesignSystem.Colors.surface)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                        .onChange(of: text) { _, newValue in
                        wordCount = newValue.split { $0.isWhitespace || $0.isNewline }.count
                    }
                
                Button("Save Entry") { saveEntry() }
                    .minimalistButton(variant: .primary, size: .large)
                    .disabled(text.isEmpty)
                    .opacity(text.isEmpty ? 0.5 : 1)
            }
            .padding()
            .navigationTitle("New Entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(accentColor)
                }
            }
        }
        .loadingOverlay(loadingManager: loadingManager)
        .sheet(isPresented: $showingPromptPicker) {
            PromptPickerView(
                selectedPrompt: $selectedPrompt,
                selectedPromptCategory: $selectedPromptCategory,
                selectedPromptType: $selectedPromptType
            )
            .presentationDetents([.fraction(0.5), .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: selectedPrompt) { _, newValue in
            guard !newValue.isEmpty, text.isEmpty else { return }
            text = newValue + "\n\n"
        }
    }
    
    private func saveEntry() {
        loadingManager.startLoading(message: "Saving entry...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let entry = JournalEntry(context: viewContext)
            entry.content = text
            entry.createdDate = date
            entry.modifiedDate = Date()
            entry.id = UUID()
            entry.book = book
            if !selectedPrompt.isEmpty {
                let metadata = JournalPromptMetadata(
                    prompt: selectedPrompt,
                    category: selectedPromptCategory,
                    type: selectedPromptType.rawValue
                )
                if let data = try? promptMetadataEncoder.encode(metadata),
                   let json = String(data: data, encoding: .utf8) {
                    entry.tags = json
                }
            }
            viewContext.insert(entry)
            withAnimation { try? viewContext.save() }
                loadingManager.stopLoading()
                dismiss()
            lightHaptic()
        }
    }
}

// MARK: - Edit Entry View
struct EditEntryView: View {
    let book: JournalBook
    let entry: JournalEntry
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var loadingManager = LoadingStateManager()
    @State private var text: String
    
    init(book: JournalBook, entry: JournalEntry) {
        self.book = book
        self.entry = entry
        _text = State(initialValue: entry.content ?? "")
    }
    
    var body: some View {
        NavigationStack {
            VStack {
            TextEditor(text: $text)
                    .font(DesignSystem.Typography.body)
                    .padding()
                    .background(DesignSystem.Colors.surface)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                Spacer()
            }
                .padding()
                .navigationTitle("Edit Entry")
                .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                    ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveEntry() }
                        .foregroundColor(DesignSystem.Colors.accent)
                }
                }
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
    
    private func saveEntry() {
        loadingManager.startLoading(message: "Saving...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            entry.content = text
            entry.modifiedDate = Date()
            withAnimation { try? viewContext.save() }
                loadingManager.stopLoading()
                dismiss()
            lightHaptic()
        }
    }
}

// MARK: - Prompt Picker View
struct PromptPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPrompt: String
    @Binding var selectedPromptCategory: String
    @Binding var selectedPromptType: PromptType
    
    @State private var selectedCategory: PromptCategory = .reflection
    @State private var showingPrompts = false
    
    private let promptData = JournalPromptData.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xxl) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        Text("Choose a Category")
                            .font(DesignSystem.Typography.title3)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: DesignSystem.Spacing.lg) {
                            ForEach(PromptCategory.allCases, id: \.self) { category in
                                Button {
                                    withAnimation(.spring) {
                                        selectedCategory = category
                                        showingPrompts = true
                                        lightHaptic()
                                    }
                                } label: {
                                    VStack(spacing: DesignSystem.Spacing.sm) {
                                        Image(systemName: category.icon)
                                            .font(.title3)
                                            .foregroundColor(Color(hex: category.color) ?? .blue)
                                        Text(category.displayName)
                                            .font(DesignSystem.Typography.body)
                                            .foregroundColor(DesignSystem.Colors.textPrimary)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 80)
                                    .padding(DesignSystem.Spacing.lg)
                                    .background(DesignSystem.Colors.surface)
                                    .cornerRadius(DesignSystem.CornerRadius.lg)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                            .stroke(Color(hex: category.color) ?? DesignSystem.Colors.border, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Button {
                        let prompt = promptData.getRandomPrompt(category: selectedCategory, type: .reflection)
                        selectedPrompt = prompt
                        selectedPromptCategory = selectedCategory.rawValue
                        selectedPromptType = .reflection
                        lightHaptic()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Get Random Prompt")
                                .fontWeight(.medium)
                        }
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textInverse)
                        .padding(.vertical, DesignSystem.Spacing.lg)
                        .frame(maxWidth: .infinity)
                        .background(DesignSystem.Colors.accent)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                    }
                    .buttonStyle(.plain)
                }
                .padding(DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Writing Prompts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.accent)
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
            .presentationDetents([.fraction(0.5), .large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Prompt Category View
struct PromptCategoryView: View {
    let category: PromptCategory
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPrompt: String
    @Binding var selectedPromptCategory: String
    @Binding var selectedPromptType: PromptType
    
    private let promptData = JournalPromptData.shared
    
    var prompts: [String] {
        promptData.getAllPrompts(for: category, type: .reflection)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.md) {
                ForEach(prompts, id: \.self) { prompt in
                        Button {
                        selectedPrompt = prompt
                        selectedPromptCategory = category.rawValue
                        selectedPromptType = .reflection
                            lightHaptic()
                        dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text(prompt)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                .multilineTextAlignment(.leading)
                            
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: category.icon)
                                    .font(.caption)
                                    .foregroundColor(Color(hex: category.color) ?? .blue)
                                    Text(category.displayName)
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                Spacer()
                                }
                            }
                            .padding(DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.surface)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                    .stroke(DesignSystem.Colors.border, lineWidth: 0.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle(category.displayName)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.accent)
                }
            }
        }
    }
}

// MARK: - Journal Prompt Types
enum PromptType: String, CaseIterable {
    case reflection = "reflection"
    case gratitude = "gratitude"
    case goal = "goal"
    case memory = "memory"
    case creative = "creative"
    
    var displayName: String {
        switch self {
        case .reflection: return "Reflection"
        case .gratitude: return "Gratitude"
        case .goal: return "Goal Setting"
        case .memory: return "Memory"
        case .creative: return "Creative Writing"
        }
    }
}

enum PromptCategory: String, CaseIterable {
    case reflection = "reflection"
    case gratitude = "gratitude"
    case goal = "goal"
    case memory = "memory"
    case creative = "creative"
    
    var displayName: String {
        switch self {
        case .reflection: return "Reflection"
        case .gratitude: return "Gratitude"
        case .goal: return "Goal Setting"
        case .memory: return "Memory"
        case .creative: return "Creative Writing"
        }
    }
    
    var icon: String {
        switch self {
        case .reflection: return "brain.head.profile"
        case .gratitude: return "heart.fill"
        case .goal: return "target"
        case .memory: return "photo"
        case .creative: return "paintbrush.fill"
        }
    }
    
    var color: String {
        switch self {
        case .reflection: return "#4A90E2"
        case .gratitude: return "#7ED321"
        case .goal: return "#F5A623"
        case .memory: return "#9013FE"
        case .creative: return "#D0021B"
        }
    }
    
    var prompts: [String] {
        switch self {
        case .reflection:
            return [
                "What was the most challenging part of your day?",
                "What did you learn about yourself today?",
                "How did you grow today?",
                "What would you do differently if you could relive today?",
                "What patterns do you notice in your thoughts today?"
            ]
        case .gratitude:
            return [
                "What are three things you're grateful for today?",
                "Who made a positive impact on your day?",
                "What small moment brought you joy today?",
                "What are you grateful for about yourself?",
                "What in nature are you grateful for today?"
            ]
        case .goal:
            return [
                "What is one goal you want to achieve this week?",
                "What steps did you take toward your goals today?",
                "What obstacles are preventing you from reaching your goals?",
                "How do you define success for yourself?",
                "What new skill would you like to learn?"
            ]
        case .memory:
            return [
                "Describe a favorite childhood memory.",
                "What was the best day you had this month?",
                "Write about a person who influenced you.",
                "What tradition from your family do you cherish?",
                "Describe a place that holds special meaning for you."
            ]
        case .creative:
            return [
                "Write a short story about a character who finds a mysterious key.",
                "Describe your ideal day in detail.",
                "Write a letter to your future self.",
                "Create a poem about the changing seasons.",
                "Imagine you could have dinner with anyone, living or dead. Who would it be and why?"
            ]
        }
    }
}

class JournalPromptData: ObservableObject {
    static let shared = JournalPromptData()
    
    private init() {}
    
    func getRandomPrompt(for category: PromptCategory) -> String {
        let prompts = category.prompts
        return prompts.randomElement() ?? "Write about your day."
    }
    
    func getAllPrompts() -> [PromptCategory: [String]] {
        var allPrompts: [PromptCategory: [String]] = [:]
        for category in PromptCategory.allCases {
            allPrompts[category] = category.prompts
        }
        return allPrompts
    }
    
    func getRandomPrompt(category: PromptCategory, type: PromptType) -> String {
        return getRandomPrompt(for: category)
    }
    
    func getAllPrompts(for category: PromptCategory, type: PromptType) -> [String] {
        return category.prompts
    }
}
