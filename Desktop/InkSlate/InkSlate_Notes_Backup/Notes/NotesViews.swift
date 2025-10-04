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

struct NotesListView_Complex: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Note.modifiedDate, order: .reverse) private var notes: [Note]
    @Query(sort: \Folder.createdDate, order: .forward) private var folders: [Folder]
    @StateObject private var notesManager = NotesManager()
    @StateObject private var searchDebouncer = SearchDebouncer(delay: 0.3)
    @State private var searchText = ""
    @State private var showingNewNote = false
    @State private var selectedNote: Note?
    @State private var showingFolderSheet = false
    @State private var editMode = EditMode.inactive
    @State private var selectedForDeletion: Set<PersistentIdentifier> = []
    @State private var showingTrash = false
    @State private var showingTrashSheet = false
    @EnvironmentObject var sharedStateManager: SharedStateManager
    
    var filteredNotes: [Note] {
        let folderFiltered = notesManager.selectedFolder == nil ? 
            notes : 
            notes.filter { $0.folder?.persistentModelID == notesManager.selectedFolder?.persistentModelID }
        let notDeleted = folderFiltered.filter { !$0.isDeleted }
        
        if searchDebouncer.debouncedText.isEmpty {
            return Array(notDeleted) // Already sorted by query
        }
        
        let searchLower = searchDebouncer.debouncedText.lowercased()
        return notDeleted.filter { note in
            note.safeTitle.lowercased().contains(searchLower) ||
            note.attributedContent.string.lowercased().contains(searchLower)
        } // Already sorted by query
    }
    
    private var listSelection: Binding<Set<PersistentIdentifier>> {
        editMode == .active ? $selectedForDeletion : .constant(Set<PersistentIdentifier>())
    }
    
    var body: some View {
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
        .environment(\.editMode, $editMode)
        .searchable(text: $searchText, prompt: "Search notes")
        .onChange(of: searchText) { _, newValue in
            searchDebouncer.searchText = newValue
        }
        .navigationTitle(notesManager.selectedFolder?.name ?? "Notes")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
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
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if editMode == .active {
                        Button("Delete Selected") {
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
        }
        .overlay(
            Group {
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
        )
        .sheet(isPresented: $showingFolderSheet) {
            NewFolderView(notesManager: notesManager)
        }
        .sheet(item: $selectedNote) { note in
            NavigationView {
                RichTextEditorView(note: note)
            }
            .onDisappear {
                showingNewNote = false
            }
        }
        .sheet(isPresented: $showingTrashSheet) {
            RecentlyDeletedView()
        }
    }
    
    private func deleteNotes(at offsets: IndexSet) {
        for index in offsets {
            let note = filteredNotes[index]
            notesManager.deleteNote(note, with: modelContext)
        }
        try? modelContext.save()
        
        // Force refresh of the view
        DispatchQueue.main.async {
            // Trigger a view update by toggling a state variable
            self.searchText = self.searchText
        }
    }
}

// MARK: - Recently Deleted View
struct RecentlyDeletedView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Note> { $0.isDeleted == true }, sort: \Note.deletedDate, order: .reverse) private var deletedNotes: [Note]
    @State private var selected: Set<PersistentIdentifier> = []
    @StateObject private var notesManager = NotesManager()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(deletedNotes, id: \.persistentModelID) { note in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(note.safeTitle)
                                .font(DesignSystem.Typography.body)
                            if !note.attributedContent.string.isEmpty {
                                Text(note.attributedContent.string)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Button("Restore") {
                            notesManager.restoreNote(note, with: modelContext)
                        }
                        .buttonStyle(.bordered)
                        Button(role: .destructive) {
                            notesManager.permanentlyDelete(note, with: modelContext)
                        } label: {
                            Text("Delete")
                        }
                    }
                }
            }
            .navigationTitle("Recently Deleted")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Empty All", role: .destructive) {
                        deletedNotes.forEach { notesManager.permanentlyDelete($0, with: modelContext) }
                    }
                }
            }
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

