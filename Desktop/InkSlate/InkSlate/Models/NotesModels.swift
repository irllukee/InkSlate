//
//  NotesModels.swift
//  InkSlate
//
//  Created by Lucas Waldron on 10/18/25.
//  Based on FSNotes structure
//  FIXED: Added proper ID field for encryption keychain storage

import SwiftUI
import SwiftData
import Foundation

// MARK: - Notes Data Models (FSNotes-inspired)

@Model
class FSNote {
    @Attribute(.unique) var id: UUID?
    var title: String = ""
    var content: String = ""
    var preview: String = ""
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var isPinned: Bool = false
    var isEncrypted: Bool = false
    var containerType: NoteContainer = NoteContainer.none
    var noteType: NoteType = NoteType.markdown
    var tags: [String] = []
    var attachments: [String] = [] // URLs as strings
    var imageUrls: [String] = [] // Image URLs as strings
    var selectedRange: String = "" // NSRange as string
    var fileName: String = ""
    var originalExtension: String = ""
    var isBlocked: Bool = false
    var isParsed: Bool = false
    var modifiedLocalAt: Date = Date()
    var project: FSProject?
    var isDeleted: Bool = false
    var deletedDate: Date? = nil
    
    init(title: String = "", content: String = "", project: FSProject? = nil) {
        self.id = UUID()
        self.title = title.isEmpty ? "New Note" : title
        self.content = content
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.project = project
        self.fileName = title.isEmpty ? "New_Note" : title.replacingOccurrences(of: " ", with: "_")
        self.originalExtension = noteType.fileExtension
        self.preview = generatePreview(from: content)
    }
    
    // Generate preview from content (first 200 characters) - OPTIMIZED
    private func generatePreview(from content: String) -> String {
        // Early return for empty content
        guard !content.isEmpty else { return "" }
        
        // Use regex for more efficient markdown removal
        let markdownPatterns = [
            "#+\\s*",           // Headers
            "\\*\\*([^*]+)\\*\\*", // Bold
            "\\*([^*]+)\\*",    // Italic
            "`([^`]+)`",        // Inline code
            "~~([^~]+)~~",      // Strikethrough
            "\\[([^\\]]+)\\]\\([^\\)]+\\)", // Links
            ">\\s*",            // Blockquotes
            "```[\\s\\S]*?```"  // Code blocks
        ]
        
        var cleanContent = content
        for pattern in markdownPatterns {
            cleanContent = cleanContent.replacingOccurrences(of: pattern, with: "$1", options: .regularExpression)
        }
        
        // Clean up extra whitespace
        cleanContent = cleanContent
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return String(cleanContent.prefix(200))
    }
    
    // Update preview when content changes - OPTIMIZED
    func updatePreview() {
        // Update preview immediately for better responsiveness
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let newPreview = self.generatePreview(from: self.content)
            
            DispatchQueue.main.async {
                self.preview = newPreview
                self.modifiedDate = Date()
                self.modifiedLocalAt = Date()
            }
        }
    }
    
    // Add tag to note
    func addTag(_ tag: String) {
        if !tags.contains(tag) {
            tags.append(tag)
            modifiedDate = Date()
        }
    }
    
    // Remove tag from note
    func removeTag(_ tag: String) {
        tags.removeAll { $0 == tag }
        modifiedDate = Date()
    }
    
    // Toggle pin status
    func togglePin() {
        isPinned.toggle()
        modifiedDate = Date()
    }
    
    // Encrypt content with password (note: actual encryption happens in EncryptionService)
    func encryptContent(password: String) throws {
        guard !content.isEmpty else { return }
        let encryptedData = try EncryptionService.shared.encrypt(data: content.data(using: .utf8)!, password: password)
        self.content = encryptedData.base64EncodedString()
        self.isEncrypted = true
        self.containerType = .encryptedTextPack
        self.modifiedDate = Date()
    }
    
    // Decrypt content with password (note: actual decryption happens in EncryptionService)
    func decryptContent(password: String) throws -> String {
        guard isEncrypted, let data = Data(base64Encoded: content) else { return content }
        let decryptedData = try EncryptionService.shared.decrypt(data: data, password: password)
        let decryptedString = String(data: decryptedData, encoding: .utf8) ?? ""
        self.content = decryptedString
        self.isEncrypted = false
        self.containerType = .none
        self.modifiedDate = Date()
        return decryptedString
    }
    
    // Encrypt note with password
    func encrypt(with password: String) throws {
        try encryptContent(password: password)
    }
    
    // Decrypt note with password
    func decrypt(with password: String) throws {
        _ = try decryptContent(password: password)
    }
}

@Model
class FSProject {
    @Attribute(.unique) var id: UUID?
    var name: String = "New Project"
    var path: String = ""
    var createdDate: Date = Date()
    var isDefault: Bool = false
    var settings: ProjectSettings?
    @Relationship(deleteRule: .cascade) var notes: [FSNote]? = []
    
    init(name: String = "New Project", path: String = "", isDefault: Bool = false) {
        self.id = UUID()
        self.name = name
        self.path = path
        self.createdDate = Date()
        self.isDefault = isDefault
    }
}

@Model
class ProjectSettings {
    @Attribute(.unique) var id: UUID?
    var sortBy: SortBy = SortBy.modificationDate
    var sortDirection: SortDirection = SortDirection.descending
    var showInSidebar: Bool = true
    var isEncrypted: Bool = false
    var gitRepository: String = ""
    var createdDate: Date = Date()
    
