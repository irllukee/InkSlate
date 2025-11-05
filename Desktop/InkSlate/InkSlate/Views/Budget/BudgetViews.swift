//
//  BudgetViews.swift
//  InkSlate
//
//  Created by Lucas Waldron on 1/2/25.
//

import SwiftUI
import CoreData
import Foundation

// MARK: - Balance Status Enum

enum BalanceStatus {
    case underBudget
    case closeToLimit
    case overBudget
    
    var color: Color {
        switch self {
        case .underBudget:
            return DesignSystem.Colors.success
        case .closeToLimit:
            return .orange
        case .overBudget:
            return .red
        }
    }
    
    var icon: String {
        switch self {
        case .underBudget:
            return "checkmark.circle.fill"
        case .closeToLimit:
            return "exclamationmark.triangle.fill"
        case .overBudget:
            return "xmark.circle.fill"
        }
    }
}

// MARK: - Recurring Frequency Enum

enum RecurringFrequency: String, CaseIterable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"
    
    var displayName: String {
        switch self {
        case .daily:
            return "Daily"
        case .weekly:
            return "Weekly"
        case .monthly:
            return "Monthly"
        case .quarterly:
            return "Quarterly"
        case .yearly:
            return "Yearly"
        }
    }
}

// MARK: - Formatters

extension NumberFormatter {
    static let currency: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        return formatter
    }()
}

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
    
    static let mediumDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }()
}

// MARK: - Budget Feature Views

