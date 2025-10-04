//
//  QuotesModels.swift
//  Slate
//
//  Created by UI Overhaul on 9/29/25.
//

import SwiftUI
import SwiftData

// MARK: - Quote Data Model
@Model
class Quote {
    var text: String = ""
    var author: String = ""
    var category: String = ""
    var createdDate: Date = Date()
    
    init(text: String, author: String, category: String) {
        self.text = text
        self.author = author
        self.category = category
        self.createdDate = Date()
    }
}

// MARK: - Quote Category Enum
enum QuoteCategory: String, CaseIterable {
    case motivation = "Motivation"
    case wisdom = "Wisdom"
    case love = "Love"
    case success = "Success"
    case life = "Life"
    case humor = "Humor"
    case inspiration = "Inspiration"
    case philosophy = "Philosophy"
    
    var icon: String {
        switch self {
        case .motivation: return "flame"
        case .wisdom: return "brain.head.profile"
        case .love: return "heart"
        case .success: return "star"
        case .life: return "leaf"
        case .humor: return "face.smiling"
        case .inspiration: return "lightbulb"
        case .philosophy: return "book.closed"
        }
    }
    
    var color: Color {
        switch self {
        case .motivation: return .orange
        case .wisdom: return .purple
        case .love: return .pink
        case .success: return .yellow
        case .life: return .green
        case .humor: return .blue
        case .inspiration: return .cyan
        case .philosophy: return .brown
        }
    }
}