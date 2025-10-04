//
//  NotesModels.swift
//  Slate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI
import SwiftData
import CryptoKit

// MARK: - Notes Data Models

@Model
class Note {
    var title: String
    var content: Data // Stores NSAttributedString as RTF data
    var createdDate: Date
    var modifiedDate: Date
    @Relationship(deleteRule: .nullify) var folder: Folder?
    var isPasswordProtected: Bool
    var passwordHash: String? // Stores hashed password
    var passwordSalt: String? // Stores salt for password hashing
    var passwordHint: String? // Optional hint for the password
    var isDeleted: Bool
    var deletedDate: Date?
    
    init(title: String = "New Note", content: Data = Data(), folder: Folder? = nil, isPasswordProtected: Bool = false, passwordHash: String? = nil, passwordSalt: String? = nil, passwordHint: String? = nil) {
        // Ensure title is never nil or empty
        self.title = title.isEmpty ? "New Note" : title
        self.content = content
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.folder = folder
        self.isPasswordProtected = isPasswordProtected
        self.passwordHash = passwordHash
        self.passwordSalt = passwordSalt
        self.passwordHint = passwordHint
        self.isDeleted = false
        self.deletedDate = nil
    }
    
    // Computed property to safely get title, ensuring it's never nil
    var safeTitle: String {
        return title.isEmpty ? "Untitled" : title
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
    var name: String = "New Folder"
    var createdDate: Date = Date()
    @Relationship(deleteRule: .cascade, inverse: \Note.folder) var notes: [Note] = []
    
    init(name: String = "New Folder") {
        self.name = name
    }
}

// MARK: - Notes Manager (replaces the Core Data version)
class NotesManager: ObservableObject {
    @Published var selectedFolder: Folder?
    @Published var showingTrash: Bool = false
    
    func createNote(in folder: Folder? = nil, with modelContext: ModelContext) -> Note {
        let note = Note(title: "New Note", folder: folder ?? selectedFolder)
        note.attributedContent = NSAttributedString(string: "")
        modelContext.insert(note)
        try? modelContext.save()
        return note
    }
    
    // Migration helper to fix any existing notes with nil or empty titles
    func migrateNotesIfNeeded(with modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Note>()
        do {
            let notes = try modelContext.fetch(descriptor)
            for note in notes {
                if note.title.isEmpty {
                    note.title = "Untitled Note"
                    note.modifiedDate = Date()
                }
            }
            try modelContext.save()
        } catch {
            print("Failed to migrate notes: \(error)")
        }
    }
    
    func createFolder(name: String, with modelContext: ModelContext) {
        let folder = Folder(name: name)
        modelContext.insert(folder)
        try? modelContext.save()
    }
    
    func deleteNote(_ note: Note, with modelContext: ModelContext) {
        note.isDeleted = true
        note.deletedDate = Date()
        try? modelContext.save()
    }

    func restoreNote(_ note: Note, with modelContext: ModelContext) {
        note.isDeleted = false
        note.deletedDate = nil
        try? modelContext.save()
    }

    func permanentlyDelete(_ note: Note, with modelContext: ModelContext) {
        modelContext.delete(note)
        try? modelContext.save()
    }
    
    // MARK: - Password Protection Methods
    func setPassword(for note: Note, password: String, hint: String?) {
        note.isPasswordProtected = true
        let salt = generateSalt()
        note.passwordSalt = salt
        note.passwordHash = hashPassword(password, salt: salt)
        note.passwordHint = hint
    }
    
    func removePassword(from note: Note) {
        note.isPasswordProtected = false
        note.passwordHash = nil
        note.passwordSalt = nil
        note.passwordHint = nil
    }
    
    func verifyPassword(for note: Note, password: String) -> Bool {
        guard let storedHash = note.passwordHash,
              let salt = note.passwordSalt else { return false }
        
        let inputHash = hashPassword(password, salt: salt)
        return secureCompare(storedHash, inputHash)
    }
    
    private func generateSalt() -> String {
        let saltData = Data((0..<32).map { _ in UInt8.random(in: 0...255) })
        return saltData.base64EncodedString()
    }
    
    private func hashPassword(_ password: String, salt: String) -> String {
        guard let saltData = Data(base64Encoded: salt),
              let passwordData = password.data(using: .utf8) else {
            return ""
        }
        
        // Combine password and salt
        var combinedData = passwordData
        combinedData.append(saltData)
        
        // Hash using SHA-256
        let hashedData = SHA256.hash(data: combinedData)
        return Data(hashedData).base64EncodedString()
    }
    
    private func secureCompare(_ a: String, _ b: String) -> Bool {
        guard a.count == b.count else { return false }
        
        var result: UInt8 = 0
        for (byteA, byteB) in zip(a.utf8, b.utf8) {
            result |= byteA ^ byteB
        }
        return result == 0
    }
    
    func saveNote(_ note: Note, with modelContext: ModelContext) {
        note.modifiedDate = Date()
        try? modelContext.save()
    }
}
