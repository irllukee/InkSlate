//
//  JournalPromptModels.swift
//  InkSlate
//
//  Journal prompt models and data
//

import Foundation
import SwiftData

// MARK: - Journal Prompt Model
@Model
class JournalPrompt {
    var id: String = UUID().uuidString
    var text: String = ""
    var category: String = "reflection"
    var type: String = "reflection"
    var isUsed: Bool = false
    var usedDate: Date?
    var createdAt: Date = Date()
    
    init(text: String, category: PromptCategory, type: PromptType) {
        self.text = text
        self.category = category.rawValue
        self.type = type.rawValue
    }
}

// MARK: - Prompt Categories
enum PromptCategory: String, CaseIterable {
    case personalGrowth = "Personal Growth"
    case relationships = "Relationships"
    case creative = "Creative"
    case reflection = "Reflection"
    case gratitude = "Gratitude"
    case planning = "Planning"
    
    var icon: String {
        switch self {
        case .personalGrowth: return "person.crop.circle"
        case .relationships: return "heart"
        case .creative: return "paintbrush"
        case .reflection: return "mirror"
        case .gratitude: return "star"
        case .planning: return "calendar"
        }
    }
    
    var color: String {
        switch self {
        case .personalGrowth: return "#4CAF50"
        case .relationships: return "#E91E63"
        case .creative: return "#9C27B0"
        case .reflection: return "#2196F3"
        case .gratitude: return "#FF9800"
        case .planning: return "#607D8B"
        }
    }
}

// MARK: - Prompt Types
enum PromptType: String, CaseIterable {
    case planning = "Planning"
    case reflection = "Reflection"
    
    var description: String {
        switch self {
        case .planning: return "Start your day with intention"
        case .reflection: return "Reflect on your day"
        }
    }
}

// MARK: - Prompt Data
class JournalPromptData {
    static let shared = JournalPromptData()
    
    private init() {}
    
    // Planning Prompts
    let planningPrompts = [
        "What are three things you want to accomplish today?",
        "How do you want to feel at the end of today?",
        "What's one thing you're looking forward to today?",
        "What challenge are you ready to face today?",
        "How can you show kindness to yourself today?",
        "What's one small step toward your goals you can take today?",
        "What energy do you want to bring to your interactions today?",
        "What's something new you'd like to try today?",
        "How can you make today meaningful?",
        "What's one thing you want to learn today?"
    ]
    
    // Reflection Prompts
    let reflectionPrompts = [
        "What was the best part of your day?",
        "What's one thing you learned about yourself today?",
        "How did you grow today?",
        "What made you smile today?",
        "What challenge did you overcome today?",
        "How did you show kindness today?",
        "What are you grateful for from today?",
        "What would you do differently if you could relive today?",
        "What emotion was strongest for you today?",
        "What are you proud of from today?"
    ]
    
    // Personal Growth Prompts
    let personalGrowthPrompts = [
        "What's one thing you want to improve about yourself?",
        "What limiting belief are you ready to let go of?",
        "How have you changed in the past year?",
        "What's a fear you'd like to face?",
        "What does success mean to you?",
        "What's one habit you'd like to develop?",
        "How do you want to be remembered?",
        "What's your biggest strength?",
        "What's something you've been avoiding?",
        "What would you do if you weren't afraid?"
    ]
    
    // Relationship Prompts
    let relationshipPrompts = [
        "How did you connect with someone today?",
        "What relationship in your life brings you the most joy?",
        "How can you show more love to the people you care about?",
        "What's one thing you appreciate about your closest friend?",
        "How do you want to be a better partner/friend/family member?",
        "What's a relationship you'd like to strengthen?",
        "How do you handle conflict in relationships?",
        "What's the best advice about relationships you've received?",
        "How do you show people you care about them?",
        "What's one way you can be more present with loved ones?"
    ]
    
    // Creative Prompts
    let creativePrompts = [
        "Describe your day using only colors and emotions",
        "If your day was a song, what would it sound like?",
        "Write about your day from the perspective of an object in your room",
        "What story does your day tell?",
        "If you could paint your mood right now, what would it look like?",
        "What metaphor best describes your current life situation?",
        "If your life was a movie, what genre would it be?",
        "What would your inner child want to tell you today?",
        "If you could have a conversation with your future self, what would you ask?",
        "What would you write in a letter to your past self?"
    ]
    
    // Gratitude Prompts
    let gratitudePrompts = [
        "What small moment brought you joy today?",
        "Who are you grateful for in your life right now?",
        "What's something you take for granted that you're actually grateful for?",
        "What's a challenge that made you stronger?",
        "What's something beautiful you noticed today?",
        "What's a skill or ability you're grateful to have?",
        "What's something that made you laugh today?",
        "What's a place you're grateful to have experienced?",
        "What's a lesson you're grateful to have learned?",
        "What's something about your body you're grateful for?"
    ]
    
    // Get random prompt by category and type
    func getRandomPrompt(category: PromptCategory, type: PromptType) -> String {
        let prompts: [String]
        
        switch category {
        case .personalGrowth:
            prompts = personalGrowthPrompts
        case .relationships:
            prompts = relationshipPrompts
        case .creative:
            prompts = creativePrompts
        case .gratitude:
            prompts = gratitudePrompts
        case .planning:
            prompts = type == .planning ? planningPrompts : reflectionPrompts
        case .reflection:
            prompts = type == .planning ? planningPrompts : reflectionPrompts
        }
        
        return prompts.randomElement() ?? "What's on your mind today?"
    }
    
    // Get all prompts for a category
    func getAllPrompts(for category: PromptCategory, type: PromptType) -> [String] {
        switch category {
        case .personalGrowth:
            return personalGrowthPrompts
        case .relationships:
            return relationshipPrompts
        case .creative:
            return creativePrompts
        case .gratitude:
            return gratitudePrompts
        case .planning:
            return type == .planning ? planningPrompts : reflectionPrompts
        case .reflection:
            return type == .planning ? planningPrompts : reflectionPrompts
        }
    }
}
