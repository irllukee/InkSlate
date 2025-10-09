//
//  BudgetViews.swift
//  InkSlate
//
//  Created by Lucas Waldron on 1/2/25.
//

import SwiftUI
import SwiftData

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
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BudgetCategory.sortOrder, order: .forward) private var categories: [BudgetCategory]
    @Query(
        filter: #Predicate<BudgetItem> { !$0.isDeleted },
        sort: \BudgetItem.date,
        order: .reverse
    ) private var budgetItems: [BudgetItem]
    @StateObject private var budgetManager = BudgetManager()
    @State private var selectedItem: BudgetItem?
    @State private var showingCreateItem = false
    @State private var showingCreateCategory = false
    @State private var showingCategoryManagement = false
    @State private var newItem: BudgetItem?
    @State private var selectedPeriod: Date = Date()
    @State private var showingIncomeInput = false
    
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
                budgetManager.initializeDefaultCategories(with: modelContext)
            }
            budgetManager.cleanupExpiredItems(with: modelContext)
        }
        .sheet(isPresented: $showingCreateItem) {
            if let item = newItem {
                BudgetItemDetailView(item: item, budgetManager: budgetManager)
            }
        }
        .sheet(isPresented: $showingCreateCategory) {
            CreateCategoryView(budgetManager: budgetManager, modelContext: modelContext)
        }
        .sheet(isPresented: $showingCategoryManagement) {
            CategoryManagementView(budgetManager: budgetManager, modelContext: modelContext)
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
            item.name == "Monthly Income" &&
            item.isIncome &&
            !item.isDeleted
        }
        return incomeItems.first?.amount ?? 0.0
    }
    
    // UPDATED: No date filtering - just update or create single income item
    private func saveMonthlyIncome(_ amount: Double) {
        // Find existing monthly income item (no date filtering)
        let incomeItems = budgetItems.filter { item in
            item.name == "Monthly Income" &&
            item.isIncome &&
            !item.isDeleted
        }
        
        if let existingItem = incomeItems.first {
            // Update existing income
            existingItem.amount = amount
            existingItem.modifiedDate = Date()
        } else {
            // Create new income item
            let incomeItem = BudgetItem(
                name: "Monthly Income",
                amount: amount,
                date: Date(), // Just use current date as timestamp
                isIncome: true
            )
            modelContext.insert(incomeItem)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving monthly income: \(error)")
        }
    }
    
    private var budgetContent: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                // Summary cards
                summaryCards
                
                // Category list
                ForEach(categories.sorted(by: { $0.sortOrder < $1.sortOrder }), id: \.persistentModelID) { category in
                    CategoryCardView(
                        category: category,
                        period: selectedPeriod,
                        budgetManager: budgetManager,
                        onItemTap: { item in
                            selectedItem = item
                        },
                        onCreateItem: {
                            newItem = budgetManager.createBudgetItem(
                                name: "New Item",
                                amount: 0.0,
                                category: category,
                                with: modelContext
                            )
                            showingCreateItem = true
                        }
                    )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.xxl)
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
            
            Text("Tap the + button to create your first budget category")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textTertiary)
                .multilineTextAlignment(.center)
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
        return budgetItems.filter { item in
            !item.isDeleted &&
            !item.isIncome &&
            item.name.hasSuffix(" Budget") &&
            item.name != "Monthly Income"
        }.reduce(0.0) { total, item in
            total + item.amount
        }
    }
    
    private var totalSpent: Double {
        categories.reduce(0.0) { total, category in
            total + budgetManager.calculateTotalSpent(for: category, in: selectedPeriod)
        }
    }
    
    // UPDATED: No date filtering - just get the single monthly income
    private var monthlyIncome: Double {
        // Get the single monthly income item (no date filtering)
        if let incomeItem = budgetItems.first(where: { item in
            !item.isDeleted &&
            item.isIncome &&
            item.name == "Monthly Income"
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
    let onCreateItem: () -> Void
    
    @Environment(\.modelContext) private var modelContext
    @State private var budgetAmount: Double = 0.0
    @State private var showingSubcategories = false
    @State private var subcategoryBudgets: [String: Double] = [:]
    @State private var subcategoryTextInputs: [String: String] = [:]
    @FocusState private var focusedSubcategory: String?
    
    private var totalBudget: Double {
        subcategoryBudgets.values.reduce(0.0, +)
    }
    
    private var totalSpent: Double {
        budgetManager.calculateTotalSpent(for: category, in: period)
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
            Image(systemName: category.icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(Color(hex: category.color) ?? DesignSystem.Colors.accent)
                .frame(width: 24)
            
            Text(category.name)
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
                            
                            Text(subcategory)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
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
    
    // UPDATED: No date filtering - just one budget per subcategory
    private func loadSubcategoryBudgets() {
        for subcategory in defaultSubcategories {
            // Find the budget item without date filtering
            if let existingItem = category.budgetItems?.first(where: { item in
                item.name == "\(subcategory) Budget" && !item.isDeleted
            }) {
                subcategoryBudgets[subcategory] = existingItem.amount
            } else {
                subcategoryBudgets[subcategory] = 0.0
            }
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        if amount == 0.0 {
            return "0.00"
        }
        return String(format: "%.2f", amount)
    }
    
    // UPDATED: No date filtering - just update or create single budget item
    private func saveSubcategoryBudget(_ subcategory: String, amount: Double) {
        // Find existing budget item for this subcategory (no date check)
        let existingItem = category.budgetItems?.first(where: { item in
            item.name == "\(subcategory) Budget" && !item.isDeleted
        })
        
        if let existingItem = existingItem {
            // Update existing item
            existingItem.amount = amount
            existingItem.modifiedDate = Date()
        } else if amount > 0 {
            // Only create new item if amount is greater than 0
            let budgetItem = BudgetItem(
                name: "\(subcategory) Budget",
                amount: amount,
                date: Date(), // Just use current date as a timestamp, not for filtering
                category: category
            )
            budgetItem.isIncome = false
            modelContext.insert(budgetItem)
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving subcategory budget: \(error)")
        }
    }
    
    
    private var balanceSummary: some View {
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
    }
}

// MARK: - Budget Item Row View
struct BudgetItemRowView: View {
    let item: BudgetItem
    let onTap: (BudgetItem) -> Void
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .lineLimit(1)
                
                if !item.notes.isEmpty {
                    Text(item.notes)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 4) {
                    if item.isIncome {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.success)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(DesignSystem.Colors.error)
                    }
                    
                    Text(NumberFormatter.currency.string(from: NSNumber(value: item.amount)) ?? "$0.00")
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }
                
                Text(DateFormatter.shortDate.string(from: item.date))
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
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
    @Environment(\.modelContext) private var modelContext
    
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
        name = item.name
        amount = item.amount
        budgetAmount = item.budgetAmount
        date = item.date
        notes = item.notes
        isIncome = item.isIncome
        isRecurring = item.isRecurring
        recurringFrequency = item.recurringFrequency
    }
    
    private func saveItem() {
        item.name = name.isEmpty ? "Untitled Item" : name
        item.amount = amount
        item.budgetAmount = budgetAmount
        item.date = date
        item.notes = notes
        item.isIncome = isIncome
        item.isRecurring = isRecurring
        item.recurringFrequency = recurringFrequency
        
        budgetManager.saveBudgetItem(item, with: modelContext)
    }
}

// MARK: - Create Category View
struct CreateCategoryView: View {
    let budgetManager: BudgetManager
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var selectedIcon = "dollarsign.circle"
    @State private var selectedColor = "#8B4513"
    
    let icons = ["dollarsign.circle", "house.fill", "car.fill", "cart.fill", "fork.knife", "banknote.fill", "graduationcap.fill", "cross.fill", "gift.fill", "ellipsis.circle.fill"]
    let colors = ["#8B4513", "#2196F3", "#FF9800", "#4CAF50", "#E91E63", "#9C27B0", "#3F51B5", "#F44336", "#FF5722", "#607D8B"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category Details") {
                    TextField("Category Name", text: $name)
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
                        let _ = budgetManager.createCategory(name: name, icon: selectedIcon, color: selectedColor, with: modelContext)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Category Management View
struct CategoryManagementView: View {
    let budgetManager: BudgetManager
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BudgetCategory.sortOrder, order: .forward) private var categories: [BudgetCategory]
    
    var body: some View {
        NavigationView {
            List {
                ForEach(categories, id: \.persistentModelID) { category in
                    HStack {
                        Image(systemName: category.icon)
                            .foregroundColor(Color(hex: category.color) ?? DesignSystem.Colors.accent)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name)
                                .font(DesignSystem.Typography.headline)
                            
                            Text("\(category.budgetItems?.count ?? 0) items")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        if !category.isDefault {
                            Button("Delete") {
                                deleteCategory(category)
                            }
                            .foregroundColor(.red)
                            .font(DesignSystem.Typography.caption)
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
        modelContext.delete(category)
        do {
            try modelContext.save()
        } catch {
            print("Error deleting category: \(error)")
        }
    }
    
    private func moveCategories(from source: IndexSet, to destination: Int) {
        var mutableCategories = categories
        mutableCategories.move(fromOffsets: source, toOffset: destination)
        
        for (index, category) in mutableCategories.enumerated() {
            category.sortOrder = index
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error reordering categories: \(error)")
        }
    }
}

// MARK: - Budget Trash View
struct BudgetTrashView: View {
    let budgetManager: BudgetManager
    let modelContext: ModelContext
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<BudgetItem> { $0.isDeleted == true }) private var deletedItems: [BudgetItem]
    
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
                ForEach(deletedItems, id: \.persistentModelID) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(DesignSystem.Typography.headline)
                        
                                Text("Deleted \(DateFormatter.mediumDateTime.string(from: item.deletedDate))")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Restore") {
                            budgetManager.restoreBudgetItem(item, with: modelContext)
                        }
                        .tint(.green)
                        
                        Button("Delete Forever", role: .destructive) {
                            budgetManager.permanentlyDelete(item, with: modelContext)
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
            budgetManager.permanentlyDelete(item, with: modelContext)
        }
    }
}
