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
    
    @FetchRequest private var normalNotes: FetchedResults<Notes>
    @FetchRequest private var deletedNotes: FetchedResults<Notes>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FSProject.name, ascending: true)]
    ) private var projects: FetchedResults<FSProject>

    @StateObject private var searchDebouncer = SearchDebouncer(delay: 0.4)
    @State private var searchQuery: String = ""

    @State private var showingNewNoteSheet = false
    @State private var selectedNote: Notes?
    @State private var selectedProject: FSProject?
    @State private var showingProjectSidebar = NavigationSplitViewVisibility.detailOnly
    @State private var showingFoldersSheet = false
    @State private var showingNewProjectSheet = false
    @State private var showingProjectSettings = false
    @State private var showingTagManager = false
    @State private var noteToMove: Notes?
    
    @AppStorage("lastSelectedFolderID") private var lastSelectedFolderID: String?

    @State private var sortBy: SortBy = .modificationDate
    @State private var sortDirection: SortDirection = .descending
    @State private var showPinnedOnly = false

    @State private var showingDeletedNotes = false
    @State private var showingEmptyTrashAlert = false

    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    init() {
        let defaultSort = [NSSortDescriptor(key: "modifiedDate", ascending: false)]
        _normalNotes = FetchRequest(
            sortDescriptors: defaultSort,
            predicate: NSPredicate(format: "isMarkedDeleted == NO"),
            animation: .default
        )
        _deletedNotes = FetchRequest(
            sortDescriptors: defaultSort,
            predicate: NSPredicate(format: "isMarkedDeleted == YES"),
            animation: .default
        )
    }
    
    private var defaultProject: FSProject? {
        projects.first { $0.isDefault } ?? projects.first
    }
    
    private func loadLastSelectedFolder() {
        // Start with "All Notes" (nil) if no saved preference
        guard let folderIDString = lastSelectedFolderID,
              let folderID = UUID(uuidString: folderIDString) else {
            selectedProject = nil
            return
        }
        
        // Try to find the saved folder
        if let savedFolder = projects.first(where: { $0.id == folderID }) {
            selectedProject = savedFolder
        } else {
            // Folder was deleted, reset to "All Notes"
            selectedProject = nil
            lastSelectedFolderID = nil
        }
    }
    
    private func saveLastSelectedFolder(_ folder: FSProject?) {
        if let folder = folder {
            lastSelectedFolderID = folder.id?.uuidString
        } else {
            lastSelectedFolderID = nil
        }
    }

    private var activeNotes: FetchedResults<Notes> {
        showingDeletedNotes ? deletedNotes : normalNotes
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
            .navigationTitle(showingDeletedNotes ? "Recently Deleted" : (selectedProject?.name ?? "All Notes"))
            .overlay { if isLoading { loadingOverlay } }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !showingDeletedNotes {
                        Button {
                            showingFoldersSheet = true
                        } label: {
                            Image(systemName: "folder")
                        }
                        .accessibilityLabel("Folders")
                    } else {
                    Button {
                        withAnimation(.easeInOut) { showingDeletedNotes.toggle() }
                    } label: {
                            Image(systemName: "arrow.left")
                    }
                        .accessibilityLabel("Back to Notes")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                        HStack(spacing: 12) {
                    if !showingDeletedNotes {
                                Button {
                                    showingTagManager = true
                                } label: {
                                    Image(systemName: "tag")
                                }
                                .accessibilityLabel("Tags")
                                
                                if selectedProject != nil {
                                    Button {
                                        showingProjectSettings = true
                                    } label: {
                                        Image(systemName: "gearshape")
                                    }
                                    .accessibilityLabel("Folder Settings")
                                }
                                
                        Button {
                            showingNewNoteSheet = true
                        } label: { Image(systemName: "square.and.pencil") }
                        .accessibilityLabel("New Note")
                    }
                }
            }
                }
                .sheet(isPresented: $showingFoldersSheet) {
                    FoldersListView(selectedProject: $selectedProject, showingNewProjectSheet: $showingNewProjectSheet)
                }
                .sheet(isPresented: $showingNewNoteSheet) { 
                    NewNoteView(selectedProject: selectedProject)
                }
                .sheet(isPresented: $showingNewProjectSheet) {
                    NewProjectView()
                }
                .sheet(isPresented: $showingProjectSettings) {
                    if let project = selectedProject {
                        ProjectSettingsView(project: project)
                    }
                }
                .sheet(isPresented: $showingTagManager) {
                    TagManagerView()
                }
                .sheet(item: $noteToMove) { note in
                    MoveToFolderView(note: note) {
                        noteToMove = nil
                    }
                }
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
                .onAppear { 
                    purgeOldDeletedNotes()
                    loadLastSelectedFolder()
                }
                .onReceive(searchDebouncer.$debouncedText) { value in
                    searchQuery = value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                .onChange(of: selectedProject) { _, newValue in
                    saveLastSelectedFolder(newValue)
                }
            }
        }
    }