struct BudgetMainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BudgetCategory.sortOrder, ascending: true)]
    ) private var categories: FetchedResults<BudgetCategory>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BudgetItem.date, ascending: false)]
    ) private var budgetItems: FetchedResults<BudgetItem>
    @StateObject private var budgetManager = BudgetManager.shared
    @State private var selectedItem: BudgetItem?
    @State private var showingCreateItem = false
    @State private var showingCreateCategory = false
    @State private var showingCategoryManagement = false
    @State private var newItem: BudgetItem?
    @State private var selectedPeriod: Date = Date()
    @State private var showingIncomeInput = false
    @State private var showingResetAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header right below navigation bar
            HStack {
                Text("Budget")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                HStack(spacing: DesignSystem.Spacing.md) {
                    Button(action: {
                        showingCreateCategory = true
                    }) {
                        Image(systemName: "folder.badge.plus")
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                    }
                    
                    Button(action: {
                        showingCategoryManagement = true
                    }) {
                        Image(systemName: "folder")
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                    }
                    
                    // Reset budget data button
                    Button(action: {
                        showingResetAlert = true
                    }) {
                        Image(systemName: "trash.circle")
                            .foregroundColor(.red)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.md)
            
            // Main content
            if categories.isEmpty {
                emptyStateView
            } else {
                budgetContent
            }
        }
        .onAppear {
            if categories.isEmpty {
                budgetManager.initializeDefaultCategories(with: viewContext)
            }
            budgetManager.cleanupExpiredItems(with: viewContext)
        }
        .sheet(isPresented: $showingCreateItem) {
            if let item = newItem {
                BudgetItemDetailView(item: item, budgetManager: budgetManager)
            }
        }
        .sheet(isPresented: $showingCreateCategory) {
            CreateCategoryView(budgetManager: budgetManager, viewContext: viewContext)
        }
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView(budgetManager: budgetManager, viewContext: viewContext)
        }
        .sheet(item: $selectedItem) { item in
            BudgetItemDetailView(item: item, budgetManager: budgetManager)
        }
        .sheet(isPresented: $showingIncomeInput) {
            MonthlyIncomeInputView(
                income: .constant(monthlyIncome),
                period: selectedPeriod,
                onSave: { saveMonthlyIncome($0) }
            )
        }
    }
    
    // UPDATED: No date filtering - just get the single monthly income
    private func getMonthlyIncome() -> Double {
        // Get the single monthly income (no date filtering)
        let incomeItems = budgetItems.filter { item in
            item.name == "Monthly Income"
        }
        return incomeItems.first?.amount ?? 0.0
    }
    
    // UPDATED: No date filtering - just update or create single income item
    private func saveMonthlyIncome(_ amount: Double) {
        // Find existing monthly income item (no date filtering)
        let incomeItems = budgetItems.filter { item in
            item.name == "Monthly Income"
        }
        
        if let existingItem = incomeItems.first {
            // Update existing income
            existingItem.amount = amount
            existingItem.modifiedDate = Date()
        } else {
            // Create new income item
            let incomeItem = BudgetItem(context: viewContext)
            incomeItem.name = "Monthly Income"
            incomeItem.amount = amount
            incomeItem.date = Date()
            // incomeItem.isIncome = true // Property doesn't exist in Core Data model
            incomeItem.createdDate = Date()
            incomeItem.modifiedDate = Date()
            viewContext.insert(incomeItem)
        }
        
        do {
            try viewContext.save()
        } catch {
            
        }
    }
    
    private var budgetContent: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                // Summary cards
                summaryCards
                
                // Category list
                ForEach(categories.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.objectID) { category in
                    CategoryCardView(
                        category: category,
                        period: selectedPeriod,
                        budgetManager: budgetManager,
                        onItemTap: { item in
                            selectedItem = item
                        },
                        onCreateItem: { subcategory in
                            // Create a subcategory first, then create the budget item
                            let subcategoryEntity = budgetManager.createSubcategory(
                                name: subcategory,
                                category: category,
                                with: viewContext
                            )
                            newItem = budgetManager.createBudgetItem(
                                name: subcategory,
                                amount: 0.0,
                                subcategory: subcategoryEntity,
                                with: viewContext
                            )
                            
                            // Save context immediately after creating the item
                            do {
                                try viewContext.save()
                            } catch {
                                print("Failed to save new item: \(error)")
                            }
                            
                            showingCreateItem = true
                        }
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl)
        }
        .alert("Reset Budget Data", isPresented: $showingResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                budgetManager.clearAllBudgetData(with: viewContext)
                budgetManager.initializeDefaultCategories(with: viewContext)
            }
        } message: {
            Text("This will permanently delete all budget categories, subcategories, and items. This action cannot be undone.")
        }
    }
    
    private var summaryCards: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button(action: {
                showingIncomeInput = true
            }) {
                SummaryCardView(
                    title: "Total Income",
                    amount: monthlyIncome,
                    color: DesignSystem.Colors.success,
                    icon: "arrow.up.circle.fill"
                )
            }
            .buttonStyle(PlainButtonStyle())
                
            SummaryCardView(
                title: "Total Budget",
                amount: totalBudget,
                color: budgetColor,
                icon: "target"
            )
            
            SummaryCardView(
                title: "Total Remaining",
                amount: monthlyIncome - totalBudget,
                color: remainingColor,
                icon: remainingIcon
            )
        }
    }
    
    private var remainingColor: Color {
        let remaining = monthlyIncome - totalBudget
        if remaining > 0 {
            return DesignSystem.Colors.success
        } else if remaining == 0 {
            return DesignSystem.Colors.accent
        } else {
            return .red
        }
    }
    
    private var remainingIcon: String {
        let remaining = monthlyIncome - totalBudget
        if remaining > 0 {
            return "checkmark.circle.fill"
        } else if remaining == 0 {
            return "equal.circle.fill"
        } else {
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var budgetColor: Color {
        if monthlyIncome == 0 {
            return DesignSystem.Colors.accent
        } else if totalBudget > monthlyIncome {
            return .red
        } else {
            return .green
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "chart.pie.fill")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            
            Text("No Budget Categories")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Text("Tap the folder icon with plus in the top right to create your first budget category")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.xl)
        }
        .padding(DesignSystem.Spacing.xxl)
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Button(action: {
                    showingCreateCategory = true
                }) {
                    Image(systemName: "folder.badge.plus")
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                }
                
                Button(action: {
                    showingCategoryManagement = true
                }) {
                    Image(systemName: "folder")
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                }
                
            }
        }
    }
    
    // MARK: - Computed Properties
    // UPDATED: No date filtering - just sum all budget items
    private var totalBudget: Double {
        // Sum all budget items (subcategory budgets) - no date filtering
        let filteredItems = budgetItems.filter { item in
            (item.name?.hasSuffix(" Budget") ?? false) &&
            (item.name ?? "") != "Monthly Income"
        }
        
        return filteredItems.reduce(0.0) { total, item in
            total + item.amount
        }
    }
    
    private var totalSpent: Double {
        categories.reduce(0.0) { total, category in
            guard let subcategories = category.subcategories else { return total }
            return total + subcategories.reduce(0.0) { subTotal, subcategory in
                if let sub = subcategory as? BudgetSubcategory {
                    return subTotal + budgetManager.calculateTotalSpent(for: sub, in: selectedPeriod)
                } else {
                    return subTotal
                }
            }
        }
    }
    
    // UPDATED: No date filtering - just get the single monthly income
    private var monthlyIncome: Double {
        // Get the single monthly income item (no date filtering)
        if let incomeItem = budgetItems.first(where: { item in
            (item.name ?? "") == "Monthly Income"
        }) {
            return incomeItem.amount
        }
        return 0.0
    }
    
}