// MARK: - New Folder View
struct NewFolderView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var folderName = ""
    let notesManager: NotesManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Folder Name")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    ModernTaskTextField(
                        text: $folderName,
                        placeholder: "Enter folder name",
                        isFocused: .constant(false),
                        isMultiline: false
                    )
                }
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.background)
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
    @StateObject private var autoSaveManager = AutoSaveManager()
    @State private var noteTitle: String
    @State private var selectedColor: Color = .black
    @State private var showingFolderPicker = false
    @State private var showingPasswordProtection = false
    @State private var isUnlocked = true
    @State private var showingPasswordUnlock = false
    
    init(note: Note) {
        self.note = note
        _noteTitle = State(initialValue: note.safeTitle)
        _viewModel = StateObject(wrappedValue: RichTextViewModel(note: note))
        _isUnlocked = State(initialValue: !note.isPasswordProtected)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isUnlocked {
                // Title Field
                TextField("Title", text: $noteTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding()
                    .background(Color(.systemGray6))
                    .onChange(of: noteTitle) {
                        autoSaveManager.scheduleSave()
                    }
                
                // Text Editor
                RichTextEditor(attributedText: $viewModel.attributedText, viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onChange(of: viewModel.attributedText) {
                        autoSaveManager.scheduleSave()
                    }
            } else {
                // Locked content view
                VStack(spacing: 20) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("This note is password protected")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let hint = note.passwordHint, !hint.isEmpty {
                        Text("Hint: \(hint)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button("Unlock Note") {
                        showingPasswordUnlock = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
            }
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
                    
                    Button(note.isPasswordProtected ? "Password Settings" : "Password Protection") {
                        showingPasswordProtection = true
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
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
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
        .sheet(isPresented: $showingPasswordProtection) {
            PasswordPromptView(note: note, notesManager: NotesManager(), isSettingPassword: !note.isPasswordProtected)
        }
        .sheet(isPresented: $showingPasswordUnlock) {
            PasswordUnlockView(note: note, isUnlocked: $isUnlocked)
        }
        .onAppear {
            // Check if note is password protected and needs unlocking
            if note.isPasswordProtected {
                isUnlocked = false
                showingPasswordUnlock = true
            }
        }
        .onChange(of: isUnlocked) { _, newValue in
            if !newValue && note.isPasswordProtected {
                // If unlock failed, show the unlock sheet again
                showingPasswordUnlock = true
            }
        }
        .onDisappear {
            saveNote()
        }
    }
    
    private func saveNote() {
        note.title = noteTitle.isEmpty ? "Untitled" : noteTitle
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
                
                ForEach(folders, id: \.persistentModelID) { folder in
                    Button {
                        note.folder = folder
                        try? modelContext.save()
                        dismiss()
                    } label: {
                        HStack {
                            Label(folder.name, systemImage: "folder.fill")
                            Spacer()
                            if note.folder?.persistentModelID == folder.persistentModelID {
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
                
                // Bullet Points
                FormatButton(icon: "list.bullet", isActive: viewModel.isBulletList) {
                    viewModel.toggleBulletList()
                }
                
                FormatButton(icon: "list.number", isActive: viewModel.isNumberedList) {
                    viewModel.toggleNumberedList()
                }
                
                Divider()
                    .frame(height: 24)
                
                // Undo/Redo
                Button(action: {
                    viewModel.undo()
                }) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(viewModel.canUndo ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                        .frame(width: 44, height: 44)
                        .background(Color.clear)
                        .cornerRadius(8)
                }
                .disabled(!viewModel.canUndo)
                
                Button(action: {
                    viewModel.redo()
                }) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(viewModel.canRedo ? DesignSystem.Colors.textPrimary : DesignSystem.Colors.textTertiary)
                        .frame(width: 44, height: 44)
                        .background(Color.clear)
                        .cornerRadius(8)
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
                .foregroundColor(isActive ? .white : DesignSystem.Colors.textPrimary)
                .frame(width: 44, height: 44)
                .background(isActive ? Color.accentColor : Color.clear)
                .cornerRadius(8)
                .shadow(color: isActive ? Color.clear : DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
        }
        .disabled(false)
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
        
        // Configure undo manager with more undo levels
        textView.undoManager?.levelsOfUndo = 100
        
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
            // Handle return key for bullet/numbered list continuation
            if text == "\n" {
                let currentLine = getCurrentLine(textView: textView, at: range.location)
                
                // Check for bullet point
                if currentLine.trimmingCharacters(in: .whitespacesAndNewlines) == "•" {
                    // Remove empty bullet and exit list mode
                    let lineRange = (textView.text as NSString).lineRange(for: NSRange(location: range.location, length: 0))
                    textView.text = (textView.text as NSString).replacingCharacters(in: lineRange, with: "")
                    parent.viewModel.isBulletList = false
                    return false
                } else if currentLine.hasPrefix("• ") {
                    // Add new bullet point
                    textView.insertText("\n• ")
                    return false
                }
                
                // Check for numbered list
                if currentLine.range(of: "^(\\d+)\\. $", options: .regularExpression) != nil {
                    // Remove empty numbered item and exit list mode
                    let lineRange = (textView.text as NSString).lineRange(for: NSRange(location: range.location, length: 0))
                    textView.text = (textView.text as NSString).replacingCharacters(in: lineRange, with: "")
                    parent.viewModel.isNumberedList = false
                    return false
                } else if let match = currentLine.range(of: "^(\\d+)\\. ", options: .regularExpression) {
                    // Extract current number and increment
                    let numberStr = String(currentLine[match].dropLast(2))
                    if let currentNumber = Int(numberStr) {
                        let nextNumber = currentNumber + 1
                        textView.insertText("\n\(nextNumber). ")
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
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            // Apply to selected text
            let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
            mutableAttributedString.enumerateAttributes(in: selectedRange, options: []) { attributes, range, _ in
                var newAttributes = attributes
                if let font = attributes[.font] as? UIFont {
                    let fontDescriptor = font.fontDescriptor
                    let traits = fontDescriptor.symbolicTraits
                    let newTraits = traits.contains(.traitBold) ? traits.subtracting(.traitBold) : traits.union(.traitBold)
                    
                    if let newFontDescriptor = fontDescriptor.withSymbolicTraits(newTraits) {
                        newAttributes[.font] = UIFont(descriptor: newFontDescriptor, size: font.pointSize)
                    }
                } else {
                    // No font attribute, create one
                    var newTraits: UIFontDescriptor.SymbolicTraits = .traitBold
                    if let currentFont = textView.font {
                        newTraits = currentFont.fontDescriptor.symbolicTraits.union(.traitBold)
                    }
                    
                    if let fontDescriptor = UIFont.systemFont(ofSize: 17).fontDescriptor.withSymbolicTraits(newTraits) {
                        newAttributes[.font] = UIFont(descriptor: fontDescriptor, size: 17)
                    }
                }
                
                mutableAttributedString.setAttributes(newAttributes, range: range)
            }
            
            textView.attributedText = mutableAttributedString
            textView.selectedRange = selectedRange
        } else {
            // Apply to future typing
            boldState.toggle()
            updateTypingAttributes()
        }
        
        DispatchQueue.main.async {
            self.updateCurrentAttributes()
        }
    }
    
    func toggleItalic() {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            // Apply to selected text
            let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
            mutableAttributedString.enumerateAttributes(in: selectedRange, options: []) { attributes, range, _ in
                var newAttributes = attributes
                if let font = attributes[.font] as? UIFont {
                    let fontDescriptor = font.fontDescriptor
                    let traits = fontDescriptor.symbolicTraits
                    let newTraits = traits.contains(.traitItalic) ? traits.subtracting(.traitItalic) : traits.union(.traitItalic)
                    
                    if let newFontDescriptor = fontDescriptor.withSymbolicTraits(newTraits) {
                        newAttributes[.font] = UIFont(descriptor: newFontDescriptor, size: font.pointSize)
                    }
                } else {
                    // No font attribute, create one
                    var newTraits: UIFontDescriptor.SymbolicTraits = .traitItalic
                    if let currentFont = textView.font {
                        newTraits = currentFont.fontDescriptor.symbolicTraits.union(.traitItalic)
                    }
                    
                    if let fontDescriptor = UIFont.systemFont(ofSize: 17).fontDescriptor.withSymbolicTraits(newTraits) {
                        newAttributes[.font] = UIFont(descriptor: fontDescriptor, size: 17)
                    }
                }
                
                mutableAttributedString.setAttributes(newAttributes, range: range)
            }
            
            textView.attributedText = mutableAttributedString
            textView.selectedRange = selectedRange
        } else {
            // Apply to future typing
            italicState.toggle()
            updateTypingAttributes()
        }
        
        DispatchQueue.main.async {
            self.updateCurrentAttributes()
        }
    }
    
    func toggleUnderline() {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            // Apply to selected text
            let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
            mutableAttributedString.enumerateAttributes(in: selectedRange, options: []) { attributes, range, _ in
                var newAttributes = attributes
                let currentUnderline = (attributes[.underlineStyle] as? Int) ?? 0
                newAttributes[.underlineStyle] = currentUnderline == NSUnderlineStyle.single.rawValue ? 0 : NSUnderlineStyle.single.rawValue
                mutableAttributedString.setAttributes(newAttributes, range: range)
            }
            
            textView.attributedText = mutableAttributedString
            textView.selectedRange = selectedRange
        } else {
            // Apply to future typing
            underlineState.toggle()
            updateTypingAttributes()
        }
        
        DispatchQueue.main.async {
            self.updateCurrentAttributes()
        }
    }
    
    func toggleStrikethrough() {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            // Apply to selected text
            let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
            mutableAttributedString.enumerateAttributes(in: selectedRange, options: []) { attributes, range, _ in
                var newAttributes = attributes
                let currentStrikethrough = (attributes[.strikethroughStyle] as? Int) ?? 0
                newAttributes[.strikethroughStyle] = currentStrikethrough == NSUnderlineStyle.single.rawValue ? 0 : NSUnderlineStyle.single.rawValue
                mutableAttributedString.setAttributes(newAttributes, range: range)
            }
            
            textView.attributedText = mutableAttributedString
            textView.selectedRange = selectedRange
        } else {
            // Apply to future typing
            strikethroughState.toggle()
            updateTypingAttributes()
        }
        
        DispatchQueue.main.async {
            self.updateCurrentAttributes()
        }
    }
    
    func setFontSize(_ size: CGFloat) {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            // Apply to selected text
            let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
            mutableAttributedString.enumerateAttributes(in: selectedRange, options: []) { attributes, range, _ in
                var newAttributes = attributes
                if let font = attributes[.font] as? UIFont {
                    newAttributes[.font] = font.withSize(size)
                } else {
                    newAttributes[.font] = UIFont.systemFont(ofSize: size)
                }
                mutableAttributedString.setAttributes(newAttributes, range: range)
            }
            
            textView.attributedText = mutableAttributedString
            textView.selectedRange = selectedRange
        } else {
            // Apply to future typing
            fontSizeState = size
            updateTypingAttributes()
        }
        
        DispatchQueue.main.async {
            self.updateCurrentAttributes()
        }
    }
    
    func setTextColor(_ color: Color) {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            // Apply to selected text
            let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
            mutableAttributedString.enumerateAttributes(in: selectedRange, options: []) { attributes, range, _ in
                var newAttributes = attributes
                newAttributes[.foregroundColor] = UIColor(color)
                mutableAttributedString.setAttributes(newAttributes, range: range)
            }
            
            textView.attributedText = mutableAttributedString
            textView.selectedRange = selectedRange
        } else {
            // Apply to future typing
            textColorState = UIColor(color)
            updateTypingAttributes()
        }
        
        DispatchQueue.main.async {
            self.updateCurrentAttributes()
        }
    }
    
    func setAlignment(_ alignment: NSTextAlignment) {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if selectedRange.length > 0 {
            // Apply to selected text
            let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
            mutableAttributedString.enumerateAttributes(in: selectedRange, options: []) { attributes, range, _ in
                var newAttributes = attributes
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = alignment
                newAttributes[.paragraphStyle] = paragraphStyle
                mutableAttributedString.setAttributes(newAttributes, range: range)
            }
            
            textView.attributedText = mutableAttributedString
            textView.selectedRange = selectedRange
        } else {
            // Apply to future typing
            alignmentState = alignment
            updateTypingAttributes()
        }
        
        DispatchQueue.main.async {
            self.updateCurrentAttributes()
        }
    }
    
    func toggleBulletList() {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if isBulletList {
            // Remove bullet list
            removeListFormatting(from: textView, in: selectedRange)
            isBulletList = false
        } else {
            // Add bullet list
            applyBulletListFormatting(to: textView, in: selectedRange)
            isBulletList = true
            isNumberedList = false
        }
        
        DispatchQueue.main.async {
            self.updateCurrentAttributes()
        }
    }
    
    func toggleNumberedList() {
        guard let textView = textView else { return }
        let selectedRange = textView.selectedRange
        
        if isNumberedList {
            // Remove numbered list
            removeListFormatting(from: textView, in: selectedRange)
            isNumberedList = false
        } else {
            // Add numbered list
            applyNumberedListFormatting(to: textView, in: selectedRange)
            isNumberedList = true
            isBulletList = false
        }
        
        DispatchQueue.main.async {
            self.updateCurrentAttributes()
        }
    }
    
    private func applyBulletListFormatting(to textView: UITextView, in range: NSRange) {
        let text = textView.text as NSString
        let lineRange = text.lineRange(for: range)
        let lineText = text.substring(with: lineRange)
        
        // Check if line already has bullet
        if lineText.hasPrefix("• ") {
            return
        }
        
        // Add bullet to the beginning of the line
        let bulletText = "• " + lineText
        let newText = text.replacingCharacters(in: lineRange, with: bulletText)
        textView.text = newText
        
        // Update the attributed text
        let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
        let bulletRange = NSRange(location: lineRange.location, length: 2)
        mutableAttributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: bulletRange)
        textView.attributedText = mutableAttributedString
    }
    
    private func applyNumberedListFormatting(to textView: UITextView, in range: NSRange) {
        let text = textView.text as NSString
        let lineRange = text.lineRange(for: range)
        let lineText = text.substring(with: lineRange)
        
        // Check if line already has number
        if lineText.range(of: "^\\d+\\. ", options: .regularExpression) != nil {
            return
        }
        
        // Add number to the beginning of the line
        let numberText = "1. " + lineText
        let newText = text.replacingCharacters(in: lineRange, with: numberText)
        textView.text = newText
        
        // Update the attributed text
        let mutableAttributedString = NSMutableAttributedString(attributedString: textView.attributedText)
        let numberRange = NSRange(location: lineRange.location, length: 3)
        mutableAttributedString.addAttribute(.foregroundColor, value: UIColor.systemBlue, range: numberRange)
        textView.attributedText = mutableAttributedString
    }
    
    private func removeListFormatting(from textView: UITextView, in range: NSRange) {
        let text = textView.text as NSString
        let lineRange = text.lineRange(for: range)
        let lineText = text.substring(with: lineRange)
        
        var newLineText = lineText
        
        // Remove bullet point
        if lineText.hasPrefix("• ") {
            newLineText = String(lineText.dropFirst(2))
        }
        
        // Remove numbered list
        if let match = lineText.range(of: "^\\d+\\. ", options: .regularExpression) {
            newLineText = String(lineText[match.upperBound...])
        }
        
        if newLineText != lineText {
            let newText = text.replacingCharacters(in: lineRange, with: newLineText)
            textView.text = newText
        }
    }
    
    private func updateTypingAttributes() {
        guard let textView = textView else { return }
        
        var attributes: [NSAttributedString.Key: Any] = [:]
        
        // Font attributes
        var fontTraits: UIFontDescriptor.SymbolicTraits = []
        if boldState { fontTraits.insert(.traitBold) }
        if italicState { fontTraits.insert(.traitItalic) }
        
        if let fontDescriptor = UIFont.systemFont(ofSize: fontSizeState).fontDescriptor.withSymbolicTraits(fontTraits) {
            attributes[.font] = UIFont(descriptor: fontDescriptor, size: fontSizeState)
        } else {
            attributes[.font] = UIFont.systemFont(ofSize: fontSizeState)
        }
        
        // Color
        attributes[.foregroundColor] = textColorState
        
        // Underline
        if underlineState {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        
        // Strikethrough
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

// MARK: - Password Unlock View
struct PasswordUnlockView: View {
    let note: Note
    @Binding var isUnlocked: Bool
    @Environment(\.dismiss) var dismiss
    @StateObject private var notesManager = NotesManager()
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
                    
                    Text("Unlock Note")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Enter the password to access this note")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    if let hint = note.passwordHint, !hint.isEmpty {
                        Text("Hint: \(hint)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                
                VStack(spacing: 16) {
                    SecureField("Enter password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            unlockNote()
                        }
                    
                    Button("Unlock") {
                        unlockNote()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(password.isEmpty)
                }
                
                Spacer()
            }
            .padding(24)
            .navigationTitle("Unlock Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Incorrect Password", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func unlockNote() {
        if notesManager.verifyPassword(for: note, password: password) {
            isUnlocked = true
            dismiss()
        } else {
            errorMessage = "Incorrect password. Please try again."
            showingError = true
            password = ""
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
