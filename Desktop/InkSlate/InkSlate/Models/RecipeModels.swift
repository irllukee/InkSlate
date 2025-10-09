//
//  RecipeModels.swift
//  InkSlate
//
//  Created by UI Overhaul on 9/29/25.
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Recipe Data Models
@Model
class Recipe {
    var name: String = ""
    var instructions: String = ""
    var isFavorite: Bool = false
    var category: String = ""
    var createdDate: Date = Date()
    @Relationship(deleteRule: .cascade) var ingredients: [RecipeIngredient]? = []
    var imageData: Data = Data()
    var servings: String = ""
    var cookingTime: String = ""
    var difficulty: String = ""
    
    init(name: String, instructions: String, category: String, isFavorite: Bool = false) {
        self.name = name
        self.instructions = instructions
        self.category = category
        self.isFavorite = isFavorite
        self.createdDate = Date()
    }
    
    var image: Image? {
        guard !imageData.isEmpty,
              let uiImage = UIImage(data: imageData) else { return nil }
        return Image(uiImage: uiImage)
    }
}

@Model
class RecipeIngredient {
    var quantity: String = ""
    var item: String = ""
    @Relationship(deleteRule: .nullify) var recipe: Recipe?
    
    init(quantity: String = "", item: String = "") {
        self.quantity = quantity
        self.item = item
    }
}

@Model
class FridgeItem {
    var name: String = ""
    var quantity: String = ""
    var createdDate: Date = Date()
    
    init(name: String, quantity: String) {
        self.name = name
        self.quantity = quantity
        self.createdDate = Date()
    }
}

@Model
class SpiceItem {
    var name: String = ""
    var quantity: String = ""
    var createdDate: Date = Date()
    
    init(name: String, quantity: String) {
        self.name = name
        self.quantity = quantity
        self.createdDate = Date()
    }
}

@Model
class CartItem {
    var name: String = ""
    var quantity: String = ""
    var isPurchased: Bool = false
    var createdDate: Date = Date()
    
    init(name: String, quantity: String, isPurchased: Bool = false) {
        self.name = name
        self.quantity = quantity
        self.isPurchased = isPurchased
        self.createdDate = Date()
    }
}

// MARK: - Recipe Category Enum
enum RecipeCategory: String, CaseIterable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case appetizers = "Appetizers"
    case drinks = "Drinks"
    case desserts = "Desserts"
    case snacks = "Snacks"
    case sides = "Sides"
    
    var icon: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon"
        case .appetizers: return "fork.knife"
        case .drinks: return "cup.and.saucer"
        case .desserts: return "birthday.cake"
        case .snacks: return "popcorn"
        case .sides: return "leaf"
        }
    }
    
    var color: Color {
        switch self {
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .blue
        case .appetizers: return .green
        case .drinks: return .cyan
        case .desserts: return .pink
        case .snacks: return .purple
        case .sides: return .mint
        }
    }
}