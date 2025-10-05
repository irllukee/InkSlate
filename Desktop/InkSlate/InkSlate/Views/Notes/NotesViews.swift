//
//  NotesViews.swift
//  InkSlate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI
import SwiftData
import UIKit

// MARK: - Notes Feature Views

struct NotesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<Note> { !$0.isDeleted },
        sort: \Note.modifiedDate,
        order: .reverse
    ) private var notes: [Note]
    @Query(sort: \Folder.createdDate, order: .forward) private var folders: [Folder]
    @StateObject private var notesManager = NotesManager()
    @StateObject private var searchDebouncer = SearchDebouncer(delay: 0.3)
    
    @State private var searchText = ""
    @State private var selectedNote: Note?
    @State private var editMode: EditMode = .inactive
    @State private var selectedForDeletion: Set<PersistentIdentifier> = []
    @State private var showingCreateFolder = false
    @State private var showingFolderSheet = false
    @State private var showingTrashSheet = false
    @State private var showingNewNote = false
    @State private var newNote: Note?
    
    private var filteredNotes: [Note] {
        let baseFilter = notes.filter { note in
            notesManager.selectedFolder == nil || note.folder == notesManager.selectedFolder
        }
        
        if searchDebouncer.searchText.isEmpty {
            return baseFilter
        } else {
            return baseFilter.filter { note in
                note.title.localizedCaseInsensitiveContains(searchDebouncer.searchText) ||
                note.attributedContent.string.localizedCaseInsensitiveContains(searchDebouncer.searchText)
            }
        }
    }
    
    private var listSelection: Binding<Set<PersistentIdentifier>> {
        editMode == .active ? $selectedForDeletion : .constant(Set<PersistentIdentifier>())
    }
    
    var body: some View {
        notesListContent
            .environment(\.editMode, $editMode)
            .searchable(text: $searchText, prompt: "Search notes")
            .onChange(of: searchText) { _, newValue in
                searchDebouncer.searchText = newValue
            }
            .navigationTitle(notesManager.selectedFolder?.name ?? "Notes")
            .toolbar {
                toolbarContent
            }
            .sheet(isPresented: $showingCreateFolder) {
                CreateFolderView_Simple(notesManager: notesManager, modelContext: modelContext)
            }
            .sheet(isPresented: $showingFolderSheet) {
                FolderManagementView_Simple(notesManager: notesManager, modelContext: modelContext)
            }
            .sheet(isPresented: $showingTrashSheet) {
                TrashView_Simple(notesManager: notesManager, modelContext: modelContext)
            }
            .sheet(isPresented: $showingNewNote) {
                if let note = newNote {
                    NoteDetailView_Simple(note: note)
                }
            }
            .sheet(item: $selectedNote) { note in
                if note.isPasswordProtected {
                    PasswordAccessView(note: note, notesManager: notesManager, showingNoteDetail: .constant(false))
                } else {
                    NoteDetailView_Simple(note: note)
                }
            }
    }
    
    private var notesListContent: some View {
        List(selection: listSelection) {
            ForEach(filteredNotes, id: \.persistentModelID) { note in
                NoteRowView(note: note)
                    .contentShape(Rectangle())
                    .tag(note.persistentModelID)
                    .onTapGesture {
                        if editMode == .inactive {
                            selectedNote = note
                        }
                    }
            }
            .onDelete(perform: deleteNotes)
        }
        .animation(.easeInOut(duration: 0.3), value: filteredNotes.count)
        .overlay(
            Group {
                if filteredNotes.isEmpty {
                    emptyStateView
                }
            }
        )
        .onAppear {
            // Cleanup expired notes on app launch
            notesManager.cleanupExpiredNotes(with: modelContext)
        }
    }
    
    private var emptyStateView: some View {
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
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            folderMenu
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
            trailingToolbar
        }
    }
    
    private var folderMenu: some View {
        Menu {
            Button("All Notes") {
                notesManager.selectedFolder = nil
            }
            Divider()
            ForEach(folders, id: \.persistentModelID) { folder in
                FolderMenuButton(folder: folder, notesManager: notesManager, modelContext: modelContext)
            }
            Divider()
            Button("New Folder") {
                showingCreateFolder = true
            }
            Button("Manage Folders") {
                showingFolderSheet = true
            }
            Divider()
            Button("Recently Deleted") {
                showingTrashSheet = true
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "folder")
                if let folder = notesManager.selectedFolder {
                    Text(folder.name)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var trailingToolbar: some View {
        HStack(spacing: 16) {
            if editMode == .active {
                Button("Delete Selected") {
                    deleteSelectedNotes()
                }
                .disabled(selectedForDeletion.isEmpty)
            } else {
                Button {
                    newNote = notesManager.createNote(with: modelContext)
                    showingNewNote = true
                } label: {
                    Image(systemName: "square.and.pencil")
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                }
            }
        }
    }
    
    private func deleteNotes(offsets: IndexSet) {
        let notesToDelete = offsets.map { filteredNotes[$0] }
        
        // Mark for deletion IMMEDIATELY (no delay)
        for note in notesToDelete {
            notesManager.deleteNote(note, with: modelContext)
        }
        
        // The animation will happen automatically through SwiftUI's List updates
        // when the @Query updates and filteredNotes changes
    }
    
    private func deleteSelectedNotes() {
        let notesToDelete = filteredNotes.filter { selectedForDeletion.contains($0.persistentModelID) }
        
        // Mark for deletion IMMEDIATELY (no delay)
        for note in notesToDelete {
            notesManager.deleteNote(note, with: modelContext)
        }
        
        selectedForDeletion.removeAll()
        editMode = .inactive
        
        // The animation will happen automatically through SwiftUI's List updates
        // when the @Query updates and filteredNotes changes
    }
}

// MARK: - Note Row View
struct NoteRowView: View {
    let note: Note
    @State private var showingPasswordPrompt = false
    @State private var showingLockOptions = false
    @State private var showingNoteDetail = false
    @Environment(\.modelContext) private var modelContext
    @StateObject private var notesManager = NotesManager()
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: note.modifiedDate)
    }
    
    private var formattedDateFull: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: note.modifiedDate)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Main content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(note.safeTitle)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if note.isPasswordProtected {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 12))
                    }
                }
                
                if !note.isPasswordProtected && !note.attributedContent.string.isEmpty {
                    Text(note.attributedContent.string)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                } else if note.isPasswordProtected {
                    Text("🔒 Password Protected")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(.orange)
                        .lineLimit(1)
                }
            }
            
            // Time and folder info
            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedDate)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
                
                if let folder = note.folder {
                    Text(folder.name)
                        .font(.system(size: 10))
                        .foregroundColor(DesignSystem.Colors.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(DesignSystem.Colors.accent.opacity(0.1))
                        )
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .onTapGesture {
            if note.isPasswordProtected {
                showingPasswordPrompt = true
            } else {
                showingNoteDetail = true
            }
        }
        .onLongPressGesture {
            showingLockOptions = true
        }
        .sheet(isPresented: $showingLockOptions) {
            LockOptionsView(note: note, notesManager: notesManager)
        }
        .sheet(isPresented: $showingPasswordPrompt) {
            PasswordAccessView(note: note, notesManager: notesManager, showingNoteDetail: $showingNoteDetail)
        }
        .sheet(isPresented: $showingNoteDetail) {
            NoteDetailView_Simple(note: note)
        }
    }
}

