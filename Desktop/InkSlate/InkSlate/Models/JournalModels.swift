import Foundation
import SwiftData

@Model
class JournalBook {
    var title: String = "New Journal"
    var bookType: String = "regular" // "dream" or "regular"
    var color: String = "#8B4513" // hex color
    var createdDate: Date = Date()
    var lastWrittenDate: Date = Date.distantPast
    var isDailyJournal: Bool = false
    var currentStreak: Int = 0
    var longestStreak: Int = 0
    var lastEntryDate: Date = Date.distantPast
    @Relationship(deleteRule: .cascade)
    var entries: [JournalEntry]?
    
    init(title: String = "New Journal", bookType: String = "regular", color: String = "#8B4513", createdDate: Date = Date(), lastWrittenDate: Date? = nil, isDailyJournal: Bool = false) {
        self.title = title
        self.bookType = bookType
        self.color = color
        self.createdDate = createdDate
        self.lastWrittenDate = lastWrittenDate ?? Date.distantPast
        self.isDailyJournal = isDailyJournal
        self.currentStreak = 0
        self.longestStreak = 0
        self.lastEntryDate = Date.distantPast
        self.entries = []
    }
    
    // Computed property to check if streak should continue
    var shouldContinueStreak: Bool {
        guard isDailyJournal else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let lastEntryDay = calendar.startOfDay(for: lastEntryDate)
        let daysDifference = calendar.dateComponents([.day], from: lastEntryDay, to: today).day ?? 0
        return daysDifference <= 1
    }
    
    // Update streak when new entry is added
    func updateStreak(for entryDate: Date) {
        guard isDailyJournal else { return }
        
        let calendar = Calendar.current
        let entryDay = calendar.startOfDay(for: entryDate)
        let lastDay = calendar.startOfDay(for: lastEntryDate)
        
        if lastEntryDate == Date.distantPast {
            // First entry
            currentStreak = 1
        } else {
            let daysDifference = calendar.dateComponents([.day], from: lastDay, to: entryDay).day ?? 0
            
            if daysDifference == 1 {
                // Consecutive day
                currentStreak += 1
            } else if daysDifference == 0 {
                // Same day, don't change streak
                return
            } else {
                // Streak broken
                currentStreak = 1
            }
        }
        
        // Update longest streak
        if currentStreak > longestStreak {
            longestStreak = currentStreak
        }
        
        lastEntryDate = entryDay
        lastWrittenDate = entryDate
    }
}

@Model
class JournalEntry {
    var content: Data = Data()  // Changed from NSAttributedString
    var createdDate: Date = Date()  // Renamed from 'date'
    var moodRating: Int = 5
    var sleepQuality: Int = 5
    var bedTime: Date = Date.distantPast
    var wakeTime: Date = Date.distantPast
    var isLucidDream: Bool = false
    var dreamTags: String = ""
    var interpretationNotes: String = ""
    var photoData: Data = Data()
    var wordCount: Int = 0
    var usedPrompt: String = ""
    var promptCategory: String = ""
    @Relationship(deleteRule: .nullify, inverse: \JournalBook.entries) var book: JournalBook?
    
    init(content: NSAttributedString = NSAttributedString(string: ""), createdDate: Date = Date(), moodRating: Int = 5, sleepQuality: Int = 5, bedTime: Date? = nil, wakeTime: Date? = nil, isLucidDream: Bool = false, dreamTags: String = "", interpretationNotes: String = "", photoData: Data? = nil, book: JournalBook? = nil, wordCount: Int = 0, usedPrompt: String = "", promptCategory: String = "") {
        // Convert NSAttributedString to Data
        do {
            self.content = try content.data(from: NSRange(location: 0, length: content.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
        } catch {
            self.content = Data()
        }
        self.createdDate = createdDate
        self.moodRating = moodRating
        self.sleepQuality = sleepQuality
        self.bedTime = bedTime ?? Date.distantPast
        self.wakeTime = wakeTime ?? Date.distantPast
        self.isLucidDream = isLucidDream
        self.dreamTags = dreamTags
        self.interpretationNotes = interpretationNotes
        self.photoData = photoData ?? Data()
        self.wordCount = wordCount
        self.usedPrompt = usedPrompt
        self.promptCategory = promptCategory
        self.book = book
    }
    
    // Computed property for easy access
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
                // Update word count when content changes
                wordCount = newValue.string.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
            } catch {
                content = Data()
                wordCount = 0
            }
        }
    }
    
    // Computed property for current word count
    var currentWordCount: Int {
        return attributedContent.string.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
}

// MARK: - Dream Tags
enum DreamTag: String, CaseIterable {
    case nightmare = "Nightmare"
    case lucid = "Lucid"
    case recurring = "Recurring"
    case vivid = "Vivid"
    case flying = "Flying"
    case falling = "Falling"
    case chase = "Chase"
    case water = "Water"
    case animal = "Animal"
    case people = "People"
}
