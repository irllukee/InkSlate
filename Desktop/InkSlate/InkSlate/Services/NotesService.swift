//
//  NotesService.swift
//  InkSlate
//
//  Created by Lucas Waldron on 10/18/25.
//  Business logic service for notes operations
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Notes Service
class NotesService: ObservableObject {
    static let shared = NotesService()
    
    private let errorService = ErrorHandlingService.shared
    
    private init() {}
    
    // MARK: - Note Operations
    
    func createNote(title: String, content: String, in context: ModelContext) -> FSNote? {
        return errorService.safeSave({
            let newNote = FSNote(title: title, content: content)
            context.insert(newNote)
            try context.save()
            return newNote
        }, context: "Create note")
    }
    
    func updateNote(_ note: FSNote, in context: ModelContext) -> Bool {
        return errorService.safeSave({
            note.updatePreview()
            try context.save()
            return true
        }, context: "Update note") ?? false
    }
    
    func deleteNote(_ note: FSNote, in context: ModelContext) -> Bool {
        return errorService.safeDelete({
            context.delete(note)
            try context.save()
            return true
        }, context: "Delete note") ?? false
    }
    
    func moveToTrash(_ note: FSNote, in context: ModelContext) -> Bool {
        return errorService.safeSave({
            note.isDeleted = true
            note.deletedDate = Date()
            try context.save()
            return true
        }, context: "Move to trash") ?? false
    }
    
    func restoreNote(_ note: FSNote, in context: ModelContext) -> Bool {
        return errorService.safeSave({
            note.isDeleted = false
            note.deletedDate = nil
            try context.save()
            return true
        }, context: "Restore note") ?? false
    }
    
    func togglePin(_ note: FSNote, in context: ModelContext) -> Bool {
        return errorService.safeSave({
            note.togglePin()
            try context.save()
            return true
        }, context: "Toggle pin") ?? false
    }
    
    func emptyTrash(notes: [FSNote], in context: ModelContext) -> Bool {
        return errorService.safeDelete({
            for note in notes where note.isDeleted {
                context.delete(note)
            }
            try context.save()
            return true
        }, context: "Empty trash") ?? false
    }
    
    func purgeOldDeletedNotes(notes: [FSNote], in context: ModelContext) -> Bool {
        return errorService.safeDelete({
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
            for note in notes where note.isDeleted && (note.deletedDate ?? Date()) < cutoffDate {
                context.delete(note)
            }
            try context.save()
            return true
        }, context: "Purge old notes") ?? false
    }
    
    // MARK: - Search and Filter Operations
    
    func searchNotes(_ notes: [FSNote], searchText: String) -> [FSNote] {
        guard !searchText.isEmpty else { return notes }
        
        let searchLower = searchText.lowercased()
        return notes.filter { note in
            note.title.localizedCaseInsensitiveContains(searchLower) ||
            note.content.localizedCaseInsensitiveContains(searchLower) ||
            note.preview.localizedCaseInsensitiveContains(searchLower) ||
            note.tags.contains { $0.lowercased().contains(searchLower) }
        }
    }
    
    func filterNotes(_ notes: [FSNote], showDeleted: Bool, showPinnedOnly: Bool) -> [FSNote] {
        var filtered = notes
        
        if showDeleted {
            filtered = filtered.filter { $0.isDeleted }
        } else {
            filtered = filtered.filter { !$0.isDeleted }
        }
        
        if showPinnedOnly && !showDeleted {
            filtered = filtered.filter { $0.isPinned }
        }
        
        return filtered
    }
    
    func sortNotes(_ notes: [FSNote], by sortBy: SortBy, direction: SortDirection) -> [FSNote] {
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
        
        if direction == .descending {
            sortedNotes.reverse()
        }
        
        return sortedNotes
    }
    
    // MARK: - Tag Operations
    
    func addTag(_ tag: String, to note: FSNote, in context: ModelContext) -> Bool {
        return errorService.safeSave({
            note.addTag(tag)
            try context.save()
            return true
        }, context: "Add tag") ?? false
    }
    
    func removeTag(_ tag: String, from note: FSNote, in context: ModelContext) -> Bool {
        return errorService.safeSave({
            note.removeTag(tag)
            try context.save()
            return true
        }, context: "Remove tag") ?? false
    }
    
    // MARK: - Encryption Operations
    
    func encryptNote(_ note: FSNote, password: String, in context: ModelContext) -> Bool {
        return errorService.safeSave({
            try note.encryptContent(password: password)
            try context.save()
            return true
        }, context: "Encrypt note") ?? false
    }
    
    func decryptNote(_ note: FSNote, password: String, in context: ModelContext) -> Bool {
        return errorService.safeSave({
            _ = try note.decryptContent(password: password)
            try context.save()
            return true
        }, context: "Decrypt note") ?? false
    }
}

// MARK: - Notes View Model
class NotesViewModel: ObservableObject {
    @Published var notes: [FSNote] = []
    @Published var searchText: String = ""
    @Published var debouncedSearchText: String = ""
    @Published var sortBy: SortBy = .modificationDate
    @Published var sortDirection: SortDirection = .descending
    @Published var showPinnedOnly: Bool = false
    @Published var showDeleted: Bool = false
    @Published var isLoading: Bool = false
    
    private let notesService = NotesService.shared
    private var searchTimer: Timer?
    
    var filteredNotes: [FSNote] {
        let filtered = notesService.filterNotes(notes, showDeleted: showDeleted, showPinnedOnly: showPinnedOnly)
        let searched = notesService.searchNotes(filtered, searchText: debouncedSearchText)
        return notesService.sortNotes(searched, by: sortBy, direction: sortDirection)
    }
    
    func updateNotes(_ newNotes: [FSNote]) {
        notes = newNotes
    }
    
    func updateSearchText(_ text: String) {
        searchText = text
        searchTimer?.invalidate()
        searchTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            self?.debouncedSearchText = text
        }
    }
    
    func toggleSort() {
        sortDirection = sortDirection == .ascending ? .descending : .ascending
    }
    
    func setSortBy(_ newSortBy: SortBy) {
        sortBy = newSortBy
    }
}