// MARK: - Folders List View (Sheet)
struct FoldersListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Notes.modifiedDate, ascending: false)],
        predicate: NSPredicate(format: "isMarkedDeleted == NO")
    ) private var normalNotes: FetchedResults<Notes>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FSProject.name, ascending: true)]
    ) private var projects: FetchedResults<FSProject>
    
    @Binding var selectedProject: FSProject?
    @Binding var showingNewProjectSheet: Bool
    
    @AppStorage("lastSelectedFolderID") private var lastSelectedFolderID: String?
    
    @State private var projectToDelete: FSProject?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // All Notes Folder - Always visible
                Button {
                    withAnimation {
                        selectedProject = nil
                    }
                    saveFolderSelection(nil)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("All Notes")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text("\(normalNotes.count) notes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        if selectedProject == nil {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 18))
                        }
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
                .listRowBackground(selectedProject == nil ? Color.blue.opacity(0.1) : Color.clear)
                
                // User Created Folders
                if !projects.isEmpty {
                    Section {
                        ForEach(projects) { project in
                            Button {
                                withAnimation {
                                    selectedProject = project
                                }
                                saveFolderSelection(project)
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(project.name ?? "Unnamed Folder")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        if let notes = project.notes as? Set<Notes> {
                                            let count = notes.filter { !$0.isMarkedDeleted }.count
                                            Text("\(count) notes")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedProject?.id == project.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 18))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(selectedProject?.id == project.id ? Color.blue.opacity(0.1) : Color.clear)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    projectToDelete = project
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        Text("Folders")
                    }
                }
                
                // New Folder Button
                Section {
                    Button {
                        showingNewProjectSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("New Folder")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Folders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewProjectSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .alert("Delete Folder", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { projectToDelete = nil }
                Button("Delete", role: .destructive) {
                    if let project = projectToDelete {
                        deleteProject(project)
                        projectToDelete = nil
                    }
                }
            } message: {
                Text("Are you sure you want to delete this folder? All notes in this folder will be moved to 'All Notes'.")
            }
            .sheet(isPresented: $showingNewProjectSheet) {
                NewProjectView()
            }
        }
    }
    
    private func deleteProject(_ project: FSProject) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        if selectedProject?.id == project.id {
            selectedProject = nil
        }
        
        // Move notes to "All Notes" (remove folder assignment)
        if let notes = project.notes as? Set<Notes> {
            for note in notes {
                note.project = nil
            }
        }
        
        viewContext.delete(project)
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete folder: \(error.localizedDescription)")
        }
    }
    
    private func saveFolderSelection(_ folder: FSProject?) {
        if let folder = folder {
            lastSelectedFolderID = folder.id?.uuidString
        } else {
            lastSelectedFolderID = nil
        }
    }
}

extension NotesListView {
    private var toolbarView: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                SearchBar(text: $searchDebouncer.searchText)

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

