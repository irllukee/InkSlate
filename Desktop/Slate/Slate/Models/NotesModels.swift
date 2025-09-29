//
//  NotesModels.swift
//  Slate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI
import SwiftData

// MARK: - Notes Data Models

@Model
class Note {
    var id: UUID
    var title: String
    var content: Data // Stores NSAttributedString as RTF data
    var createdDate: Date
    var modifiedDate: Date
    var folder: Folder?
    
    init(title: String = "New Note", content: Data = Data(), folder: Folder? = nil) {
        self.id = UUID()
        self.title = title
        self.content = content
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.folder = folder
    }
    
    // Computed property for attributed content
    var attributedContent: NSAttributedString {
        get {
            guard !content.isEmpty else {
                return NSAttributedString(string: "")
            }
            do {
                return try NSAttributedString(data: content, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            } catch {
                return NSAttributedString(string: "")
            }
        }
        set {
            do {
                let data = try newValue.data(from: NSRange(location: 0, length: newValue.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                content = data
            } catch {
                print("Failed to save attributed string: \(error)")
            }
        }
    }
}

@Model
class Folder {
    var id: UUID
    var name: String
    var createdDate: Date
    @Relationship(deleteRule: .nullify, inverse: \Note.folder) var notes: [Note] = []
    
    init(name: String) {
        self.id = UUID()
        self.name = name
        self.createdDate = Date()
    }
}

// MARK: - Notes Manager (replaces the Core Data version)
class NotesManager: ObservableObject {
    @Published var selectedFolder: Folder?
    
    func createNote(in folder: Folder? = nil, with modelContext: ModelContext) -> Note {
        let note = Note(title: "New Note", folder: folder ?? selectedFolder)
        note.attributedContent = NSAttributedString(string: "")
        modelContext.insert(note)
        try? modelContext.save()
        return note
    }
    
    func createFolder(name: String, with modelContext: ModelContext) {
        let folder = Folder(name: name)
        modelContext.insert(folder)
        try? modelContext.save()
    }
    
    func deleteNote(_ note: Note, with modelContext: ModelContext) {
        modelContext.delete(note)
        try? modelContext.save()
    }
    
    func saveNote(_ note: Note, with modelContext: ModelContext) {
        note.modifiedDate = Date()
        try? modelContext.save()
    }
}