// MARK: - Summary Card View
struct SummaryCardView: View {
    let title: String
    let amount: Double
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
                
                Spacer()
            }
            
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
            
            Text(NumberFormatter.currency.string(from: NSNumber(value: amount)) ?? "$0.00")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .minimalistCard(.elevated)
    }
}

// MARK: - Monthly Income Input View
struct MonthlyIncomeInputView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var income: Double
    let period: Date
    let onSave: (Double) -> Void
    
    @State private var incomeText: String = ""
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Monthly Income")
                        .font(DesignSystem.Typography.title1)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("Enter your total monthly income for \(DateFormatter.monthYear.string(from: period))")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    HStack(spacing: 4) {
                        Text("$")
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        TextField("0.00", text: $incomeText)
                            .font(.system(size: 48, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.leading)
                            .textFieldStyle(.plain)
                            .focused($isFieldFocused)
                            .onTapGesture {
                                if incomeText == "0.00" || incomeText == "0" {
                                    incomeText = ""
                                }
                                isFieldFocused = true
                            }
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(DesignSystem.Colors.backgroundSecondary)
                    )
                }
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.xl)
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveIncome()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.accent)
                }
            }
            .onAppear {
                incomeText = income > 0 ? String(format: "%.2f", income) : ""
                isFieldFocused = true
            }
        }
    }
    
    private func saveIncome() {
        if let value = Double(incomeText) {
            onSave(value)
        } else {
            onSave(0.0)
        }
        dismiss()
    }
}

// MARK: - Category Card View
struct CategoryCardView: View {
    let category: BudgetCategory
    let period: Date
    let budgetManager: BudgetManager
    let onItemTap: (BudgetItem) -> Void
    let onCreateItem: (String) -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var budgetAmount: Double = 0.0
    @State private var showingSubcategories = false
    @State private var subcategoryBudgets: [String: Double] = [:]
    @State private var subcategoryTextInputs: [String: String] = [:]
    @FocusState private var focusedSubcategory: String?
    
    // 4. Fix the totalBudget calculation
    private var totalBudget: Double {
        let request: NSFetchRequest<BudgetItem> = BudgetItem.fetchRequest()
        
        // Get all items for subcategories in this category
        var total = 0.0
        
        for subcategory in defaultSubcategories {
            let budgetName = "\(subcategory) Budget"
            request.predicate = NSPredicate(format: "name == %@", budgetName)
            
            if let items = try? viewContext.fetch(request),
               let budgetItem = items.first {
                total += budgetItem.amount
            }
        }
        
        return total
    }
    
    // 5. Also update the totalSpent calculation to use actual data
    private var totalSpent: Double {
        guard let subcategories = category.subcategories else { return 0.0 }
        
        return subcategories.reduce(0.0) { total, subcategory in
            if let sub = subcategory as? BudgetSubcategory {
                let spent = budgetManager.calculateTotalSpent(for: sub, in: period)
                print("Spent for \(sub.name ?? "unknown"): $\(spent)")
                return total + spent
            }
            return total
        }
    }
    
    
    private var balanceStatus: BalanceStatus {
        if totalSpent <= totalBudget {
            return .underBudget
        } else if totalSpent <= totalBudget * 1.1 {
            return .closeToLimit
        } else {
            return .overBudget
        }
    }
    
