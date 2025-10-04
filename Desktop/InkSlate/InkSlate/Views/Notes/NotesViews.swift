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
    @Query(sort: \Note.modifiedDate, order: .reverse) private var notes: [Note]
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
    
    private var filteredNotes: [Note] {
        if searchDebouncer.searchText.isEmpty {
            return notes.filter { note in
                !note.isDeleted && (notesManager.selectedFolder == nil || note.folder == notesManager.selectedFolder)
            }
        } else {
            return notes.filter { note in
                !note.isDeleted && 
                (notesManager.selectedFolder == nil || note.folder == notesManager.selectedFolder) &&
                (note.title.localizedCaseInsensitiveContains(searchDebouncer.searchText) ||
                 note.attributedContent.string.localizedCaseInsensitiveContains(searchDebouncer.searchText))
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
            .sheet(item: $selectedNote) { note in
                NoteDetailView_Simple(note: note)
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
        .overlay(
            Group {
                if filteredNotes.isEmpty {
                    emptyStateView
                }
            }
        )
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
                Button(folder.name) {
                    notesManager.selectedFolder = folder
                }
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
                    guard !showingNewNote else { return }
                    let newNote = notesManager.createNote(with: modelContext)
                    selectedNote = newNote
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
        for index in offsets {
            let note = filteredNotes[index]
            notesManager.deleteNote(note, with: modelContext)
        }
    }
    
    private func deleteSelectedNotes() {
        filteredNotes.filter { selectedForDeletion.contains($0.persistentModelID) }
            .forEach { notesManager.deleteNote($0, with: modelContext) }
        selectedForDeletion.removeAll()
        editMode = .inactive
        try? modelContext.save()
        
        // Force refresh of the view
        DispatchQueue.main.async {
            self.searchText = self.searchText
        }
    }
}

// MARK: - Note Row View
struct NoteRowView: View {
    let note: Note
    @State private var showingPasswordPrompt = false
    @State private var showingLockOptions = false
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
                
                if !note.attributedContent.string.isEmpty {
                    Text(note.attributedContent.string)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
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
        .onLongPressGesture {
            showingLockOptions = true
        }
        .sheet(isPresented: $showingLockOptions) {
            LockOptionsView(note: note, notesManager: notesManager)
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
    
    var body: some View {
        NavigationView {
            List {
                ForEach(folders, id: \.persistentModelID) { folder in
                    Text(folder.name)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        modelContext.delete(folders[index])
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
    }
}

struct TrashView_Simple: View {
    let notesManager: NotesManager
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Note> { $0.isDeleted == true }) private var deletedNotes: [Note]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(deletedNotes, id: \.persistentModelID) { note in
                    Text(note.safeTitle)
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        modelContext.delete(deletedNotes[index])
                    }
                    try? modelContext.save()
                }
            }
            .navigationTitle("Recently Deleted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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
            print("Failed to save note: \(error)")
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

