//
//  NotesViews.swift
//  InkSlate
//

import SwiftUI
import Foundation
import UIKit
import CoreData

// MARK: - Sort Options (imported from NotesService)

// MARK: - Main Notes List View
struct NotesListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Notes.modifiedDate, ascending: false)],
        predicate: NSPredicate(format: "isMarkedDeleted == NO")
    ) private var normalNotes: FetchedResults<Notes>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Notes.modifiedDate, ascending: false)],
        predicate: NSPredicate(format: "isMarkedDeleted == YES")
    ) private var deletedNotes: FetchedResults<Notes>

    @State private var searchText: String = ""
    @State private var debouncedSearchText = ""
    @State private var searchTimer: Timer?

    @State private var showingNewNoteSheet = false
    @State private var selectedNote: Notes?

    @State private var sortBy: SortBy = .modificationDate
    @State private var sortDirection: SortDirection = .descending
    @State private var showPinnedOnly = false

    @State private var showingDeletedNotes = false
    @State private var showingEmptyTrashAlert = false

    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false

    private var filteredNotes: [Notes] {
        var notes = Array(showingDeletedNotes ? deletedNotes : normalNotes)

        if !debouncedSearchText.isEmpty {
            let q = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchLower = q.lowercased()
            
            notes = notes.filter { note in
                (note.title?.lowercased().contains(searchLower) ?? false) ||
                (note.content?.lowercased().contains(searchLower) ?? false) ||
                (note.preview?.lowercased().contains(searchLower) ?? false)
            }
        }

        if showPinnedOnly && !showingDeletedNotes {
            notes = notes.filter { $0.isPinned }
        }

        switch sortBy {
        case .modificationDate:
            notes.sort { sortDirection == .ascending ? ($0.modifiedDate ?? Date.distantPast) < ($1.modifiedDate ?? Date.distantPast) : ($0.modifiedDate ?? Date.distantPast) > ($1.modifiedDate ?? Date.distantPast) }
        case .creationDate:
            notes.sort { sortDirection == .ascending ? ($0.createdDate ?? Date.distantPast) < ($1.createdDate ?? Date.distantPast) : ($0.createdDate ?? Date.distantPast) > ($1.createdDate ?? Date.distantPast) }
        case .title:
            notes.sort { sortDirection == .ascending ? ($0.title ?? "") < ($1.title ?? "") : ($0.title ?? "") > ($1.title ?? "") }
        case .pin:
            notes.sort {
                if sortDirection == .ascending { ($0.isPinned ? 0 : 1) < ($1.isPinned ? 0 : 1) }
                else { ($0.isPinned ? 0 : 1) > ($1.isPinned ? 0 : 1) }
            }
        }

        return notes
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                toolbarView

                if filteredNotes.isEmpty {
                    emptyStateView
                } else {
                    notesListView
                }
            }
            .navigationTitle(showingDeletedNotes ? "Recently Deleted" : "Notes")
            .overlay { if isLoading { loadingOverlay } }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        withAnimation(.easeInOut) { showingDeletedNotes.toggle() }
                    } label: {
                        Image(systemName: showingDeletedNotes ? "arrow.left" : "trash")
                    }
                    .accessibilityLabel(showingDeletedNotes ? "Back to Notes" : "Recently Deleted")
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if !showingDeletedNotes {
                        Button {
                            showingNewNoteSheet = true
                        } label: { Image(systemName: "square.and.pencil") }
                        .accessibilityLabel("New Note")
                    }
                }
            }
            .sheet(isPresented: $showingNewNoteSheet) { NewNoteView() }
            .sheet(item: $selectedNote) { note in
                if note.isDeleted {
                    Text("This note is in Recently Deleted.")
                        .padding()
                } else if note.isEncrypted {
                    DecryptionView(note: note) { success in
                        if success {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                selectedNote = note
                            }
                        } else {
                            selectedNote = nil
                        }
                    }
                } else {
                    TextEditorView(note: note)
                }
            }
            .alert("Error", isPresented: $showingError) { Button("OK") {} } message: { Text(errorMessage) }
            .onAppear { purgeOldDeletedNotes() }
            .onChange(of: searchText) { _, newValue in
                searchTimer?.invalidate()
                searchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                    debouncedSearchText = newValue
                }
            }
        }
    }

    private var toolbarView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                SearchBar(text: $searchText)

                if !showingDeletedNotes {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { showPinnedOnly.toggle() }
                    } label: {
                        Image(systemName: showPinnedOnly ? "pin.fill" : "pin")
                            .foregroundColor(showPinnedOnly ? .blue : .gray)
                            .font(.system(size: 18))
                            .accessibilityLabel(showPinnedOnly ? "Showing pinned only" : "Toggle pinned filter")
                    }
                }

                Menu {
                    Menu("Sort By") {
                        Button("Modified Date") { sortBy = .modificationDate }
                        Button("Created Date") { sortBy = .creationDate }
                        Button("Title") { sortBy = .title }
                        Button("Pin") { sortBy = .pin }
                    }
                    Divider()
                    Button("Ascending") { sortDirection = .ascending }
                    Button("Descending") { sortDirection = .descending }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 16)

            if showPinnedOnly && !showingDeletedNotes {
                HStack {
                    Text("Showing pinned notes only")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: showingDeletedNotes ? "trash" : "note.text")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text(showingDeletedNotes ? "No deleted notes" : (searchText.isEmpty ? "No notes yet" : "No notes found"))
                .font(.headline)
                .foregroundColor(.gray)

            if !showingDeletedNotes && searchText.isEmpty {
                Text("Tap + to create your first note")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var notesListView: some View {
        List {
            if showingDeletedNotes {
                Section { trashHeaderView }
            }

            ForEach(filteredNotes) { note in
                NoteRowView(note: note) {
                    if !showingDeletedNotes { selectedNote = note }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if showingDeletedNotes {
                        Button {
                            restoreNote(note)
                        } label: {
                            Label("Restore", systemImage: "arrow.uturn.backward")
                        }
                        .tint(.green)

                        Button(role: .destructive) {
                            permanentlyDelete(note)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } else {
                        Button(role: .destructive) {
                            softDelete(note)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            togglePin(note)
                        } label: {
                            Label(note.isPinned ? "Unpin" : "Pin",
                                  systemImage: note.isPinned ? "pin.slash" : "pin")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .listStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: filteredNotes.map(\.id))
    }

    private var trashHeaderView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Notes are permanently deleted after 30 days")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Button(role: .destructive) {
                showingEmptyTrashAlert = true
            } label: {
                HStack {
                    Image(systemName: "trash.slash")
                    Text("Empty Trash")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.bordered)
            .alert("Empty Trash", isPresented: $showingEmptyTrashAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive) { emptyTrash() }
            } message: {
                Text("All notes in Recently Deleted will be permanently removed. This action cannot be undone.")
            }
        }
        .padding(.vertical, 8)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().scaleEffect(1.2)
                Text("Loading...").font(.subheadline)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }

    private func softDelete(_ note: Notes) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        if selectedNote?.id == note.id { selectedNote = nil }

        note.isMarkedDeleted = true
        note.modifiedDate = Date()
        
        do {
            try viewContext.save()
        } catch {
            errorMessage = "Failed to delete note: \(error.localizedDescription)"
            showingError = true
        }
    }

    private func restoreNote(_ note: Notes) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        note.isMarkedDeleted = false
        note.modifiedDate = Date()

        saveOrAlert("Failed to restore note")
    }

    private func permanentlyDelete(_ note: Notes) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()

        viewContext.delete(note)
        saveOrAlert("Failed to permanently delete note")
    }

    private func emptyTrash() {
        withAnimation(.easeInOut) { isLoading = true }

        for note in deletedNotes { viewContext.delete(note) }

        do {
            try viewContext.save()
        } catch {
            errorMessage = "Failed to empty trash: \(error.localizedDescription)"
            showingError = true
        }

        withAnimation(.easeInOut) { isLoading = false }
    }

    private func togglePin(_ note: Notes) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        note.isPinned.toggle()
        note.modifiedDate = Date()

        saveOrAlert("Failed to toggle pin")
    }

    private func purgeOldDeletedNotes() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
        let old = deletedNotes.filter { ($0.modifiedDate ?? .distantPast) < cutoff }
        guard !old.isEmpty else { return }

        for note in old { viewContext.delete(note) }
        _ = try? viewContext.save()
    }

    private func saveOrAlert(_ prefix: String) {
        do {
            try viewContext.save()
        } catch {
            errorMessage = "\(prefix): \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Note Row View
struct NoteRowView: View {
    let note: Notes
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text((note.title?.isEmpty ?? true) ? "Untitled" : (note.title ?? "Untitled"))
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                    }

                    if note.isEncrypted {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }

                if !(note.preview?.isEmpty ?? true) {
                    Text(note.preview ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 10) {
                    Text((note.modifiedDate ?? Date()).formatted(.dateTime.day().month().year().hour().minute()))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if !(note.tags?.isEmpty ?? true) {
                        HStack(spacing: 4) {
                            ForEach((note.tags ?? "").components(separatedBy: ",").prefix(3), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                            if (note.tags?.components(separatedBy: ",").count ?? 0) > 3 {
                                Text("+\((note.tags?.components(separatedBy: ",").count ?? 0) - 3)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Search Bar
struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(.gray)
            TextField("Search notes...", text: $text).textFieldStyle(.plain)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .cornerRadius(10)
    }
}

// MARK: - Note Editor View
struct TextEditorView: View {
    @ObservedObject var note: Notes
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingMarkdownPreview = false
    @State private var showingTagEditor = false
    @State private var showingEncryption = false
    @State private var showingDecryption = false
    @State private var showingExportOptions = false

    @State private var showingError = false
    @State private var errorMessage = ""

    @State private var hasUnsavedChanges = false
    @State private var autoSaveTimer: Timer?
    @State private var isSaving = false
    
    @State private var selectedRange = NSRange(location: 0, length: 0)
    @State private var coordinatorRef: MarkdownEditor.Coordinator?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let coordinator = coordinatorRef {
                    MarkdownToolbarView(coordinator: coordinator)
                        .background(Color(.systemGray6))
                }
                
                titleSection
                contentSection
            }
            .background(Color(.systemBackground))
            .navigationTitle((note.title?.isEmpty ?? true) ? "Note" : (note.title ?? "Note"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { saveAndDismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    if isSaving {
                        ProgressView().scaleEffect(0.8)
                    } else if hasUnsavedChanges {
                        Text("Unsaved").font(.caption).foregroundColor(.orange)
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        togglePin()
                    } label: {
                        Image(systemName: note.isPinned ? "pin.fill" : "pin")
                            .foregroundColor(note.isPinned ? .blue : .gray)
                    }

                    Spacer()

                    Button("Tags") { showingTagEditor = true }

                    Spacer()

                    Button {
                        if note.isEncrypted { showingDecryption = true } else { showingEncryption = true }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: note.isEncrypted ? "lock.fill" : "lock.open")
                            Text(note.isEncrypted ? "Decrypt" : "Encrypt")
                        }
                        .foregroundColor(note.isEncrypted ? .orange : .blue)
                    }

                    Spacer()

                    Button { showingExportOptions = true } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
            .sheet(isPresented: $showingTagEditor) { 
                Text("Tag Editor - Coming Soon")
                    .padding()
            }
            .sheet(isPresented: $showingEncryption) {
                EncryptionView(note: note) { success in if success { saveNote() } }
            }
            .sheet(isPresented: $showingDecryption) {
                DecryptionView(note: note) { success in if success { saveNote() } }
            }
            .sheet(isPresented: $showingExportOptions) { ExportOptionsView(note: note) }
            .alert("Error", isPresented: $showingError) { Button("OK") {} } message: { Text(errorMessage) }
            .onAppear { startAutoSave() }
            .onDisappear { stopAutoSave() }
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Title").font(.caption).foregroundColor(.secondary)
            TextField("Note title", text: Binding(
                get: { note.title ?? "" },
                set: { note.title = $0 }
            ))
                .font(.title3)
                .textFieldStyle(.plain)
                .onChange(of: note.title) { _, _ in markAsChanged() }
        }
        .padding()
        .background(Color(.systemGray6))
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Content").font(.caption).foregroundColor(.secondary)
                Spacer()
                Button(showingMarkdownPreview ? "Edit" : "Preview") { showingMarkdownPreview.toggle() }
                    .font(.caption).foregroundColor(.blue)
            }
            .padding(.horizontal).padding(.top, 8)

            if showingMarkdownPreview {
                ScrollView {
                    Text(note.content ?? "")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            } else {
                MarkdownEditor(text: Binding(
                    get: { note.content ?? "" },
                    set: { note.content = $0 }
                ), selectedRange: $selectedRange, coordinatorRef: $coordinatorRef)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                    .onChange(of: note.content) { _, _ in markAsChanged() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func markAsChanged() {
        hasUnsavedChanges = true
        note.modifiedDate = Date()
        
        // Create preview without image markers
        if let content = note.content {
            let cleaned = content.replacingOccurrences(of: "\\[IMG:[A-Za-z0-9+/=]+\\]", with: "[Image]", options: .regularExpression)
            note.preview = String(cleaned.prefix(100))
        }
        
        scheduleAutoSave()
    }

    private func togglePin() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        note.isPinned.toggle()
        saveNote()
    }

    private func startAutoSave() {
        // Auto-save is handled by the debounced text change detection
        // in the MarkdownEditor coordinator
    }

    private func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    private func scheduleAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { _ in
            if hasUnsavedChanges { saveNote() }
        }
    }

    private func saveNote() {
        guard !isSaving else { return }
        isSaving = true
        note.modifiedDate = Date()
        
        do {
            try viewContext.save()
            hasUnsavedChanges = false
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            showingError = true
        }
        isSaving = false
    }

    private func saveAndDismiss() {
        if hasUnsavedChanges { saveNote() }
        dismiss()
    }
}

// MARK: - New Note View
struct NewNoteView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    @State private var coordinatorRef: MarkdownEditor.Coordinator?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let coordinator = coordinatorRef {
                    MarkdownToolbarView(coordinator: coordinator)
                        .background(Color(.systemGray6))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title").font(.caption).foregroundColor(.secondary)
                    TextField("Note title", text: $title).font(.title3).textFieldStyle(.plain)
                }
                .padding()
                .background(Color(.systemGray6))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Content").font(.caption).foregroundColor(.secondary)
                        .padding(.horizontal).padding(.top, 8)
                    MarkdownEditor(text: $content, selectedRange: .constant(NSRange(location: 0, length: 0)), coordinatorRef: $coordinatorRef)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemBackground))
                }

                Spacer()
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveNote() }
                        .disabled(isSaving || (title.isEmpty && content.isEmpty))
                }
            }
            .alert("Error", isPresented: $showingError) { Button("OK") {} } message: { Text(errorMessage) }
        }
    }

    private func saveNote() {
        guard !isSaving else { return }
        guard !title.isEmpty || !content.isEmpty else { dismiss(); return }

        isSaving = true
        let newNote = Notes(context: viewContext)
        newNote.title = title.isEmpty ? "Untitled" : title
        newNote.content = content
        newNote.isMarkedDeleted = false
        newNote.createdDate = Date()
        newNote.modifiedDate = Date()
        newNote.id = UUID()
        
        // Create preview without image markers
        let cleaned = content.replacingOccurrences(of: "\\[IMG:[A-Za-z0-9+/=]+\\]", with: "[Image]", options: .regularExpression)
        newNote.preview = String(cleaned.prefix(100))

        viewContext.insert(newNote)

        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save note: \(error.localizedDescription)"
            showingError = true
            isSaving = false
        }
    }
}

// MARK: - Placeholder Views (imported from service files)