    init(sortBy: SortBy = .modificationDate, sortDirection: SortDirection = .descending) {
        self.id = UUID()
        self.sortBy = sortBy
        self.sortDirection = sortDirection
        self.createdDate = Date()
    }
}

@Model
class FSTag {
    @Attribute(.unique) var id: UUID?
    var name: String = ""
    var fullName: String = ""
    var parentTag: FSTag?
    var createdDate: Date = Date()
    @Relationship(deleteRule: .nullify) var notes: [FSNote]? = []
    
    init(name: String, parentTag: FSTag? = nil) {
        self.id = UUID()
        self.name = name
        self.parentTag = parentTag
        self.createdDate = Date()
        self.fullName = generateFullName()
    }
    
    private func generateFullName() -> String {
        if let parent = parentTag, !parent.fullName.isEmpty {
            return "\(parent.fullName)/\(name)"
        }
        return name
    }
    
    func updateFullName() {
        self.fullName = generateFullName()
    }
}

// MARK: - Enums

enum NoteContainer: Int, Codable {
    case none = 1
    case textBundle = 2
    case textBundleV2 = 3
    case encryptedTextPack = 4
    
    var uti: String {
        switch self {
        case .textBundle: return "com.apple.package"
        case .textBundleV2: return "com.apple.package"
        case .encryptedTextPack: return "es.fsnot.etp.package"
        case .none: return ""
        }
    }
}

enum SortBy: String, Codable, CaseIterable {
    case title = "title"
    case creationDate = "creationDate"
    case modificationDate = "modificationDate"
    case pin = "pin"
    
    var displayName: String {
        switch self {
        case .title: return "Title"
        case .creationDate: return "Creation Date"
        case .modificationDate: return "Modification Date"
        case .pin: return "Pin Status"
        }
    }
}

enum SortDirection: String, Codable, CaseIterable {
    case ascending = "ascending"
    case descending = "descending"
    
    var displayName: String {
        switch self {
        case .ascending: return "Ascending"
        case .descending: return "Descending"
        }
    }
}

// MARK: - Notes Manager

class FSNotesManager: ObservableObject {
    static let shared = FSNotesManager()
    
    @Published var selectedProject: FSProject?
    @Published var selectedTag: FSTag?
    @Published var searchText: String = ""
    @Published var sortBy: SortBy = .modificationDate
    @Published var sortDirection: SortDirection = .descending
    @Published var showPinnedOnly: Bool = false
    
    private init() {}
    
    func createNote(in project: FSProject? = nil, with modelContext: ModelContext) -> FSNote {
        let note = FSNote(project: project ?? selectedProject)
        modelContext.insert(note)
        try? modelContext.save()
        return note
    }
    
    func createProject(name: String, with modelContext: ModelContext) -> FSProject {
        let project = FSProject(name: name)
        modelContext.insert(project)
        try? modelContext.save()
        return project
    }
    
    func createTag(name: String, parentTag: FSTag? = nil, with modelContext: ModelContext) -> FSTag {
        let tag = FSTag(name: name, parentTag: parentTag)
        modelContext.insert(tag)
        try? modelContext.save()
        return tag
    }

    func deleteNote(_ note: FSNote, with modelContext: ModelContext) {
        modelContext.delete(note)
        try? modelContext.save()
    }
    
    func deleteProject(_ project: FSProject, with modelContext: ModelContext) {
        modelContext.delete(project)
        try? modelContext.save()
    }
    
    func deleteTag(_ tag: FSTag, with modelContext: ModelContext) {
        modelContext.delete(tag)
        try? modelContext.save()
    }
    
    // Search functionality
    func searchNotes(notes: [FSNote], searchText: String) -> [FSNote] {
        guard !searchText.isEmpty else { return notes }
        
        let searchLower = searchText.lowercased()
        return notes.filter { note in
            note.title.lowercased().contains(searchLower) ||
            note.content.lowercased().contains(searchLower) ||
            note.preview.lowercased().contains(searchLower) ||
            note.tags.contains { $0.lowercased().contains(searchLower) }
        }
    }
    
    // Sort functionality
    func sortNotes(_ notes: [FSNote]) -> [FSNote] {
        var sortedNotes = notes
        
        switch sortBy {
        case .title:
            sortedNotes.sort { $0.title < $1.title }
        case .creationDate:
            sortedNotes.sort { $0.createdDate < $1.createdDate }
        case .modificationDate:
            sortedNotes.sort { $0.modifiedDate < $1.modifiedDate }
        case .pin:
            sortedNotes.sort { $0.isPinned && !$1.isPinned }
        }
        
        if sortDirection == .descending {
            sortedNotes.reverse()
        }
        
        return sortedNotes
    }
    
    // Filter functionality
    func filterNotes(_ notes: [FSNote]) -> [FSNote] {
        var filteredNotes = notes
        
        if showPinnedOnly {
            filteredNotes = filteredNotes.filter { $0.isPinned }
        }
        
        if let selectedTag = selectedTag {
            filteredNotes = filteredNotes.filter { note in
                note.tags.contains(selectedTag.name) || note.tags.contains(selectedTag.fullName)
            }
        }
        
        return filteredNotes
    }
}

// MARK: - NoteType Enum
public enum NoteType: Int, Codable, CaseIterable, Identifiable {
    public var id: Self { self }
    case markdown = 0x01
    case richText = 0x02
    case plainText = 0x03
    
    public var fileExtension: String {
        switch self {
        case .markdown:
            return "md"
        case .richText:
            return "rtf"
        case .plainText:
            return "txt"
        }
    }
}