    private var defaultSubcategories: [String] {
        switch category.name {
        case "🚗 Transportation":
            return ["Car Payment", "Car Insurance", "Fuel / Gas", "Public Transit / Rideshare", "Parking / Tolls", "Maintenance & Repairs", "Vehicle Registration / Licensing"]
        case "🏠 Housing & Utilities":
            return ["Rent / Mortgage", "Property Taxes / HOA", "Home Insurance", "Electricity", "Water & Sewer", "Gas / Heating", "Internet", "Phone / Mobile", "Trash / Recycling", "Home Maintenance / Repairs"]
        case "🛍️ Daily Living & Household":
            return ["Groceries", "Household Supplies", "Personal Care", "Clothing & Shoes", "Childcare / Babysitting", "Pet Care", "Laundry / Dry Cleaning"]
        case "🍽️ Food & Leisure":
            return ["Dining Out / Takeout", "Coffee / Snacks", "Entertainment", "Hobbies", "Subscriptions / Memberships", "Vacations & Travel"]
        case "💵 Financial Obligations":
            return ["Income Taxes", "Debt Payments", "Insurance", "Investments", "Retirement Contributions", "Emergency Fund", "Savings Goals"]
        case "🧠 Education & Personal Growth":
            return ["School Tuition / Fees", "Books & Supplies", "Courses / Training", "Kids' Activities"]
        case "🩺 Health & Wellness":
            return ["Health Insurance Premiums", "Doctor / Dentist Visits", "Prescriptions / Medications", "Therapy / Counseling", "Fitness"]
        case "🎁 Gifts & Giving":
            return ["Charitable Donations", "Birthday / Holiday Gifts", "Special Occasions"]
        case "📝 Miscellaneous":
            return ["Miscellaneous Expenses", "Buffer / Unplanned", "Allowances"]
        default:
            return []
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Category header with budget input
            categoryHeader
            
            // Subcategories dropdown (if available)
            if !defaultSubcategories.isEmpty {
                subcategoriesDropdown
            }
            
            // Balance summary
            balanceSummary
            }
            .padding(DesignSystem.Spacing.md)
            .minimalistCard(.outlined)
        .onAppear {
            loadSubcategoryBudgets()
        }
    }
    
    private var categoryHeader: some View {
        HStack {
            Image(systemName: category.icon ?? "tag")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(DesignSystem.Colors.accent)
                .frame(width: 24)
            
            Text(category.name ?? "Untitled")
                .font(DesignSystem.Typography.headline)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Spacer()
        }
    }
    
