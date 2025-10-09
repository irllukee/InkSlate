//
//  BudgetModels.swift
//  InkSlate
//
//  Created by Lucas Waldron on 1/2/25.
//

import Foundation
import SwiftData

// MARK: - Double Extension for NaN Safety
extension Double {
    /// Returns the value if it's valid (not NaN or infinite), otherwise returns the fallback
    func safeValue(fallback: Double = 0.0) -> Double {
        if self.isNaN || self.isInfinite {
            return fallback
        }
        return self
    }
}

// MARK: - Budget Data Models

@Model
class BudgetCategory {
    var name: String = ""
    var icon: String = "dollarsign.circle"
    var color: String = "#8B4513" // hex color
    var createdDate: Date = Date()
    var isDefault: Bool = false
    var sortOrder: Int = 0
    @Relationship(deleteRule: .cascade)
    var subcategories: [BudgetSubcategory]?
    @Relationship(deleteRule: .cascade)
    var budgetItems: [BudgetItem]?
    
    init(name: String, icon: String = "dollarsign.circle", color: String = "#8B4513", isDefault: Bool = false, sortOrder: Int = 0) {
        self.name = name
        self.icon = icon
        self.color = color
        self.createdDate = Date()
        self.isDefault = isDefault
        self.sortOrder = sortOrder
        self.subcategories = []
        self.budgetItems = []
    }
}

@Model
class BudgetSubcategory {
    var name: String = ""
    var icon: String = "circle.fill"
    var createdDate: Date = Date()
    var sortOrder: Int = 0
    @Relationship(deleteRule: .nullify, inverse: \BudgetCategory.subcategories) var category: BudgetCategory?
    @Relationship(deleteRule: .cascade) var budgetItems: [BudgetItem]?
    
    init(name: String, icon: String = "circle.fill", sortOrder: Int = 0, category: BudgetCategory? = nil) {
        self.name = name
        self.icon = icon
        self.createdDate = Date()
        self.sortOrder = sortOrder
        self.category = category
        self.budgetItems = []
    }
}

@Model
class BudgetItem {
    var name: String = ""
    var amount: Double = 0.0
    var budgetAmount: Double = 0.0
    var date: Date = Date()
    var createdDate: Date = Date()
    var modifiedDate: Date = Date()
    var notes: String = ""
    var isIncome: Bool = false
    var isRecurring: Bool = false
    var recurringFrequency: String = "monthly" // daily, weekly, monthly, yearly
    var isDeleted: Bool = false
    var deletedDate: Date = Date.distantPast
    @Relationship(deleteRule: .nullify, inverse: \BudgetCategory.budgetItems) var category: BudgetCategory?
    @Relationship(deleteRule: .nullify, inverse: \BudgetSubcategory.budgetItems) var subcategory: BudgetSubcategory?
    
    init(name: String, amount: Double, budgetAmount: Double = 0.0, date: Date = Date(), notes: String = "", isIncome: Bool = false, isRecurring: Bool = false, recurringFrequency: String = "monthly", category: BudgetCategory? = nil, subcategory: BudgetSubcategory? = nil) {
        self.name = name
        self.amount = amount
        self.budgetAmount = budgetAmount
        self.date = date
        self.createdDate = Date()
        self.modifiedDate = Date()
        self.notes = notes
        self.isIncome = isIncome
        self.isRecurring = isRecurring
        self.recurringFrequency = recurringFrequency
        self.isDeleted = false
        self.deletedDate = Date.distantPast
        self.category = category
        self.subcategory = subcategory
    }
    
    // Computed property for current balance
    var balance: Double {
        return budgetAmount - amount
    }
    
    // Computed property for balance percentage
    var balancePercentage: Double {
        guard budgetAmount > 0 else { return 0 }
        let percentage = (amount / budgetAmount) * 100
        return percentage.safeValue(fallback: 0)
    }
    
    // Computed property for balance status
    var balanceStatus: BalanceStatus {
        if amount <= budgetAmount {
            return .underBudget
        } else if amount <= budgetAmount * 1.1 { // 10% over
            return .closeToLimit
        } else {
            return .overBudget
        }
    }
}

// MARK: - Budget Enums
enum BalanceStatus {
    case underBudget
    case closeToLimit
    case overBudget
    
