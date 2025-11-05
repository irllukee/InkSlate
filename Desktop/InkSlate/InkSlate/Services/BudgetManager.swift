//
//  BudgetManager.swift
//  InkSlate
//
//  Created by Lucas Waldron on 1/2/25.
//

import Foundation
import CoreData
import SwiftUI

class BudgetManager: ObservableObject {
    static let shared = BudgetManager()
    
    private init() {}
    
    // MARK: - Category Management
    
    func createCategory(name: String, icon: String, color: String, with context: NSManagedObjectContext) -> BudgetCategory {
        let category = BudgetCategory(context: context)
        category.name = name
        category.icon = icon
        category.color = color
        category.sortOrder = Int16(getNextSortOrder(for: context))
        category.createdDate = Date()
        category.modifiedDate = Date()
        
        context.insert(category)
        saveContext(context)
        return category
    }
    
    func createSubcategory(name: String, category: BudgetCategory, with context: NSManagedObjectContext) -> BudgetSubcategory {
        let subcategory = BudgetSubcategory(context: context)
        subcategory.name = name
        subcategory.category = category
        subcategory.createdDate = Date()
        subcategory.modifiedDate = Date()
        
        context.insert(subcategory)
        saveContext(context)
        return subcategory
    }
    
    func deleteCategory(_ category: BudgetCategory, with context: NSManagedObjectContext) {
        context.delete(category)
        saveContext(context)
    }
    
    // MARK: - Budget Item Management
    
    func createBudgetItem(name: String, amount: Double, subcategory: BudgetSubcategory?, with context: NSManagedObjectContext) -> BudgetItem {
        let item = BudgetItem(context: context)
        item.name = name
        item.amount = amount
        item.date = Date()
        item.subcategory = subcategory
        item.createdDate = Date()
        item.modifiedDate = Date()
        
        context.insert(item)
        saveContext(context)
        return item
    }
    
    func saveBudgetItem(_ item: BudgetItem, with context: NSManagedObjectContext) {
        item.modifiedDate = Date()
        saveContext(context)
    }
    
    func deleteBudgetItem(_ item: BudgetItem, with context: NSManagedObjectContext) {
        context.delete(item)
        saveContext(context)
    }
    
    // MARK: - Calculations
    
    func calculateTotalSpent(for subcategory: BudgetSubcategory, in period: Date) -> Double {
        guard let items = subcategory.items else { return 0.0 }
        
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: period)?.start ?? period
        let endOfMonth = calendar.dateInterval(of: .month, for: period)?.end ?? period
        
        return items.reduce(0.0) { total, item in
            guard let budgetItem = item as? BudgetItem,
                  let itemDate = budgetItem.date,
                  itemDate >= startOfMonth && itemDate < endOfMonth else {
                return total
            }
            return total + budgetItem.amount
        }
    }
    
    func calculateTotalBudget(for category: BudgetCategory, in period: Date) -> Double {
        guard let subcategories = category.subcategories else { return 0.0 }
        
        return subcategories.reduce(0.0) { total, subcategory in
            guard let sub = subcategory as? BudgetSubcategory else { return total }
            return total + calculateTotalBudget(for: sub, in: period)
        }
    }
    
    func calculateTotalBudget(for subcategory: BudgetSubcategory, in period: Date) -> Double {
        guard let items = subcategory.items else { return 0.0 }
        
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: period)?.start ?? period
        let endOfMonth = calendar.dateInterval(of: .month, for: period)?.end ?? period
        
        return items.reduce(0.0) { total, item in
            guard let budgetItem = item as? BudgetItem,
                  let itemDate = budgetItem.date,
                  itemDate >= startOfMonth && itemDate < endOfMonth else {
                return total
            }
            return total + budgetItem.amount
        }
    }
    
    // MARK: - Default Categories
    
    func initializeDefaultCategories(with context: NSManagedObjectContext) {
        let defaultCategories = [
            ("🚗 Transportation", "car.fill", "#8B4513"),
            ("🏠 Housing & Utilities", "house.fill", "#2196F3"),
            ("🛍️ Daily Living & Household", "cart.fill", "#FF9800"),
            ("🍽️ Food & Leisure", "fork.knife", "#4CAF50"),
            ("💵 Financial Obligations", "banknote.fill", "#E91E63"),
            ("🧠 Education & Personal Growth", "graduationcap.fill", "#9C27B0"),
            ("🩺 Health & Wellness", "cross.fill", "#3F51B5"),
            ("🎁 Gifts & Giving", "gift.fill", "#F44336"),
            ("📝 Miscellaneous", "ellipsis.circle.fill", "#607D8B")
        ]
        
        for (index, (name, icon, color)) in defaultCategories.enumerated() {
            let category = createCategory(name: name, icon: icon, color: color, with: context)
            category.sortOrder = Int16(index)
        }
        
        saveContext(context)
    }
    
    // MARK: - Cleanup
    
    func cleanupExpiredItems(with context: NSManagedObjectContext) {
        // This could be used to clean up old budget items if needed
        // For now, we'll keep all items
    }
    
    func clearAllBudgetData(with context: NSManagedObjectContext) {
        // Clear all budget items
        let budgetItemRequest: NSFetchRequest<BudgetItem> = BudgetItem.fetchRequest()
        let budgetItems = (try? context.fetch(budgetItemRequest)) ?? []
        for item in budgetItems {
            context.delete(item)
        }
        
        // Clear all subcategories
        let subcategoryRequest: NSFetchRequest<BudgetSubcategory> = BudgetSubcategory.fetchRequest()
        let subcategories = (try? context.fetch(subcategoryRequest)) ?? []
        for subcategory in subcategories {
            context.delete(subcategory)
        }
        
        // Clear all categories
        let categoryRequest: NSFetchRequest<BudgetCategory> = BudgetCategory.fetchRequest()
        let categories = (try? context.fetch(categoryRequest)) ?? []
        for category in categories {
            context.delete(category)
        }
        
        saveContext(context)
    }
    
    // MARK: - Helper Methods
    
    private func getNextSortOrder(for context: NSManagedObjectContext) -> Int {
        let request: NSFetchRequest<BudgetCategory> = BudgetCategory.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \BudgetCategory.sortOrder, ascending: false)]
        request.fetchLimit = 1
        
        do {
            let categories = try context.fetch(request)
            return Int(categories.first?.sortOrder ?? 0) + 1
        } catch {
            return 0
        }
    }
    
    private func saveContext(_ context: NSManagedObjectContext) {
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}