// MARK: - Simple Placeholder Views
struct CreateFolderView_Simple: View {
    let notesManager: NotesManager
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @State private var folderName = ""
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Folder Name", text: $folderName)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let folder = Folder(name: folderName)
                        modelContext.insert(folder)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(folderName.isEmpty)
                }
            }
        }
    }
}

struct FolderManagementView_Simple: View {
    let notesManager: NotesManager
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var folders: [Folder]
    @State private var showingEditFolder: Folder?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(folders, id: \.persistentModelID) { folder in
                    FolderManagementRow(folder: folder, modelContext: modelContext, showingEditFolder: $showingEditFolder)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let folder = folders[index]
                        // Move notes to "All Notes" (no folder)
                        if let notes = folder.notes {
                            for note in notes {
                                note.folder = nil
                            }
                        }
                        modelContext.delete(folder)
                    }
                    try? modelContext.save()
                }
            }
            .navigationTitle("Manage Folders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(item: $showingEditFolder) { folder in
            EditFolderView(folder: folder, modelContext: modelContext)
        }
    }
}

struct FolderManagementRow: View {
    let folder: Folder
    let modelContext: ModelContext
    @Binding var showingEditFolder: Folder?
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name)
                    .font(.headline)
                
                if let notes = folder.notes, !notes.isEmpty {
                    Text("\(notes.count) note\(notes.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("Edit") {
                showingEditFolder = folder
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button("Delete") {
                showingDeleteAlert = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .foregroundColor(.red)
        }
        .alert("Delete Folder", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteFolder()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this folder? Notes in this folder will be moved to 'All Notes'.")
        }
    }
    
    private func deleteFolder() {
        // Move notes to "All Notes" (no folder)
        if let notes = folder.notes {
            for note in notes {
                note.folder = nil
            }
        }
        modelContext.delete(folder)
        try? modelContext.save()
    }
}