    var color: String {
        switch self {
        case .underBudget: return "#4CAF50" // Green
        case .closeToLimit: return "#FF9800" // Orange
        case .overBudget: return "#F44336" // Red
        }
    }
    
    var icon: String {
        switch self {
        case .underBudget: return "checkmark.circle.fill"
        case .closeToLimit: return "exclamationmark.triangle.fill"
        case .overBudget: return "xmark.circle.fill"
        }
    }
}

enum RecurringFrequency: String, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    
    var displayName: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        }
    }
}

// MARK: - Budget Manager
class BudgetManager: ObservableObject {
    static let shared = BudgetManager()
    
    @Published var selectedCategory: BudgetCategory?
    @Published var selectedSubcategory: BudgetSubcategory?
    @Published var showingTrash: Bool = false
    @Published var currentPeriod: Date = Date()
    
    func createBudgetItem(name: String, amount: Double, budgetAmount: Double = 0.0, date: Date = Date(), notes: String = "", isIncome: Bool = false, isRecurring: Bool = false, recurringFrequency: String = "monthly", category: BudgetCategory? = nil, subcategory: BudgetSubcategory? = nil, with modelContext: ModelContext) -> BudgetItem {
        let budgetItem = BudgetItem(name: name, amount: amount, budgetAmount: budgetAmount, date: date, notes: notes, isIncome: isIncome, isRecurring: isRecurring, recurringFrequency: recurringFrequency, category: category, subcategory: subcategory)
        modelContext.insert(budgetItem)
        try? modelContext.save()
        return budgetItem
    }
    
    func createCategory(name: String, icon: String = "dollarsign.circle", color: String = "#8B4513", isDefault: Bool = false, with modelContext: ModelContext) -> BudgetCategory {
        let category = BudgetCategory(name: name, icon: icon, color: color, isDefault: isDefault)
        modelContext.insert(category)
        try? modelContext.save()
        return category
    }
    
    func createSubcategory(name: String, icon: String = "circle.fill", category: BudgetCategory?, with modelContext: ModelContext) -> BudgetSubcategory {
        let subcategory = BudgetSubcategory(name: name, icon: icon, category: category)
        modelContext.insert(subcategory)
        try? modelContext.save()
        return subcategory
    }
    
    func deleteBudgetItem(_ budgetItem: BudgetItem, with modelContext: ModelContext) {
        budgetItem.isDeleted = true
        budgetItem.deletedDate = Date()
        try? modelContext.save()
    }
    
    func restoreBudgetItem(_ budgetItem: BudgetItem, with modelContext: ModelContext) {
        budgetItem.isDeleted = false
        budgetItem.deletedDate = Date.distantPast
        try? modelContext.save()
    }
    
    func permanentlyDelete(_ budgetItem: BudgetItem, with modelContext: ModelContext) {
        modelContext.delete(budgetItem)
        try? modelContext.save()
    }
    
    // Auto-cleanup expired items (30 days)
    func cleanupExpiredItems(with modelContext: ModelContext) {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let descriptor = FetchDescriptor<BudgetItem>(
            predicate: #Predicate<BudgetItem> { item in
                item.isDeleted == true && item.deletedDate < thirtyDaysAgo
            }
        )
        