    private var subcategoriesDropdown: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingSubcategories.toggle()
                }
            }) {
                HStack {
                    Text("Subcategories")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    Spacer()
                    
                    Image(systemName: showingSubcategories ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
            
            if showingSubcategories {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    ForEach(defaultSubcategories, id: \.self) { subcategory in
                        HStack {
                            Text("•")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                            
                            Button(action: {
                                onCreateItem(subcategory)
                            }) {
                                Text(subcategory)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Spacer()
                            
                            // Budget input for this subcategory
                            HStack(spacing: 2) {
                                Text("$")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                TextField("0.00", text: Binding(
                                    get: {
                                        subcategoryTextInputs[subcategory] ?? formatAmount(subcategoryBudgets[subcategory] ?? 0.0)
                                    },
                                    set: { newValue in
                                        subcategoryTextInputs[subcategory] = newValue
                                        // Parse and save the value
                                        if let value = Double(newValue) {
                                            subcategoryBudgets[subcategory] = value
                                            saveSubcategoryBudget(subcategory, amount: value)
                                        } else if newValue.isEmpty {
                                            subcategoryBudgets[subcategory] = 0.0
                                            saveSubcategoryBudget(subcategory, amount: 0.0)
                                        }
                                    }
                                ))
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 60)
                                .textFieldStyle(.plain)
                                .focused($focusedSubcategory, equals: subcategory)
                                .onTapGesture {
                                    // Clear the text input when tapped
                                    subcategoryTextInputs[subcategory] = ""
                                    focusedSubcategory = subcategory
                                }
                                .onChange(of: focusedSubcategory) { _, newFocus in
                                    // When focus is lost, clear the text input to show formatted value
                                    if newFocus != subcategory {
                                        subcategoryTextInputs[subcategory] = nil
                                    }
                                }
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.backgroundSecondary)
                            .cornerRadius(DesignSystem.CornerRadius.xs)
                        }
                    }
                }
                .padding(.leading, DesignSystem.Spacing.md)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
    
    // 1. Fix loadSubcategoryBudgets to actually fetch data
    private func loadSubcategoryBudgets() {
        let request: NSFetchRequest<BudgetItem> = BudgetItem.fetchRequest()
        
        for subcategory in defaultSubcategories {
            // Fetch the budget item for this subcategory
            request.predicate = NSPredicate(format: "name == %@", "\(subcategory) Budget")
            
            if let items = try? viewContext.fetch(request),
               let budgetItem = items.first {
                subcategoryBudgets[subcategory] = budgetItem.amount
            } else {
                subcategoryBudgets[subcategory] = 0.0
            }
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        if amount == 0.0 {
            return ""
        }
        return String(format: "%.2f", amount)
    }
    
    // 2. Fix saveSubcategoryBudget to properly find and update items
    private func saveSubcategoryBudget(_ subcategory: String, amount: Double) {
        let budgetName = "\(subcategory) Budget"
        
        // Fetch existing budget item
        let request: NSFetchRequest<BudgetItem> = BudgetItem.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", budgetName)
        
        let existingItems = (try? viewContext.fetch(request)) ?? []
        
        if let existingItem = existingItems.first {
            // Update existing item
            existingItem.amount = amount
            existingItem.modifiedDate = Date()
        } else if amount > 0 {
            // Create new item only if amount > 0
            let budgetItem = BudgetItem(context: viewContext)
            budgetItem.name = budgetName
            budgetItem.amount = amount
            budgetItem.date = Date()
            budgetItem.createdDate = Date()
            budgetItem.modifiedDate = Date()
            
            // Find or create the subcategory entity
            if let subcategoryEntity = findOrCreateSubcategory(named: subcategory) {
                budgetItem.subcategory = subcategoryEntity
            }
            
            viewContext.insert(budgetItem)
        }
        
        do {
            try viewContext.save()
            print("Saved budget for \(subcategory): $\(amount)")
        } catch {
            print("Failed to save budget: \(error)")
        }
    }
    
    // 3. Add helper to find or create subcategory
    private func findOrCreateSubcategory(named name: String) -> BudgetSubcategory? {
        // First, check if subcategory already exists
        if let existingSubcategory = category.subcategories?.first(where: { 
            ($0 as? BudgetSubcategory)?.name == name 
        }) as? BudgetSubcategory {
            return existingSubcategory
        }
        
        // Create new subcategory
        let subcategory = BudgetSubcategory(context: viewContext)
        subcategory.name = name
        subcategory.category = category
        subcategory.createdDate = Date()
        subcategory.modifiedDate = Date()
        
        return subcategory
    }
    
    private var balanceSummary: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Budget")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text(NumberFormatter.currency.string(from: NSNumber(value: totalBudget)) ?? "$0.00")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Spent")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text(NumberFormatter.currency.string(from: NSNumber(value: totalSpent)) ?? "$0.00")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
            }
            
            // Add visual indicator for budget status
            HStack {
                Image(systemName: balanceStatus.icon)
                    .font(.system(size: 12))
                    .foregroundColor(balanceStatus.color)
                
                Text(balanceStatusText)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(balanceStatus.color)
            }
        }
    }
    
    private var balanceStatusText: String {
        switch balanceStatus {
        case .underBudget:
            return "Under budget"
        case .closeToLimit:
            return "Approaching limit"
        case .overBudget:
            return "Over budget"
        }
    }
}