struct EditFolderView: View {
    let folder: Folder
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @State private var folderName: String
    
    init(folder: Folder, modelContext: ModelContext) {
        self.folder = folder
        self.modelContext = modelContext
        self._folderName = State(initialValue: folder.name)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Folder Name", text: $folderName)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("Edit Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        folder.name = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(folderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct FolderMenuButton: View {
    let folder: Folder
    let notesManager: NotesManager
    let modelContext: ModelContext
    @State private var showingEditFolder: Folder?
    @State private var showingDeleteAlert = false
    @State private var showingContextMenu = false
    
    var body: some View {
        Button(folder.name) {
            notesManager.selectedFolder = folder
        }
        .onLongPressGesture {
            showingContextMenu = true
        }
        .confirmationDialog("Folder Options", isPresented: $showingContextMenu) {
            Button("Edit Folder") {
                showingEditFolder = folder
            }
            
            Button("Delete Folder", role: .destructive) {
                showingDeleteAlert = true
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Choose an action for '\(folder.name)'")
        }
        .sheet(item: $showingEditFolder) { folder in
            EditFolderView(folder: folder, modelContext: modelContext)
        }
        .alert("Delete Folder", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                deleteFolder()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this folder? Notes in this folder will be moved to 'All Notes'.")
        }
    }
    
    private func deleteFolder() {
        // Move notes to "All Notes" (no folder)
        if let notes = folder.notes {
            for note in notes {
                note.folder = nil
            }
        }
        modelContext.delete(folder)
        try? modelContext.save()
        
        // Clear selection if this folder was selected
        if notesManager.selectedFolder?.persistentModelID == folder.persistentModelID {
            notesManager.selectedFolder = nil
        }
    }
}

struct TrashView_Simple: View {
    let notesManager: NotesManager
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Note> { $0.isDeleted == true }) private var deletedNotes: [Note]
    @State private var showingRestoreAlert = false
    @State private var noteToRestore: Note?
    
    var body: some View {
        NavigationView {
            List {
                ForEach(deletedNotes, id: \.persistentModelID) { note in
                    TrashNoteRowView(note: note, notesManager: notesManager)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Restore") {
                                noteToRestore = note
                                showingRestoreAlert = true
                            }
                            .tint(.green)
                            
                            Button("Delete Forever", role: .destructive) {
                                notesManager.permanentlyDelete(note, with: modelContext)
                            }
                            .tint(.red)
                        }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        notesManager.permanentlyDelete(deletedNotes[index], with: modelContext)
                    }
                }
            }
            .navigationTitle("Recently Deleted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Empty Trash") {
                        for note in deletedNotes {
                            notesManager.permanentlyDelete(note, with: modelContext)
                        }
                    }
                    .disabled(deletedNotes.isEmpty)
                }
            }
        }
        .alert("Restore Note", isPresented: $showingRestoreAlert) {
            Button("Restore") {
                if let note = noteToRestore {
                    notesManager.restoreNote(note, with: modelContext)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to restore this note?")
        }
    }
}

struct TrashNoteRowView: View {
    let note: Note
    let notesManager: NotesManager
    
    private var daysUntilExpiration: Int {
        guard let expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: note.deletedDate) else {
            return 0
        }
        let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        return max(0, daysLeft)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(note.safeTitle)
                    .font(.headline)
                
                Spacer()
                
                if daysUntilExpiration <= 3 {
                    Text("Expires in \(daysUntilExpiration) day\(daysUntilExpiration == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(4)
                } else {
                    Text("\(daysUntilExpiration) days left")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Deleted \(formatDate(note.deletedDate))")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Note Detail View with Rich Text Editor
struct NoteDetailView_Simple: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var title: String = ""
    @State private var attributedContent: NSAttributedString = NSAttributedString()
    @State private var showingToolbar = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Title Field
                VStack(spacing: 0) {
                    TextField("Note Title", text: $title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                    
                    Divider()
                        .background(Color(.separator))
                }
                
                // Rich Text Editor
                RichTextEditor(attributedText: $attributedContent)
                    .onChange(of: attributedContent) { _, newValue in
                        saveNote()
                    }
            }
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Toggle Toolbar") {
                            showingToolbar.toggle()
                        }
                        
                        Button("Clear Formatting") {
                            clearAllFormatting()
                        }
                        
                        Button("Export as Text") {
                            exportAsText()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            loadNote()
        }
        .onDisappear {
            saveNote()
        }
    }
    
