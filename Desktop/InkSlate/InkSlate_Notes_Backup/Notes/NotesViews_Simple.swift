//
//  NotesViews_Simple.swift
//  InkSlate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI
import SwiftData

// MARK: - Simplified Notes List View
struct NotesListView_Simple: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [Note]
    @Query private var folders: [Folder]
    
    @State private var searchText = ""
    @State private var selectedNote: Note?
    @State private var editMode: EditMode = .inactive
    @State private var selectedForDeletion: Set<PersistentIdentifier> = []
    @State private var showingCreateFolder = false
    
    private var filteredNotes: [Note] {
        if searchText.isEmpty {
            return notes.filter { !$0.isDeleted }
        } else {
            return notes.filter { note in
                !note.isDeleted && (
                    note.title.localizedCaseInsensitiveContains(searchText) ||
                    note.attributedContent.string.localizedCaseInsensitiveContains(searchText)
                )
            }
        }
    }
    
    private var listSelection: Binding<Set<PersistentIdentifier>> {
        editMode == .active ? $selectedForDeletion : .constant(Set<PersistentIdentifier>())
    }
    
    var body: some View {
        NavigationView {
            List(selection: listSelection) {
                ForEach(filteredNotes, id: \.persistentModelID) { note in
                    NoteRowView_Simple(note: note)
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
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if editMode == .active {
                            Button("Delete") {
                                deleteSelectedNotes()
                            }
                            .disabled(selectedForDeletion.isEmpty)
                        } else {
                            Button("Edit") {
                                editMode = .active
                            }
                        }
                        
                        Button(action: {
                            let newNote = Note(title: "New Note")
                            modelContext.insert(newNote)
                            selectedNote = newNote
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedNote) { note in
            NoteDetailView_Simple(note: note)
        }
    }
    
    private func deleteNotes(offsets: IndexSet) {
        for index in offsets {
            let note = filteredNotes[index]
            note.isDeleted = true
            note.deletedDate = Date()
        }
        try? modelContext.save()
    }
    
    private func deleteSelectedNotes() {
        filteredNotes.filter { selectedForDeletion.contains($0.persistentModelID) }
            .forEach { note in
                note.isDeleted = true
                note.deletedDate = Date()
            }
        selectedForDeletion.removeAll()
        editMode = .inactive
        try? modelContext.save()
    }
}

// MARK: - Simplified Note Row View
struct NoteRowView_Simple: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title)
                .font(.headline)
                .lineLimit(1)
            
            Text(note.attributedContent.string)
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(2)
            
            Text(note.modifiedDate, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Simplified Note Detail View
struct NoteDetailView_Simple: View {
    let note: Note
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var title: String = ""
    @State private var content: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Title", text: $title)
                    .font(.title2)
                    .padding()
                
                TextEditor(text: $content)
                    .padding()
            }
            .navigationTitle("Edit Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        note.title = title
                        note.attributedContent = NSAttributedString(string: content)
                        note.modifiedDate = Date()
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            title = note.title
            content = note.attributedContent.string
        }
    }
}

#Preview {
    NotesListView_Simple()
        .modelContainer(for: [Note.self, Folder.self])
}