// MARK: - Budget Item Row View
struct BudgetItemRowView: View {
    let item: BudgetItem
    let onTap: (BudgetItem) -> Void
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name ?? "Untitled")
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                
                                    if let notes = item.notes, !notes.isEmpty {
                        Text(notes)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(1)
                    }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    // Income/expense indicator removed - property doesn't exist
                    // if item.isIncome {
                    //     Image(systemName: "arrow.up.circle.fill")
                    //         .font(.system(size: 12))
                    //         .foregroundColor(DesignSystem.Colors.success)
                    // } else {
                    //     Image(systemName: "arrow.down.circle.fill")
                    //         .font(.system(size: 12))
                    //         .foregroundColor(DesignSystem.Colors.error)
                    // }
                    
                    Text(NumberFormatter.currency.string(from: NSNumber(value: item.amount)) ?? "$0.00")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                
                if let date = item.date {
                    Text(DateFormatter.shortDate.string(from: date))
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
        }
        .padding(.vertical, DesignSystem.Spacing.sm)
        .padding(.horizontal, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.backgroundSecondary)
        .cornerRadius(DesignSystem.CornerRadius.sm)
        .onTapGesture {
            onTap(item)
        }
    }
}

// MARK: - Budget Item Detail View
struct BudgetItemDetailView: View {
    let item: BudgetItem
    let budgetManager: BudgetManager
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    @State private var name: String = ""
    @State private var amount: Double = 0.0
    @State private var budgetAmount: Double = 0.0
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var isIncome: Bool = false
    @State private var isRecurring: Bool = false
    @State private var recurringFrequency: String = "monthly"
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Item Name", text: $name)
                    TextField("Amount", value: $amount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                    TextField("Budget Amount", value: $budgetAmount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Settings") {
                    Toggle("Income", isOn: $isIncome)
                    Toggle("Recurring", isOn: $isRecurring)
                    
                    if isRecurring {
                        Picker("Frequency", selection: $recurringFrequency) {
                            ForEach(RecurringFrequency.allCases, id: \.rawValue) { frequency in
                                Text(frequency.displayName).tag(frequency.rawValue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Budget Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadItem()
        }
    }
    
    private func loadItem() {
        name = item.name ?? ""
        amount = item.amount
        budgetAmount = 0.0 // This property doesn't exist in Core Data model
        date = item.date ?? Date()
        notes = item.notes ?? ""
        // isIncome = item.isIncome // Property doesn't exist in Core Data model
        isRecurring = false // This property doesn't exist in Core Data model
        recurringFrequency = "monthly"
    }
    
    private func saveItem() {
        item.name = name.isEmpty ? "Untitled Item" : name
        item.amount = amount
        item.date = date
        item.notes = notes
        // item.isIncome = isIncome // Property doesn't exist in Core Data model
        item.modifiedDate = Date()
        
        budgetManager.saveBudgetItem(item, with: viewContext)
    }
}

// MARK: - Create Category View
struct CreateCategoryView: View {
    let budgetManager: BudgetManager
    let viewContext: NSManagedObjectContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var budget: Double = 0.0
    @State private var selectedIcon = "dollarsign.circle"
    @State private var selectedColor = "#8B4513"
    @State private var showingDuplicateAlert = false
    
    let icons = ["dollarsign.circle", "house.fill", "car.fill", "cart.fill", "fork.knife", "banknote.fill", "graduationcap.fill", "cross.fill", "gift.fill", "ellipsis.circle.fill"]
    let colors = ["#8B4513", "#2196F3", "#FF9800", "#4CAF50", "#E91E63", "#9C27B0", "#3F51B5", "#F44336", "#FF5722", "#607D8B"]
    
    private var isDuplicateName: Bool {
        let request: NSFetchRequest<BudgetCategory> = BudgetCategory.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        let existingCategories = (try? viewContext.fetch(request)) ?? []
        return !existingCategories.isEmpty
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category Details") {
                    TextField("Category Name", text: $name)
                    TextField("Monthly Budget", value: $budget, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                }
                
                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(icons, id: \.self) { icon in
                            Button(action: {
                                selectedIcon = icon
                            }) {
                                Image(systemName: icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(selectedIcon == icon ? .white : DesignSystem.Colors.textPrimary)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? DesignSystem.Colors.accent : DesignSystem.Colors.backgroundSecondary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(colors, id: \.self) { color in
                            Button(action: {
                                selectedColor = color
                            }) {
                                Circle()
                                    .fill(Color(hex: color) ?? .gray)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(DesignSystem.Colors.border, lineWidth: selectedColor == color ? 3 : 1)
                                    )
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if isDuplicateName {
                            showingDuplicateAlert = true
                        } else {
                            let _ = budgetManager.createCategory(
                                name: name,
                                icon: selectedIcon,
                                color: selectedColor,
                                with: viewContext
                            )
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty)
                }
            }
            .alert("Duplicate Category", isPresented: $showingDuplicateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("A category with this name already exists. Please choose a different name.")
            }
        }
    }
}

// MARK: - Category Management View
struct CategoryManagementView: View {
    let budgetManager: BudgetManager
    let viewContext: NSManagedObjectContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BudgetCategory.sortOrder, ascending: true)]
    ) private var categories: FetchedResults<BudgetCategory>
    
    var body: some View {
        NavigationView {
            List {
                ForEach(categories, id: \.objectID) { category in
                    HStack {
                        Image(systemName: category.icon ?? "tag")
                            .foregroundColor(DesignSystem.Colors.accent)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name ?? "Untitled")
                                .font(DesignSystem.Typography.headline)
                            
                            Text("\(category.subcategories?.count ?? 0) subcategories")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        if false { // isDefault property doesn't exist in Core Data model
                            Text("Default")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textTertiary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(DesignSystem.Colors.backgroundSecondary)
                                .cornerRadius(4)
                        } else {
                            Button(action: {
                                deleteCategory(category)
                            }) {
                                Label("Delete", systemImage: "trash")
                                    .font(DesignSystem.Typography.caption)
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onMove(perform: moveCategories)
            }
            .navigationTitle("Manage Categories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
        }
    }
    
    private func deleteCategory(_ category: BudgetCategory) {
        viewContext.delete(category)
        do {
            try viewContext.save()
        } catch {
            
        }
    }
    
    private func moveCategories(from source: IndexSet, to destination: Int) {
        let mutableCategories = categories
        // Note: FetchedResults doesn't support move operations directly
        // This would need to be implemented with manual reordering
        
        for (index, category) in mutableCategories.enumerated() {
            category.sortOrder = Int16(index)
        }
        
        do {
            try viewContext.save()
        } catch {
            
        }
    }
}

// MARK: - Budget Trash View
struct BudgetTrashView: View {
    let budgetManager: BudgetManager
    let viewContext: NSManagedObjectContext
    @Environment(\.dismiss) private var dismiss
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BudgetItem.date, ascending: false)]
    ) private var deletedItems: FetchedResults<BudgetItem>
    
    var body: some View {
        NavigationView {
            Group {
                if deletedItems.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Image(systemName: "trash")
                            .font(.system(size: 60))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        
                        Text("Trash is Empty")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                } else {
            List {
                ForEach(deletedItems, id: \.objectID) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name ?? "Untitled")
                            .font(DesignSystem.Typography.headline)
                        
                                Text("Deleted \(DateFormatter.mediumDateTime.string(from: item.modifiedDate ?? Date()))")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Restore") {
                            // Restore functionality not implemented in BudgetManager
                            // For now, just delete the item permanently
                            budgetManager.deleteBudgetItem(item, with: viewContext)
                        }
                        .tint(.green)
                        
                        Button("Delete Forever", role: .destructive) {
                            budgetManager.deleteBudgetItem(item, with: viewContext)
                        }
                        .tint(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Recently Deleted")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if !deletedItems.isEmpty {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Empty Trash") {
                            emptyTrash()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
    
    private func emptyTrash() {
        for item in deletedItems {
            budgetManager.deleteBudgetItem(item, with: viewContext)
        }
    }
}
