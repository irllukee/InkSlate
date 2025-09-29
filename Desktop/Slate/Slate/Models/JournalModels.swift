import Foundation
import SwiftData
import UIKit

@Model
class JournalBook {
    var id: UUID = UUID()
    var title: String = "New Journal"
    var bookType: String = "regular" // "dream" or "regular"
    var color: String = "#8B4513" // hex color
    var createdDate: Date = Date()
    var lastWrittenDate: Date?
    @Relationship(deleteRule: .cascade, inverse: \JournalEntry.book)
    var entries: [JournalEntry]?
    
    init(title: String = "New Journal", bookType: String = "regular", color: String = "#8B4513", createdDate: Date = Date(), lastWrittenDate: Date? = nil) {
        self.title = title
        self.bookType = bookType
        self.color = color
        self.createdDate = createdDate
        self.lastWrittenDate = lastWrittenDate
        self.entries = []
    }
}

@Model
class JournalEntry {
    var id: UUID = UUID()
    @Attribute(.transformable(by: "NSAttributedStringTransformer"))
    var content: NSAttributedString = NSAttributedString(string: "")
    var date: Date = Date()
    var moodRating: Int = 5
    var sleepQuality: Int = 5
    var bedTime: Date?
    var wakeTime: Date?
    var isLucidDream: Bool = false
    var dreamTags: String = ""
    var interpretationNotes: String = ""
    var photoData: Data?
    @Relationship var book: JournalBook?
    
    init(content: NSAttributedString = NSAttributedString(string: ""), date: Date = Date(), moodRating: Int = 5, sleepQuality: Int = 5, bedTime: Date? = nil, wakeTime: Date? = nil, isLucidDream: Bool = false, dreamTags: String = "", interpretationNotes: String = "", photoData: Data? = nil, book: JournalBook? = nil) {
        self.content = content
        self.date = date
        self.moodRating = moodRating
        self.sleepQuality = sleepQuality
        self.bedTime = bedTime
        self.wakeTime = wakeTime
        self.isLucidDream = isLucidDream
        self.dreamTags = dreamTags
        self.interpretationNotes = interpretationNotes
        self.photoData = photoData
        self.book = book
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