            Text(showingDeletedNotes ? "No deleted notes" : (searchQuery.isEmpty ? "No notes yet" : "No notes found"))
                .font(.headline)
                .foregroundColor(.gray)

            if !showingDeletedNotes && searchQuery.isEmpty {
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
                        Button {
                            noteToMove = note
                        } label: {
                            Label("Move", systemImage: "folder")
                        }
                        .tint(.orange)

                        Button {
                            togglePin(note)
                        } label: {
                            Label(note.isPinned ? "Unpin" : "Pin",
                                  systemImage: note.isPinned ? "pin.slash" : "pin")
                        }
                        .tint(.blue)

                        Button(role: .destructive) {
                            softDelete(note)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: filteredNotes.map { $0.id })
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
    
    // Lazy filtering - FetchedResults is already lazy from Core Data
    // We use lazy sequences to avoid materializing the entire collection upfront
    // SwiftUI's List only renders visible items, so this is efficient
    private var filteredNotes: [Notes] {
        PerformanceLogger.measure(log: PerformanceMetrics.notesQuery, name: "FilterNotes") {
            // FetchedResults is already lazy - only fetches objects as accessed
            // Use lazy sequence for filtering to avoid materializing entire collection
            let lazySequence = activeNotes.lazy
            
            // Apply filters lazily - only evaluates when iterated
            // Use type erasure to handle the changing sequence types from chained filters
            var filtered: AnySequence<Notes> = AnySequence(lazySequence)
            
            // Filter by project (lazy evaluation)
            if let selectedProject = selectedProject, !showingDeletedNotes {
                filtered = AnySequence(filtered.lazy.filter { $0.project == selectedProject })
            }
            
            // Filter by pinned (lazy evaluation)
            if showPinnedOnly && !showingDeletedNotes {
                filtered = AnySequence(filtered.lazy.filter { $0.isPinned })
            }
            
            // Filter by search (lazy evaluation)
            if !searchDebouncer.debouncedText.isEmpty {
                let searchLower = searchDebouncer.debouncedText.lowercased()
                filtered = AnySequence(filtered.lazy.filter { note in
                    (note.title?.lowercased().contains(searchLower) ?? false) ||
                    (note.content?.lowercased().contains(searchLower) ?? false) ||
                    (note.preview?.lowercased().contains(searchLower) ?? false)
                })
            }
            
            // Convert to array only when needed (SwiftUI ForEach requires concrete collection)
            // The lazy sequence ensures we only process items as they're accessed during conversion
            var result = Array(filtered)
            
            // Sort only the filtered results (in-place sort is efficient)
            let ascending = sortDirection == .ascending
            switch sortBy {
            case .modificationDate:
                result.sort { ascending ? ($0.modifiedDate ?? Date.distantPast) < ($1.modifiedDate ?? Date.distantPast) : ($0.modifiedDate ?? Date.distantPast) > ($1.modifiedDate ?? Date.distantPast) }
            case .creationDate:
                result.sort { ascending ? ($0.createdDate ?? Date.distantPast) < ($1.createdDate ?? Date.distantPast) : ($0.createdDate ?? Date.distantPast) > ($1.createdDate ?? Date.distantPast) }
            case .title:
                result.sort { ascending ? ($0.title ?? "") < ($1.title ?? "") : ($0.title ?? "") > ($1.title ?? "") }
            case .pin:
                result.sort {
                    if ascending { ($0.isPinned ? 0 : 1) < ($1.isPinned ? 0 : 1) }
                    else { ($0.isPinned ? 0 : 1) > ($1.isPinned ? 0 : 1) }
                }
            }
            
            return result
        }
    }
    
    private func buildSortDescriptors() -> [NSSortDescriptor] {
        let ascending = sortDirection == .ascending
        let primary: NSSortDescriptor
        switch sortBy {
        case .modificationDate:
            primary = NSSortDescriptor(key: "modifiedDate", ascending: ascending)
        case .creationDate:
            primary = NSSortDescriptor(key: "createdDate", ascending: ascending)
        case .title:
            primary = NSSortDescriptor(key: "title", ascending: ascending, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        case .pin:
            primary = NSSortDescriptor(key: "isPinned", ascending: ascending)
        }
        let secondary = NSSortDescriptor(key: "modifiedDate", ascending: false)
        return [primary, secondary]
    }
    
    private func buildSearchPredicate(with query: String) -> NSPredicate {
        let format = "(title CONTAINS[cd] %@) OR (content CONTAINS[cd] %@) OR (preview CONTAINS[cd] %@)"
        return NSPredicate(format: format, query, query, query)
    }
    
    private func deleteProject(_ project: FSProject) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        if selectedProject?.id == project.id {
            withAnimation {
                selectedProject = nil
            }
        }
        
        viewContext.delete(project)
        saveOrAlert("Failed to delete folder")
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
                
                if let project = note.project {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                        Text(project.name ?? "Folder")
                            .font(.caption2)
                            .foregroundColor(.blue)
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
            .fullScreenCover(isPresented: $showingMarkdownPreview) {
                NotePreviewScreen(note: note, isPresented: $showingMarkdownPreview)
            }
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
            
            HStack {
                Text("Folder").font(.caption).foregroundColor(.secondary)
                Spacer()
                ProjectPickerView(selectedProject: Binding(
                    get: { note.project },
                    set: { note.project = $0; markAsChanged() }
                ))
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    private struct ProjectPickerView: View {
        @Environment(\.managedObjectContext) private var viewContext
        @FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \FSProject.name, ascending: true)]
        ) private var projects: FetchedResults<FSProject>
        
        @Binding var selectedProject: FSProject?
        
        var body: some View {
            Picker("Folder", selection: $selectedProject) {
                Text("None").tag(FSProject?.none)
                ForEach(projects) { project in
                    Text(project.name ?? "Unnamed Folder").tag(FSProject?.some(project))
                }
            }
            .pickerStyle(.menu)
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Content").font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("Preview") { showingMarkdownPreview = true }
                    .font(.caption).foregroundColor(.blue)
            }
            .padding(.horizontal).padding(.top, 8)

            MarkdownEditor(text: Binding(
                get: { note.content ?? "" },
                set: { note.content = $0 }
            ), selectedRange: $selectedRange, coordinatorRef: $coordinatorRef)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .onChange(of: note.content) { _, _ in markAsChanged() }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func markAsChanged() {
        hasUnsavedChanges = true
        note.modifiedDate = Date()
        
        // Create preview without image markers
        if let content = note.content {
            let plain = MarkdownSerialization.plainText(from: content)
            note.preview = String(plain.prefix(100))
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
        // Auto-save is handled by scheduleAutoSave() called from markAsChanged()
    }

    private func stopAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
    }

    private func scheduleAutoSave() {
        autoSaveTimer?.invalidate()
        // Save quickly after typing stops (1.5 seconds) - feels instant like iOS Notes
        // but still debounces to avoid saving on every single keystroke
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { _ in
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

struct NotePreviewScreen: View {
    @ObservedObject var note: Notes
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            MarkdownPreviewContainer(content: note.content ?? "")
                .navigationTitle((note.title?.isEmpty ?? true) ? "Preview" : (note.title ?? "Preview"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { isPresented = false }
                    }
                }
        }
    }
}

private struct MarkdownPreviewContainer: View {
    let content: String
    
    var body: some View {
        ScrollView {
            MarkdownPreviewTextView(content: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
        }
        .background(Color(.systemBackground))
    }
}

private struct MarkdownPreviewTextView: UIViewRepresentable {
    let content: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = false
        textView.isScrollEnabled = false
        textView.adjustsFontForContentSizeCategory = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        let width = max(uiView.bounds.width - 28, UIScreen.main.bounds.width - 48)
        if let (attributed, _) = MarkdownSerialization.deserialize(content, maxWidth: width) {
            uiView.attributedText = attributed
        } else {
            uiView.attributedText = EditorContentParser.deserialize(content, maxWidth: width)
        }
    }
}

// MARK: - New Note View
struct NewNoteView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FSProject.name, ascending: true)]
    ) private var projects: FetchedResults<FSProject>
    
    let selectedProject: FSProject?

    @State private var title: String = ""
    @State private var content: String = ""
    @State private var project: FSProject?
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
                    Text("Folder").font(.caption).foregroundColor(.secondary)
                    Picker("Folder", selection: $project) {
                        Text("None").tag(FSProject?.none)
                        ForEach(projects) { proj in
                            Text(proj.name ?? "Unnamed Folder").tag(FSProject?.some(proj))
                        }
                    }
                    .pickerStyle(.menu)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

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
            .onAppear {
                project = selectedProject
            }
        }
    }

    private func saveNote() {
        guard !isSaving else { return }
        guard !title.isEmpty || !content.isEmpty else { dismiss(); return }

        isSaving = true
        let newNote = Notes(context: viewContext)
        newNote.id = UUID()  // Required for CloudKit sync
        newNote.title = title.isEmpty ? "Untitled" : title
        newNote.content = content
        newNote.project = project ?? selectedProject
        newNote.isMarkedDeleted = false
        newNote.createdDate = Date()
        newNote.modifiedDate = Date()
        
        // Create preview without image markers
        let plain = MarkdownSerialization.plainText(from: content)
        newNote.preview = String(plain.prefix(100))

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

// MARK: - New Folder View
struct NewProjectView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var isDefault: Bool = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Folder name", text: $name)
                        .textInputAutocapitalization(.words)
                } header: {
                    Text("Folder Details")
                }
                
                Section {
                    Toggle("Set as default folder", isOn: $isDefault)
                } footer: {
                    Text("Default folder will be selected automatically when viewing notes.")
                }
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { saveProject() }
                        .disabled(isSaving || name.isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) { Button("OK") {} } message: { Text(errorMessage) }
        }
    }
    
    private func saveProject() {
        guard !isSaving else { return }
        guard !name.isEmpty else { return }
        
        isSaving = true
        
        // If setting as default, unset other defaults
        if isDefault {
            let fetchRequest = NSFetchRequest<FSProject>(entityName: "FSProject")
            if let existingProjects = try? viewContext.fetch(fetchRequest) {
                for project in existingProjects {
                    project.isDefault = false
                }
            }
        }
        
        let newProject = FSProject(context: viewContext)
        newProject.name = name
        newProject.isDefault = isDefault
        newProject.id = UUID()
        newProject.createdDate = Date()
        newProject.modifiedDate = Date()
        
        // Create default settings
        let settings = ProjectSettings(context: viewContext)
        settings.id = UUID()
        settings.project = newProject
        settings.filterBy = "all"
        settings.groupBy = "none"
        settings.searchScope = "titleAndContent"
        settings.sortBy = "modifiedDate"
        settings.sortOrder = "descending"
        settings.showCreatedDate = true
        settings.showModifiedDate = true
        settings.showPreview = true
        settings.showTags = true
        
        viewContext.insert(newProject)
        viewContext.insert(settings)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to create folder: \(error.localizedDescription)"
            showingError = true
            isSaving = false
        }
    }
}

