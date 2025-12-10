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
        sortDescriptors: [NSSortDescriptor(keyPath: \BudgetItem.date, ascending: false)],
        predicate: NSPredicate(format: "name == %@", "Monthly Income")
    ) private var incomeItems: FetchedResults<BudgetItem>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \BudgetSubcategory.sortOrder, ascending: true)]
    ) private var subcategories: FetchedResults<BudgetSubcategory>
    
    @StateObject private var budgetManager = BudgetManager.shared
    @State private var selectedItem: BudgetItem?
    @State private var showingCreateItem = false
    @State private var showingCreateCategory = false
    @State private var showingCategoryManagement = false
    @State private var newItem: BudgetItem?
    @State private var showingIncomeInput = false
    @State private var showingResetAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    
    // Current period for budget calculations (can be extended for monthly views later)
    private var currentPeriod: Date {
        Date()
    }
    
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
                onSave: { saveMonthlyIncome($0) }
            )
        }
    }
    
    private var monthlyIncome: Double {
        incomeItems.first?.amount ?? 0.0
    }
    
    private func saveMonthlyIncome(_ amount: Double) {
        guard amount >= 0 else {
            showError("Income amount cannot be negative")
            return
        }
        
        // Ensure only one income item exists
        if incomeItems.count > 1 {
            // Remove duplicates, keep the first one
            for item in incomeItems.dropFirst() {
                viewContext.delete(item)
            }
        }
        
        if let existingItem = incomeItems.first {
            existingItem.amount = amount
            existingItem.modifiedDate = Date()
        } else {
            let incomeItem = BudgetItem(context: viewContext)
            incomeItem.id = UUID()  // Required for CloudKit sync
            incomeItem.name = "Monthly Income"
            incomeItem.amount = amount
            incomeItem.date = Date()
            incomeItem.createdDate = Date()
            incomeItem.modifiedDate = Date()
            viewContext.insert(incomeItem)
        }
        
        viewContext.processPendingChanges()
        
        do {
            try viewContext.save()
            PersistenceController.shared.save()
        } catch {
            showError("Failed to save monthly income: \(error.localizedDescription)")
        }
    }
    
    private func showError(_ message: String) {
        errorMessage = message
        showingErrorAlert = true
    }
    
    private var budgetContent: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.md) {
                // Summary cards
                summaryCards
                
                // Category list - @FetchRequest already sorted
                ForEach(categories, id: \.objectID) { category in
                    CategoryCardView(
                        category: category,
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
                                showError("Failed to save new item: \(error.localizedDescription)")
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
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
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
    private var totalBudget: Double {
        subcategories.reduce(0.0) { total, subcategory in
            total + subcategory.budgetAmount
        }
    }
    
    private var totalSpent: Double {
        return categories.reduce(0.0) { total, category in
            guard let subcategories = category.subcategories else { return total }
            return total + subcategories.reduce(0.0) { subTotal, subcategory in
                if let sub = subcategory as? BudgetSubcategory {
                    return subTotal + budgetManager.calculateTotalSpent(for: sub, in: currentPeriod)
                } else {
                    return subTotal
                }
            }
        }
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
    let onSave: (Double) -> Void
    
    @State private var incomeText: String = ""
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @FocusState private var isFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Monthly Income")
                        .font(DesignSystem.Typography.title1)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("Enter your total monthly income")
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
                            .onChange(of: incomeText) { _, newValue in
                                // Format as user types
                                if !newValue.isEmpty && newValue != "0" {
                                    // Allow only valid decimal input
                                    let filtered = newValue.filter { "0123456789.".contains($0) }
                                    if filtered != newValue {
                                        incomeText = filtered
                                    }
                                }
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
            .alert("Invalid Input", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveIncome() {
        let cleanedText = incomeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = Double(cleanedText), value >= 0 {
            onSave(value)
            dismiss()
        } else if cleanedText.isEmpty {
            onSave(0.0)
            dismiss()
        } else {
            // Invalid input - show error
            errorMessage = "Please enter a valid amount (numbers and decimal point only)"
            showingErrorAlert = true
        }
    }
}

// MARK: - Category Card View
struct CategoryCardView: View {
    let category: BudgetCategory
    let budgetManager: BudgetManager
    let onItemTap: (BudgetItem) -> Void
    let onCreateItem: (String) -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingSubcategories = false
    @State private var subcategoryBudgets: [String: Double] = [:]
    @State private var subcategoryTextInputs: [String: String] = [:]
    @State private var showingAddSubcategoryField = false
    @State private var newSubcategoryName: String = ""
    @FocusState private var focusedSubcategory: String?
    @FocusState private var isAddingSubcategoryFocused: Bool
    
    // 4. Fix the totalBudget calculation
    private var totalBudget: Double {
        guard let subcategories = category.subcategories as? Set<BudgetSubcategory> else { return 0.0 }
        return subcategories.reduce(0.0) { result, subcategory in
            result + subcategory.budgetAmount
        }
    }
    
    private var totalSpent: Double {
        guard let subcategories = category.subcategories else { return 0.0 }
        let currentPeriod = Date()
        
        return subcategories.reduce(0.0) { total, subcategory in
            if let sub = subcategory as? BudgetSubcategory {
                return total + budgetManager.calculateTotalSpent(for: sub, in: currentPeriod)
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
        BudgetDefaultSubcategories.subcategories(for: category.name ?? "")
    }
    
    private var subcategoryNames: [String] {
        var names = defaultSubcategories
        if let existing = category.subcategories as? Set<BudgetSubcategory> {
            let sortedExisting = existing.sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return (lhs.name ?? "") < (rhs.name ?? "")
                }
                return lhs.sortOrder < rhs.sortOrder
            }
            for subcategory in sortedExisting {
                guard let name = subcategory.name, !name.isEmpty else { continue }
                if !names.contains(name) {
                    names.append(name)
                }
            }
        }
        return names
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Category header with budget input
            categoryHeader
            
            // Subcategories dropdown
            subcategoriesDropdown
            
            // Balance summary
            balanceSummary
            }
            .padding(DesignSystem.Spacing.md)
            .minimalistCard(.outlined)
        .onAppear {
            loadSubcategoryBudgets()
        }
        .onChange(of: category.subcategories?.count ?? 0) { _, _ in
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
                    if subcategoryNames.isEmpty {
                        Text("No subcategories yet")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .padding(.bottom, DesignSystem.Spacing.xs)
                    }
                    
                    ForEach(subcategoryNames, id: \.self) { subcategory in
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
                            
                            budgetInput(for: subcategory)
                        }
                    }
                    
                    if showingAddSubcategoryField {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            TextField("New subcategory", text: $newSubcategoryName)
                                .textInputAutocapitalization(.words)
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .textFieldStyle(.roundedBorder)
                                .focused($isAddingSubcategoryFocused)
                                .onAppear {
                                    isAddingSubcategoryFocused = true
                                }
                            
                            Button("Add") {
                                addNewSubcategory()
                            }
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.semibold)
                        }
                        .padding(.top, DesignSystem.Spacing.xs)
                    } else {
                        Button {
                            showingAddSubcategoryField = true
                        } label: {
                            Label("Add Subcategory", systemImage: "plus.circle")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.accent)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, DesignSystem.Spacing.xs)
                    }
                }
                .padding(.leading, DesignSystem.Spacing.md)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
    
    private func budgetInput(for subcategory: String) -> some View {
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
            .frame(width: 68)
            .textFieldStyle(.plain)
            .focused($focusedSubcategory, equals: subcategory)
            .onTapGesture {
                subcategoryTextInputs[subcategory] = ""
                focusedSubcategory = subcategory
            }
            .onChange(of: focusedSubcategory) { _, newFocus in
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
    
    private func loadSubcategoryBudgets() {
        subcategoryBudgets.removeAll()
        for name in subcategoryNames {
            guard let subcategory = findOrCreateSubcategory(named: name) else { continue }
            subcategoryBudgets[name] = subcategory.budgetAmount
        }
        
        if viewContext.hasChanges {
            do {
                try viewContext.save()
            } catch {
                // Error will be handled by parent view if needed
            }
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        if amount == 0.0 {
            return ""
        }
        return String(format: "%.2f", amount)
    }
    
    private func saveSubcategoryBudget(_ subcategory: String, amount: Double) {
        guard let subcategoryEntity = findOrCreateSubcategory(named: subcategory) else { return }
        subcategoryEntity.budgetAmount = amount
        subcategoryEntity.modifiedDate = Date()
        
        viewContext.processPendingChanges()
        
        do {
            try viewContext.save()
            PersistenceController.shared.save()
        } catch {
            // Log error - parent view can handle UI feedback if needed
            print("Failed to save subcategory budget: \(error.localizedDescription)")
        }
    }
    
    private func addNewSubcategory() {
        let trimmedName = newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard !subcategoryNames.contains(trimmedName) else {
            newSubcategoryName = ""
            showingAddSubcategoryField = false
            return
        }
        
        if let subcategory = findOrCreateSubcategory(named: trimmedName) {
            subcategoryBudgets[trimmedName] = subcategory.budgetAmount
            subcategoryTextInputs[trimmedName] = ""
            subcategory.sortOrder = Int16(subcategoryNames.count)
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to add subcategory: \(error.localizedDescription)")
        }
        
        newSubcategoryName = ""
        showingAddSubcategoryField = false
    }
    
    private func findOrCreateSubcategory(named name: String) -> BudgetSubcategory? {
        if let existing = category.subcategories?.first(where: {
            guard let sub = $0 as? BudgetSubcategory else { return false }
            return sub.name == name
        }) as? BudgetSubcategory {
            return existing
        }
        
        let subcategory = BudgetSubcategory(context: viewContext)
        subcategory.id = UUID()  // Required for CloudKit sync
        subcategory.name = name
        subcategory.category = category
        subcategory.budgetAmount = 0.0
        subcategory.createdDate = Date()
        subcategory.modifiedDate = Date()
        subcategory.sortOrder = Int16(subcategoryNames.count)
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
    @State private var date: Date = Date()
    @State private var notes: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Item Name", text: $name)
                    TextField("Amount", value: $amount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }
                
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
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
        date = item.date ?? Date()
        notes = item.notes ?? ""
    }
    
    private func saveItem() {
        item.name = name.isEmpty ? "Untitled Item" : name
        item.amount = amount
        item.date = date
        item.notes = notes
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
                                initialBudget: budget,
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
    
    @State private var categoryToDelete: BudgetCategory?
    @State private var showingDeleteConfirmation = false
    
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
                        
                        Button(action: {
                            deleteCategory(category)
                        }) {
                            Label("Delete", systemImage: "trash")
                                .font(DesignSystem.Typography.caption)
                        }
                        .foregroundColor(.red)
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
            .alert("Delete Category", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    categoryToDelete = nil
                }
                Button("Delete", role: .destructive) {
                    confirmDeleteCategory()
                }
            } message: {
                if let category = categoryToDelete {
                    let subcategoryCount = category.subcategories?.count ?? 0
                    let itemCount = (category.subcategories as? Set<BudgetSubcategory>)?.reduce(0) { total, sub in
                        total + (sub.items?.count ?? 0)
                    } ?? 0
                    
                    if subcategoryCount > 0 || itemCount > 0 {
                        Text("This will delete the category and all \(subcategoryCount) subcategories with \(itemCount) items. This action cannot be undone.")
                    } else {
                        Text("Are you sure you want to delete this category?")
                    }
                }
            }
        }
    }
    
    private func deleteCategory(_ category: BudgetCategory) {
        categoryToDelete = category
        showingDeleteConfirmation = true
    }
    
    private func confirmDeleteCategory() {
        guard let category = categoryToDelete else { return }
        
        viewContext.delete(category)
        do {
            try viewContext.save()
        } catch {
            print("Failed to delete category: \(error.localizedDescription)")
        }
        
        categoryToDelete = nil
    }
    
    private func moveCategories(from source: IndexSet, to destination: Int) {
        // Convert FetchedResults to array for manipulation
        var categoryArray = Array(categories)
        categoryArray.move(fromOffsets: source, toOffset: destination)
        
        // Update sortOrder for all categories
        for (index, category) in categoryArray.enumerated() {
            category.sortOrder = Int16(index)
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Failed to reorder categories: \(error.localizedDescription)")
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
                        // Note: Restore functionality requires isDeleted flag in Core Data model
                        // For now, only permanent delete is available
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