        do {
            let expiredItems = try modelContext.fetch(descriptor)
            for item in expiredItems {
                modelContext.delete(item)
            }
            if !expiredItems.isEmpty {
                try modelContext.save()
            }
        } catch {
            // Handle cleanup error silently
        }
    }
    
    func saveBudgetItem(_ budgetItem: BudgetItem, with modelContext: ModelContext) {
        budgetItem.modifiedDate = Date()
        try? modelContext.save()
    }
    
    // Calculate total budget for a category
    func calculateTotalBudget(for category: BudgetCategory, in period: Date = Date()) -> Double {
        guard let items = category.budgetItems else { return 0.0 }
        
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: period)?.start ?? period
        let monthEnd = calendar.dateInterval(of: .month, for: period)?.end ?? period
        
        return items.filter { item in
            !item.isDeleted && 
            item.date >= monthStart && 
            item.date < monthEnd
        }.reduce(0.0) { total, item in
            total + item.budgetAmount
        }
    }
    
    // Calculate total spent for a category
    func calculateTotalSpent(for category: BudgetCategory, in period: Date = Date()) -> Double {
        guard let items = category.budgetItems else { return 0.0 }
        
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: period)?.start ?? period
        let monthEnd = calendar.dateInterval(of: .month, for: period)?.end ?? period
        
        return items.filter { item in
            !item.isDeleted && 
            item.date >= monthStart && 
            item.date < monthEnd &&
            !item.isIncome
        }.reduce(0.0) { total, item in
            total + item.amount
        }
    }
    
    // Calculate total income for a category
    func calculateTotalIncome(for category: BudgetCategory, in period: Date = Date()) -> Double {
        guard let items = category.budgetItems else { return 0.0 }
        
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: period)?.start ?? period
        let monthEnd = calendar.dateInterval(of: .month, for: period)?.end ?? period
        
        return items.filter { item in
            !item.isDeleted && 
            item.date >= monthStart && 
            item.date < monthEnd &&
            item.isIncome
        }.reduce(0.0) { total, item in
            total + item.amount
        }
    }
    
    // Initialize default categories
    func initializeDefaultCategories(with modelContext: ModelContext) {
        let defaultCategories = [
            ("🏠 Housing & Utilities", "house.fill", "#2196F3"),
            ("🚗 Transportation", "car.fill", "#FF9800"),
            ("🛍️ Daily Living & Household", "cart.fill", "#4CAF50"),
            ("🍽️ Food & Leisure", "fork.knife", "#E91E63"),
            ("💵 Financial Obligations", "banknote.fill", "#9C27B0"),
            ("🧠 Education & Personal Growth", "graduationcap.fill", "#3F51B5"),
            ("🩺 Health & Wellness", "cross.fill", "#F44336"),
            ("🎁 Gifts & Giving", "gift.fill", "#FF5722"),
            ("📝 Miscellaneous", "ellipsis.circle.fill", "#607D8B")
        ]
        
        for (index, (name, icon, color)) in defaultCategories.enumerated() {
            let category = BudgetCategory(name: name, icon: icon, color: color, isDefault: true, sortOrder: index)
            modelContext.insert(category)
        }
        
        try? modelContext.save()
    }
    
    // Set budget amount for a category
    func setBudgetAmount(for category: BudgetCategory, amount: Double, in period: Date, with modelContext: ModelContext) {
        // Find existing budget item for this category and period
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: period)?.start ?? period
        let monthEnd = calendar.dateInterval(of: .month, for: period)?.end ?? period
        
        let budgetName = "\(category.name) Budget"
        
        // Use a simpler approach - fetch all items for this category and filter manually
        guard let items = category.budgetItems else {
            // Create new budget item if no items exist
            let budgetItem = BudgetItem(
                name: budgetName,
                amount: amount,
                budgetAmount: amount,
                date: period,
                category: category
            )
            modelContext.insert(budgetItem)
            try? modelContext.save()
            return
        }
        
        let budgetItems = items.filter { item in
            item.name == budgetName &&
            item.date >= monthStart &&
            item.date < monthEnd &&
            !item.isDeleted
        }
        
        if let existingItem = budgetItems.first {
            // Update existing budget item
            existingItem.budgetAmount = amount
            existingItem.amount = amount
            existingItem.modifiedDate = Date()
        } else {
            // Create new budget item
            let budgetItem = BudgetItem(
                name: budgetName,
                amount: amount,
                budgetAmount: amount,
                date: period,
                category: category
            )
            modelContext.insert(budgetItem)
        }
        
        try? modelContext.save()
    }
    
    // Get budget amount for a category
    func getBudgetAmount(for category: BudgetCategory, in period: Date) -> Double {
        let calendar = Calendar.current
        let monthStart = calendar.dateInterval(of: .month, for: period)?.start ?? period
        let monthEnd = calendar.dateInterval(of: .month, for: period)?.end ?? period
        
        guard let items = category.budgetItems else { return 0.0 }
        
        let budgetName = "\(category.name) Budget"
        
        let budgetItems = items.filter { item in
            item.name == budgetName &&
            item.date >= monthStart &&
            item.date < monthEnd &&
            !item.isDeleted
        }
        
        return budgetItems.first?.budgetAmount ?? 0.0
    }
}