// MARK: - Folder Settings View
struct ProjectSettingsView: View {
    @ObservedObject var project: FSProject
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var settings: ProjectSettings?
    @State private var filterBy: String = "all"
    @State private var groupBy: String = "none"
    @State private var searchScope: String = "titleAndContent"
    @State private var sortBy: String = "modifiedDate"
    @State private var sortOrder: String = "descending"
    @State private var showCreatedDate: Bool = true
    @State private var showModifiedDate: Bool = true
    @State private var showPreview: Bool = true
    @State private var showTags: Bool = true
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Display Options") {
                    Toggle("Show Created Date", isOn: $showCreatedDate)
                    Toggle("Show Modified Date", isOn: $showModifiedDate)
                    Toggle("Show Preview", isOn: $showPreview)
                    Toggle("Show Tags", isOn: $showTags)
                }
                
                Section("Sorting") {
                    Picker("Sort By", selection: $sortBy) {
                        Text("Modified Date").tag("modifiedDate")
                        Text("Created Date").tag("createdDate")
                        Text("Title").tag("title")
                        Text("Pin Status").tag("pin")
                    }
                    
                    Picker("Sort Order", selection: $sortOrder) {
                        Text("Ascending").tag("ascending")
                        Text("Descending").tag("descending")
                    }
                }
                
                Section("Search") {
                    Picker("Search Scope", selection: $searchScope) {
                        Text("Title & Content").tag("titleAndContent")
                        Text("Title Only").tag("title")
                        Text("Content Only").tag("content")
                    }
                }
                
                Section("Filtering") {
                    Picker("Filter By", selection: $filterBy) {
                        Text("All").tag("all")
                        Text("Pinned").tag("pinned")
                        Text("Unpinned").tag("unpinned")
                    }
                    
                    Picker("Group By", selection: $groupBy) {
                        Text("None").tag("none")
                        Text("Date").tag("date")
                        Text("Tag").tag("tag")
                    }
                }
            }
            .navigationTitle("Folder Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSettings() }
                }
            }
            .alert("Error", isPresented: $showingError) { Button("OK") {} } message: { Text(errorMessage) }
            .onAppear {
                loadSettings()
            }
        }
    }
    
    private func loadSettings() {
        if let existingSettings = project.settings {
            settings = existingSettings
            filterBy = existingSettings.filterBy ?? "all"
            groupBy = existingSettings.groupBy ?? "none"
            searchScope = existingSettings.searchScope ?? "titleAndContent"
            sortBy = existingSettings.sortBy ?? "modifiedDate"
            sortOrder = existingSettings.sortOrder ?? "descending"
            showCreatedDate = existingSettings.showCreatedDate
            showModifiedDate = existingSettings.showModifiedDate
            showPreview = existingSettings.showPreview
            showTags = existingSettings.showTags
        } else {
            // Create new settings
            let newSettings = ProjectSettings(context: viewContext)
            newSettings.id = UUID()
            newSettings.project = project
            settings = newSettings
        }
    }
    
    private func saveSettings() {
        guard let settings = settings else { return }
        
        settings.filterBy = filterBy
        settings.groupBy = groupBy
        settings.searchScope = searchScope
        settings.sortBy = sortBy
        settings.sortOrder = sortOrder
        settings.showCreatedDate = showCreatedDate
        settings.showModifiedDate = showModifiedDate
        settings.showPreview = showPreview
        settings.showTags = showTags
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save settings: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Tag Manager View
struct TagManagerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \FSTag.isSystem, ascending: false),
            NSSortDescriptor(keyPath: \FSTag.name, ascending: true)
        ]
    ) private var tags: FetchedResults<FSTag>
    
    @State private var showingNewTag = false
    @State private var selectedTag: FSTag?
    @State private var showingEditTag = false
    
    var body: some View {
        NavigationStack {
            List {
                if tags.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            Image(systemName: "tag")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("No tags yet")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("Create tags to organize your notes")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    }
                } else {
                    let systemTags = tags.filter { $0.isSystem }
                    let customTags = tags.filter { !$0.isSystem }
                    
                    if !systemTags.isEmpty {
                        Section("System Tags") {
                            ForEach(systemTags) { tag in
                                TagRowView(tag: tag)
                            }
                        }
                    }
                    
                    if !customTags.isEmpty {
                        Section("Custom Tags") {
                            ForEach(customTags) { tag in
                                TagRowView(tag: tag)
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            deleteTag(tag)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tags")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewTag = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewTag) {
                NewTagView()
            }
        }
    }
    
    private func deleteTag(_ tag: FSTag) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        viewContext.delete(tag)
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete tag: \(error.localizedDescription)")
        }
    }
}