    private func loadNote() {
        title = note.title
        attributedContent = note.attributedContent
    }
    
    private func saveNote() {
        note.title = title.isEmpty ? "Untitled Note" : title
        note.attributedContent = attributedContent
        note.modifiedDate = Date()
        
        do {
            try modelContext.save()
        } catch {
            // Handle save error silently
        }
    }
    
    private func clearAllFormatting() {
        let plainText = attributedContent.string
        attributedContent = NSAttributedString(string: plainText)
    }
    
    private func exportAsText() {
        let plainText = attributedContent.string
        UIPasteboard.general.string = plainText
    }
}

// MARK: - Lock Options View
struct LockOptionsView: View {
    let note: Note
    let notesManager: NotesManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showingPasswordPrompt = false
    @State private var showingRemovePasswordPrompt = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: note.isPasswordProtected ? "lock.fill" : "lock.open")
                        .font(.system(size: 60))
                        .foregroundColor(note.isPasswordProtected ? .orange : .gray)
                    
                    Text(note.isPasswordProtected ? "Note is Locked" : "Note is Unlocked")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(note.isPasswordProtected ? 
                         "This note is protected with a password" : 
                         "This note is not password protected")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 12) {
                    if note.isPasswordProtected {
                        Button("Change Password") {
                            showingPasswordPrompt = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("Remove Password", role: .destructive) {
                            showingRemovePasswordPrompt = true
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Set Password") {
                            showingPasswordPrompt = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Note Security")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingPasswordPrompt) {
            PasswordPromptView(note: note, notesManager: notesManager, isSettingPassword: !note.isPasswordProtected)
        }
        .alert("Remove Password", isPresented: $showingRemovePasswordPrompt) {
            Button("Remove", role: .destructive) {
                notesManager.removePassword(from: note)
                notesManager.saveNote(note, with: modelContext)
                dismiss()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove the password protection from this note?")
        }
    }
}

// MARK: - Password Access View
struct PasswordAccessView: View {
    let note: Note
    let notesManager: NotesManager
    @Binding var showingNoteDetail: Bool
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var password = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Password Required")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Enter password to access this note")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                        SecureField("Enter password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                verifyPassword()
                            }
                    }
                    
                    if !note.passwordHint.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Password Hint")
                                .font(.headline)
                            Text(note.passwordHint)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                    
                    // Warning about no password recovery
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Important")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                        
                        Text("⚠️ There is no password recovery option. If you forget your password, this note cannot be opened.")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Access Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Open") {
                        verifyPassword()
                    }
                    .disabled(password.isEmpty)
                }
            }
        }
        .alert("Incorrect Password", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func verifyPassword() {
        if notesManager.verifyPassword(for: note, password: password) {
            dismiss()
            showingNoteDetail = true
        } else {
            errorMessage = "Incorrect password. Please try again."
            showingError = true
            password = ""
        }
    }
}

// MARK: - Password Prompt View
struct PasswordPromptView: View {
    let note: Note
    let notesManager: NotesManager
    let isSettingPassword: Bool
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var hint = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    Image(systemName: isSettingPassword ? "lock.badge" : "lock.rotation")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text(isSettingPassword ? "Set Password" : "Change Password")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.headline)
                        SecureField("Enter password", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.headline)
                        SecureField("Confirm password", text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password Hint (Optional)")
                            .font(.headline)
                        TextField("Enter a hint", text: $hint)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    // Warning about no password recovery
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Important")
                                .font(.headline)
                                .foregroundColor(.orange)
                        }
                        
                        Text("⚠️ There is no password recovery option. If you forget your password, this note cannot be opened.")
                            .font(.caption)
                            .foregroundColor(.orange)
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle(isSettingPassword ? "Set Password" : "Change Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePassword()
                    }
                    .disabled(password.isEmpty || password != confirmPassword)
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func savePassword() {
        guard !password.isEmpty else {
            errorMessage = "Password cannot be empty"
            showingError = true
            return
        }
        
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match"
            showingError = true
            return
        }
        
        guard password.count >= 4 else {
            errorMessage = "Password must be at least 4 characters"
            showingError = true
            return
        }
        
        notesManager.setPassword(for: note, password: password, hint: hint.isEmpty ? nil : hint)
        notesManager.saveNote(note, with: modelContext)
        dismiss()
    }
}