// MARK: - Tag Row View
struct TagRowView: View {
    @ObservedObject var tag: FSTag
    
    var body: some View {
        HStack {
            Circle()
                .fill(Color(hex: tag.color ?? "#007AFF") ?? .blue)
                .frame(width: 12, height: 12)
            
            Text(tag.name ?? "Unnamed Tag")
                .font(.body)
            
            if tag.isSystem {
                Spacer()
                Text("System")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - New Tag View
struct NewTagView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FSTag.name, ascending: true)]
    ) private var allTags: FetchedResults<FSTag>
    
    @State private var name: String = ""
    @State private var color: String = "#007AFF"
    @State private var parentTag: FSTag?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isSaving = false
    
    let colors: [String] = ["#007AFF", "#FF3B30", "#34C759", "#FF9500", "#5856D6", "#FF2D55", "#5AC8FA", "#AF52DE"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tag name", text: $name)
                } header: {
                    Text("Tag Details")
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(colors, id: \.self) { colorHex in
                            Button {
                                color = colorHex
                            } label: {
                                Circle()
                                    .fill(Color(hex: colorHex) ?? .blue)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(color == colorHex ? Color.primary : Color.clear, lineWidth: 3)
                                    )
                            }
                        }
                    }
                }
                
                Section {
                    Picker("Parent Tag", selection: $parentTag) {
                        Text("None").tag(FSTag?.none)
                        ForEach(allTags) { tag in
                            Text(tag.name ?? "Unnamed").tag(FSTag?.some(tag))
                        }
                    }
                } header: {
                    Text("Parent Tag")
                } footer: {
                    Text("Select a parent tag to create a hierarchical tag structure.")
                }
            }
            .navigationTitle("New Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveTag() }
                        .disabled(isSaving || name.isEmpty)
                }
            }
            .alert("Error", isPresented: $showingError) { Button("OK") {} } message: { Text(errorMessage) }
        }
    }
    
    private func saveTag() {
        guard !isSaving else { return }
        guard !name.isEmpty else { return }
        
        isSaving = true
        
        let newTag = FSTag(context: viewContext)
        newTag.name = name
        newTag.color = color
        newTag.parentTag = parentTag
        newTag.isSystem = false
        newTag.id = UUID()
        newTag.createdDate = Date()
        newTag.modifiedDate = Date()
        
        viewContext.insert(newTag)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save tag: \(error.localizedDescription)"
            showingError = true
            isSaving = false
        }
    }
}

// MARK: - Move to Folder View
struct MoveToFolderView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject var note: Notes
    let onDismiss: () -> Void
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FSProject.name, ascending: true)]
    ) private var projects: FetchedResults<FSProject>
    
    var body: some View {
        NavigationStack {
            Form {
                // Move to "All Notes" (no folder)
                Section {
                    Button {
                        moveNoteToFolder(nil)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "folder.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("All Notes")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Remove from folder")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if note.project == nil {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 18))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
                
                // User Created Folders
                Section("Folders") {
                    if projects.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "folder")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("No folders yet")
                                .font(.headline)
                                .foregroundColor(.gray)
                            Text("Create a folder to organize your notes")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(projects) { project in
                            Button {
                                moveNoteToFolder(project)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "folder.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(project.name ?? "Unnamed Folder")
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        if let notes = project.notes as? Set<Notes> {
                                            let count = notes.filter { !$0.isMarkedDeleted }.count
                                            Text("\(count) notes")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if note.project?.id == project.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 18))
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Move to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func moveNoteToFolder(_ folder: FSProject?) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        note.project = folder
        note.modifiedDate = Date()
        
        do {
            try viewContext.save()
            onDismiss()
            dismiss()
        } catch {
            print("Failed to move note: \(error.localizedDescription)")
        }
    }
}

// MARK: - Placeholder Views (imported from service files)