//
//  RecipeViews.swift
//  InkSlate
//
//  Created by UI Overhaul on 9/29/25.
//  Enhanced with comprehensive recipe features + Shopping List + Pantry Management
//

import SwiftUI
import CoreData
import PhotosUI
import UIKit

// MARK: - Recipe Extensions
extension Recipe {
    var isFavorite: Bool {
        return rating >= 4
    }
    
    var totalTime: Int {
        return Int(prepTime) + Int(cookTime)
    }
    
    // Helper to get ingredients as array
    var ingredientsArray: [RecipeIngredient] {
        (ingredients?.allObjects as? [RecipeIngredient]) ?? []
    }
}

// MARK: - Expanded Recipe Category Enum
enum RecipeCategory: String, CaseIterable {
    case appetizer = "Appetizer"
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case dessert = "Dessert"
    case snack = "Snack"
    case beverage = "Beverage"
    case side = "Side Dish"
    
    var icon: String {
        switch self {
        case .appetizer: return "fork.knife.circle.fill"
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .dessert: return "birthday.cake.fill"
        case .snack: return "popcorn.fill"
        case .beverage: return "cup.and.saucer.fill"
        case .side: return "square.split.2x2.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .appetizer: return .mint
        case .breakfast: return .orange
        case .lunch: return .yellow
        case .dinner: return .blue
        case .dessert: return .pink
        case .snack: return .green
        case .beverage: return .purple
        case .side: return .brown
        }
    }
}

enum DietaryTag: String, CaseIterable {
    case vegetarian = "Vegetarian"
    case vegan = "Vegan"
    case glutenFree = "Gluten-Free"
    case dairyFree = "Dairy-Free"
    case keto = "Keto"
    case paleo = "Paleo"
    case lowCarb = "Low-Carb"
    case highProtein = "High-Protein"
    
    var icon: String {
        switch self {
        case .vegetarian: return "leaf.fill"
        case .vegan: return "leaf.circle.fill"
        case .glutenFree: return "g.circle.fill"
        case .dairyFree: return "drop.circle.fill"
        case .keto: return "k.circle.fill"
        case .paleo: return "p.circle.fill"
        case .lowCarb: return "chart.line.downtrend.xyaxis"
        case .highProtein: return "figure.strengthtraining.traditional"
        }
    }
}

enum SortOption: String, CaseIterable {
    case dateNewest = "Newest First"
    case dateOldest = "Oldest First"
    case nameAZ = "Name (A-Z)"
    case nameZA = "Name (Z-A)"
    case ratingHigh = "Highest Rated"
    case ratingLow = "Lowest Rated"
    case quickest = "Quickest to Make"
}

// MARK: - Recipe Ingredient Model
struct RecipeIngredientData: Codable, Identifiable {
    let id: UUID
    var name: String
    var amount: String
    var unit: String
    var isChecked: Bool = false
    
    init(id: UUID = UUID(), name: String, amount: String, unit: String) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
    }
}

// MARK: - Recipe Step Model
struct RecipeStep: Codable, Identifiable {
    let id: UUID
    var instruction: String
    var timerMinutes: Int?
    var isCompleted: Bool = false
    
    init(id: UUID = UUID(), instruction: String, timerMinutes: Int? = nil) {
        self.id = id
        self.instruction = instruction
        self.timerMinutes = timerMinutes
    }
}


// MARK: - Shopping List Item Model
struct ShoppingListItem: Codable, Identifiable {
    let id: UUID
    var name: String
    var amount: String
    var unit: String
    var isChecked: Bool
    var category: String
    var fromRecipe: String?
    
    init(id: UUID = UUID(), name: String, amount: String = "", unit: String = "", isChecked: Bool = false, category: String = "Other", fromRecipe: String? = nil) {
        self.id = id
        self.name = name
        self.amount = amount
        self.unit = unit
        self.isChecked = isChecked
        self.category = category
        self.fromRecipe = fromRecipe
    }
}

// MARK: - Pantry Item Model
struct PantryItem: Codable, Identifiable {
    let id: UUID
    var name: String
    var quantity: String
    var unit: String
    var category: PantryCategory
    var expirationDate: Date?
    var notes: String
    
    init(id: UUID = UUID(), name: String, quantity: String = "", unit: String = "", category: PantryCategory, expirationDate: Date? = nil, notes: String = "") {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.category = category
        self.expirationDate = expirationDate
        self.notes = notes
    }
}

enum PantryCategory: String, CaseIterable, Codable {
    case fridge = "Fridge"
    case spices = "Spice Cabinet"
    case pantry = "Pantry"
    case freezer = "Freezer"
    
    var icon: String {
        switch self {
        case .fridge: return "refrigerator.fill"
        case .spices: return "sparkles"
        case .pantry: return "cabinet.fill"
        case .freezer: return "snowflake"
        }
    }
}

// MARK: - Main Tab View Wrapper
struct RecipeTabView: View {
    var body: some View {
        TabView {
            ModernRecipeMainView()
                .tabItem {
                    Label("Recipes", systemImage: "book.fill")
                }
            
            ShoppingListMainView()
                .tabItem {
                    Label("Shopping", systemImage: "cart.fill")
                }
            
            PantryMainView()
                .tabItem {
                    Label("Pantry", systemImage: "refrigerator.fill")
                }
        }
    }
}

// MARK: - Modern Recipe Main View
struct ModernRecipeMainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var sharedState: SharedStateManager

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Recipe.createdDate, ascending: false)])
    private var allRecipes: FetchedResults<Recipe>

    @State private var searchText = ""
    @State private var showingAddRecipe = false
    @State private var showingFilters = false
    @State private var selectedCategory: RecipeCategory?
    @State private var selectedSort: SortOption = .dateNewest
    @State private var showFavoritesOnly = false
    @State private var refreshing = false
    @State private var showingStats = false

    private var filteredRecipes: [Recipe] {
        var recipes = Array(allRecipes)
        
        if !searchText.isEmpty {
            recipes = recipes.filter { recipe in
            recipe.name?.localizedCaseInsensitiveContains(searchText) == true ||
                recipe.recipeDescription?.localizedCaseInsensitiveContains(searchText) == true ||
                recipe.instructions?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        if let category = selectedCategory {
            recipes = recipes.filter { $0.cuisine == category.rawValue }
        }
        
        if showFavoritesOnly {
            recipes = recipes.filter { $0.rating >= 4 } // Use rating as proxy for favorites
        }
        
        switch selectedSort {
        case .dateNewest:
            recipes.sort { ($0.createdDate ?? Date.distantPast) > ($1.createdDate ?? Date.distantPast) }
        case .dateOldest:
            recipes.sort { ($0.createdDate ?? Date.distantPast) < ($1.createdDate ?? Date.distantPast) }
        case .nameAZ:
            recipes.sort { ($0.name ?? "") < ($1.name ?? "") }
        case .nameZA:
            recipes.sort { ($0.name ?? "") > ($1.name ?? "") }
        case .ratingHigh:
            recipes.sort { $0.rating > $1.rating }
        case .ratingLow:
            recipes.sort { $0.rating < $1.rating }
        case .quickest:
            recipes.sort { ($0.prepTime + $0.cookTime) < ($1.prepTime + $1.cookTime) }
        }
        
        return recipes
    }

    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [DesignSystem.Colors.background, DesignSystem.Colors.backgroundSecondary.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: refreshing)
            
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    header
                    searchBar
                        filterChips
                    
                    if filteredRecipes.isEmpty {
                            if searchText.isEmpty && selectedCategory == nil && !showFavoritesOnly {
                            ModernEmptyRecipesView()
                        } else {
                                SearchEmptyView(searchText: searchText.isEmpty ? "your filters" : searchText)
                        }
                    } else {
                            LazyVStack(spacing: DesignSystem.Spacing.lg) {
                                ForEach(Array(filteredRecipes.enumerated()), id: \.element.objectID) { index, recipe in
                            ModernRecipeCard(recipe: recipe)
                                        .transition(.asymmetric(
                                            insertion: .scale.combined(with: .opacity),
                                            removal: .scale.combined(with: .opacity)
                                        ))
                                        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.1), value: filteredRecipes.count)
                                }
                        }
                    }
                    
                    addCard
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .refreshable { await refreshRecipes() }
            .navigationTitle("Recipes")
            .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showingStats = true }) {
                            Image(systemName: "chart.bar.fill")
                                .font(.title3)
                                .foregroundColor(DesignSystem.Colors.accent)
                        }
                    }
                    
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAddRecipe = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(DesignSystem.Colors.accent)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddRecipe) {
            ModernAddRecipeView()
        }
        .sheet(isPresented: $showingFilters) {
            FilterSortView(
                selectedCategory: $selectedCategory,
                selectedSort: $selectedSort,
                showFavoritesOnly: $showFavoritesOnly
            )
        }
        .sheet(isPresented: $showingStats) {
            RecipeStatsView(recipes: Array(allRecipes))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🍳 My Recipes")
                .font(DesignSystem.Typography.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                    Text("\(filteredRecipes.count) recipes in your collection")
                .font(DesignSystem.Typography.body)
                .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                // Quick stats
                HStack(spacing: 16) {
                    RecipeStatCard(
                        title: "Total",
                        value: "\(allRecipes.count)",
                        icon: "book.fill",
                        color: DesignSystem.Colors.accent
                    )
                    
                    RecipeStatCard(
                        title: "Favorites",
                        value: "\(allRecipes.filter { $0.rating >= 4 }.count)",
                        icon: "heart.fill",
                        color: .red
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(DesignSystem.Colors.textSecondary)
            TextField("Search recipes, ingredients...", text: $searchText)
                .textFieldStyle(.plain)
                .font(DesignSystem.Typography.body)
            if !searchText.isEmpty {
                Button(action: { 
                    withAnimation(.spring()) {
                        searchText = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .fill(DesignSystem.Colors.backgroundTertiary)
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: { showingFilters = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text("Sort & Filter")
                    }
                    .font(DesignSystem.Typography.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(DesignSystem.Colors.accent)
                    .foregroundColor(.white)
                    .cornerRadius(16)
                }
                
                if showFavoritesOnly {
                    FilterChip(title: "Favorites", icon: "heart.fill", isActive: true) {
                        withAnimation(.spring()) {
                            showFavoritesOnly = false
                        }
                    }
                }
                
                if let category = selectedCategory {
                    FilterChip(title: category.rawValue, icon: category.icon, isActive: true) {
                        withAnimation(.spring()) {
                            selectedCategory = nil
                        }
                    }
                }
                
                ForEach(RecipeCategory.allCases.filter { $0 != selectedCategory }, id: \.self) { category in
                    FilterChip(title: category.rawValue, icon: category.icon, isActive: false) {
                        withAnimation(.spring()) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.horizontal, -DesignSystem.Spacing.lg)
    }

    private var addCard: some View {
        Button(action: { showingAddRecipe = true }) {
            HStack {
                Image(systemName: "plus")
                    .font(.title3)
                Text("Add New Recipe")
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(DesignSystem.Colors.textInverse)
            .background(
                LinearGradient(
                    colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(DesignSystem.CornerRadius.lg)
            .shadow(color: DesignSystem.Colors.accent.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func refreshRecipes() async {
        refreshing = true
        try? await Task.sleep(for: .seconds(1))
        refreshing = false
    }
}

// MARK: - Recipe Stat Card Component
struct RecipeStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(value)
                    .font(DesignSystem.Typography.headline)
                    .fontWeight(.bold)
            }
            .foregroundColor(color)
            
            Text(title)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Recipe Stats View
struct RecipeStatsView: View {
    @Environment(\.dismiss) private var dismiss
    let recipes: [Recipe]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("📊 Recipe Statistics")
                            .font(DesignSystem.Typography.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Your cooking journey at a glance")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .padding(.top)
                    
                    // Stats Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        RecipeStatCard(
                            title: "Total Recipes",
                            value: "\(recipes.count)",
                            icon: "book.fill",
                            color: DesignSystem.Colors.accent
                        )
                        
                        RecipeStatCard(
                            title: "Favorites",
                            value: "\(recipes.filter { $0.rating >= 4 }.count)",
                            icon: "heart.fill",
                            color: .red
                        )
                        
                        RecipeStatCard(
                            title: "Avg Rating",
                            value: String(format: "%.1f", recipes.map { Double($0.rating) }.reduce(0, +) / Double(max(recipes.count, 1))),
                            icon: "star.fill",
                            color: .yellow
                        )
                        
                        RecipeStatCard(
                            title: "Avg Time",
                            value: "\(Int(recipes.map { Double($0.totalTime) }.reduce(0, +) / Double(max(recipes.count, 1))))m",
                            icon: "clock.fill",
                            color: .blue
                        )
                    }
                    
                    // Category Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Categories")
                            .font(DesignSystem.Typography.title2)
                            .fontWeight(.semibold)
                        
                        ForEach(RecipeCategory.allCases, id: \.self) { category in
                            let count = recipes.filter { $0.cuisine == category.rawValue }.count
                            if count > 0 {
                                HStack {
                                    Image(systemName: category.icon)
                                        .foregroundColor(category.color)
                                    Text(category.rawValue)
                                        .font(DesignSystem.Typography.body)
                                    Spacer()
                                    Text("\(count)")
                                        .font(DesignSystem.Typography.body)
                                        .fontWeight(.semibold)
                                        .foregroundColor(DesignSystem.Colors.accent)
                                }
                                .padding()
                                .background(DesignSystem.Colors.backgroundSecondary)
                                .cornerRadius(DesignSystem.CornerRadius.md)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Filter Chip
struct FilterChip: View {
    let title: String
    let icon: String
    let isActive: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
                if isActive {
                    Image(systemName: "xmark")
                        .font(.caption2)
                }
            }
            .font(DesignSystem.Typography.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isActive ? DesignSystem.Colors.accent : DesignSystem.Colors.backgroundSecondary)
            .foregroundColor(isActive ? .white : DesignSystem.Colors.textPrimary)
            .cornerRadius(16)
            .scaleEffect(isActive ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        }
    }
}

// MARK: - Filter & Sort Sheet
struct FilterSortView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCategory: RecipeCategory?
    @Binding var selectedSort: SortOption
    @Binding var showFavoritesOnly: Bool
    
    var body: some View {
        NavigationStack {
            List {
                Section("Sort By") {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Button(action: { selectedSort = option; lightHaptic() }) {
                            HStack {
                                Text(option.rawValue)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Spacer()
                                if selectedSort == option {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(DesignSystem.Colors.accent)
                                }
                            }
                        }
                    }
                }
                
                Section("Filter by Category") {
                    Button(action: { selectedCategory = nil; lightHaptic() }) {
                        HStack {
                            Text("All Categories")
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            Spacer()
                            if selectedCategory == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(DesignSystem.Colors.accent)
                            }
                        }
                    }
                    
                    ForEach(RecipeCategory.allCases, id: \.self) { category in
                        Button(action: { selectedCategory = category; lightHaptic() }) {
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                Spacer()
                                if selectedCategory == category {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(DesignSystem.Colors.accent)
                                }
                            }
                        }
                    }
                }
                
                Section {
                    Toggle("Show Favorites Only", isOn: $showFavoritesOnly)
                }
            }
            .navigationTitle("Sort & Filter")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Enhanced Recipe Card
struct ModernRecipeCard: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingDetail = false
    @State private var isPressed = false
    @ObservedObject var recipe: Recipe

    var body: some View {
        Button(role: .none, action: { showingDetail = true }) {
            HStack(spacing: 12) {
                // Compact Recipe Image
                AsyncImage(url: URL(string: recipe.imageUrl ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(DesignSystem.Colors.backgroundSecondary)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        )
                }
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
                // Recipe Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(recipe.name ?? "Untitled Recipe")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    
                    if let description = recipe.recipeDescription, !description.isEmpty {
                        Text(description)
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 12) {
                        if let servingsString = recipe.servings, let servingsInt = Int(servingsString), servingsInt > 0 {
                        Label("\(servingsString)", systemImage: "person.2")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Label("\(Int(recipe.prepTime + recipe.cookTime))m", systemImage: "clock")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        HStack(spacing: 2) {
                            ForEach(0..<5) { star in
                                Image(systemName: star < Int(recipe.rating) ? "star.fill" : "star")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Action Button
                Button(action: { showingDetail = true }) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignSystem.Colors.backgroundTertiary)
                    .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingDetail) {
            ModernRecipeDetailView(recipe: recipe)
        }
    }
    
    private func toggleFavorite() {
        recipe.rating = recipe.rating >= 4 ? 0 : 5
        try? viewContext.save()
    }
    
    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
            .fill(DesignSystem.Colors.backgroundSecondary)
            .frame(height: 200)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.title)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("No Image")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            )
    }
}

// MARK: - Empty State Views
struct ModernEmptyRecipesView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.accent)
            
            VStack(spacing: 8) {
                Text("No Recipes Yet")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.semibold)
                
                Text("Start building your recipe collection by adding your first recipe!")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

struct SearchEmptyView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(DesignSystem.Colors.textTertiary)
            
            VStack(spacing: 8) {
                Text("No Results Found")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.semibold)
                
                Text("No recipes match '\(searchText)'. Try adjusting your search or filters.")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Add/Edit Recipe
struct ModernAddRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    let editingRecipe: Recipe?
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedCategory: RecipeCategory = .dinner
    @State private var rating = 0
    @State private var imageItem: PhotosPickerItem?
    @State private var imageUrl: String = ""
    @State private var ingredients: [RecipeIngredientData] = []
    @State private var steps: [RecipeStep] = []
    @State private var prepTime = 0
    @State private var cookTime = 0
    @State private var servings = 4
    @State private var selectedTags: Set<DietaryTag> = []
    @State private var notes = ""
    
    init(editingRecipe: Recipe? = nil) {
        self.editingRecipe = editingRecipe
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    PhotosPicker(selection: $imageItem, matching: .images) {
                        imageSection
                    }
                    .onChange(of: imageItem) { _, newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                imageUrl = "data:image/jpeg;base64,\(data.base64EncodedString())"
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        TextField("Recipe Name", text: $name)
                            .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                            .font(DesignSystem.Typography.title2)
                        
                        TextField("Description", text: $description, axis: .vertical)
                            .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                            .lineLimit(3...6)

                        HStack(spacing: 16) {
                            VStack(alignment: .leading) {
                                Text("Category")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                        Picker("Category", selection: $selectedCategory) {
                            ForEach(RecipeCategory.allCases, id: \.self) { category in
                                HStack {
                                    Image(systemName: category.icon)
                                    Text(category.rawValue)
                                }.tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading) {
                                Text("Rating")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { i in
                                Image(systemName: i <= rating ? "star.fill" : "star")
                                    .foregroundColor(i <= rating ? .yellow : DesignSystem.Colors.textTertiary)
                                    .onTapGesture {
                                                withAnimation(.spring()) {
                                        rating = i
                                                }
                                        lightHaptic()
                                            }
                                    }
                                }
                            }
                        }
                        
                        HStack(spacing: 16) {
                            VStack(alignment: .leading) {
                                Text("Prep Time (min)")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Stepper("\(prepTime)", value: $prepTime, in: 0...300, step: 5)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Cook Time (min)")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Stepper("\(cookTime)", value: $cookTime, in: 0...480, step: 5)
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text("Servings")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            Stepper("\(servings) servings", value: $servings, in: 1...20)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Dietary Tags")
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                            ForEach(DietaryTag.allCases, id: \.self) { tag in
                                Button(action: { toggleTag(tag) }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: tag.icon)
                                        Text(tag.rawValue)
                                    }
                                    .font(DesignSystem.Typography.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedTags.contains(tag) ? DesignSystem.Colors.accent : DesignSystem.Colors.backgroundSecondary)
                                    .foregroundColor(selectedTags.contains(tag) ? .white : DesignSystem.Colors.textPrimary)
                                    .cornerRadius(16)
                                }
                                .scaleEffect(selectedTags.contains(tag) ? 1.05 : 1.0)
                                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedTags.contains(tag))
                            }
                        }
                    }

                    IngredientsSection(ingredients: $ingredients)
                    StepsSection(steps: $steps)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes")
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                        TextField("Additional notes or modifications...", text: $notes, axis: .vertical)
                            .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                            .lineLimit(3...6)
                    }

                    Button(action: saveRecipe) {
                        Text(editingRecipe == nil ? "Save Recipe" : "Update Recipe")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(DesignSystem.Colors.textInverse)
                            .background(
                                LinearGradient(
                                    colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(DesignSystem.CornerRadius.lg)
                            .shadow(color: DesignSystem.Colors.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(name.isEmpty || ingredients.isEmpty || steps.isEmpty)
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle(editingRecipe == nil ? "New Recipe" : "Edit Recipe")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            loadRecipeData()
        }
    }
    
    private var imageSection: some View {
        Group {
            if !imageUrl.isEmpty {
                AsyncImage(url: URL(string: imageUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipped()
                        .cornerRadius(DesignSystem.CornerRadius.md)
                } placeholder: {
                    imagePlaceholder
                }
            } else {
                imagePlaceholder
            }
        }
    }
    
    private var imagePlaceholder: some View {
        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
            .fill(
                LinearGradient(
                    colors: [DesignSystem.Colors.backgroundSecondary, DesignSystem.Colors.backgroundTertiary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(height: 220)
            .overlay(
                VStack {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 32))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    Text("Add Photo")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            )
    }
    
    private func toggleTag(_ tag: DietaryTag) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if selectedTags.contains(tag) {
                selectedTags.remove(tag)
            } else {
                selectedTags.insert(tag)
            }
        }
        lightHaptic()
    }
    
    private func loadRecipeData() {
        guard let recipe = editingRecipe else { return }
        name = recipe.name ?? ""
        description = recipe.recipeDescription ?? ""
        imageUrl = recipe.imageUrl ?? ""
        rating = Int(recipe.rating)
        prepTime = Int(recipe.prepTime)
        cookTime = Int(recipe.cookTime)
        servings = Int(recipe.servings ?? "1") ?? 1
        notes = recipe.instructions ?? ""
        
        if let category = RecipeCategory.allCases.first(where: { $0.rawValue == recipe.cuisine }) {
            selectedCategory = category
        }
        
        // Load ingredients from Core Data relationship
        if let recipeIngredients = recipe.ingredients?.allObjects as? [RecipeIngredient] {
            ingredients = recipeIngredients.map { ingredient in
                RecipeIngredientData(
                    name: ingredient.name ?? "",
                    amount: String(ingredient.amount),
                    unit: ingredient.unit ?? ""
                )
            }
        }
        
        // For now, we'll use a simple step from instructions
        if let instructions = recipe.instructions, !instructions.isEmpty {
            steps = [RecipeStep(
                instruction: instructions
            )]
        }
        
        // Initialize with empty tags for now
        selectedTags = Set<DietaryTag>()
    }

    private func saveRecipe() {
        let recipe = editingRecipe ?? Recipe(context: viewContext)
        
        if editingRecipe == nil {
        recipe.id = UUID()
            recipe.createdDate = Date()
        }
        
        recipe.name = name
        recipe.recipeDescription = description
        recipe.cuisine = selectedCategory.rawValue
        recipe.rating = Int16(rating)
        recipe.modifiedDate = Date()
        recipe.imageUrl = imageUrl
        recipe.prepTime = Int16(prepTime)
        recipe.cookTime = Int16(cookTime)
        recipe.servings = String(servings)
        recipe.instructions = notes
        
        // Clear existing ingredients and add new ones
        if let existingIngredients = recipe.ingredients?.allObjects as? [RecipeIngredient] {
            for ingredient in existingIngredients {
                viewContext.delete(ingredient)
            }
        }
        
        // Add new ingredients
        for ingredientData in ingredients {
            let ingredient = RecipeIngredient(context: viewContext)
            ingredient.id = UUID()
            ingredient.name = ingredientData.name
            ingredient.amount = Double(ingredientData.amount) ?? 0.0
            ingredient.unit = ingredientData.unit
            ingredient.recipe = recipe
        }
        
        do { try viewContext.save(); dismiss() } catch { print(error) }
    }
}

// MARK: - Ingredients Section
struct IngredientsSection: View {
    @Binding var ingredients: [RecipeIngredientData]
    @State private var showingAdd = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Ingredients")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showingAdd = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(DesignSystem.Colors.accent)
                }
            }
            
            if ingredients.isEmpty {
                Text("No ingredients added yet")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DesignSystem.Colors.backgroundSecondary)
                    .cornerRadius(DesignSystem.CornerRadius.md)
            } else {
                ForEach(ingredients.indices, id: \.self) { index in
                    let ingredient = ingredients[index]
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ingredient.name)
                                .font(DesignSystem.Typography.body)
                            Text("\(ingredient.amount) \(ingredient.unit)")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        Spacer()
                        Button(action: { 
                            withAnimation(.spring()) {
                                var items = ingredients
                                items.remove(at: index)
                                ingredients = items
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(DesignSystem.Colors.backgroundSecondary)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddIngredientView { ingredient in
                withAnimation(.spring()) {
                    ingredients.append(ingredient)
                }
                showingAdd = false
            }
        }
    }
}

struct AddIngredientView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (RecipeIngredientData) -> Void
    
    @State private var name = ""
    @State private var amount = ""
    @State private var unit = "cups"
    
    let units = ["cups", "tbsp", "tsp", "oz", "lbs", "g", "kg", "ml", "L", "whole", "pinch", "to taste"]
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Ingredient Name", text: $name)
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                Picker("Unit", selection: $unit) {
                    ForEach(units, id: \.self) { unit in
                        Text(unit).tag(unit)
                    }
                }
            }
            .navigationTitle("Add Ingredient")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let ingredient = RecipeIngredientData(name: name, amount: amount, unit: unit)
                        onAdd(ingredient)
                    }
                    .disabled(name.isEmpty || amount.isEmpty)
                }
            }
        }
    }
}

// MARK: - Steps Section
struct StepsSection: View {
    @Binding var steps: [RecipeStep]
    @State private var showingAdd = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Instructions")
                    .font(DesignSystem.Typography.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { showingAdd = true }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(DesignSystem.Colors.accent)
                }
            }
            
            if steps.isEmpty {
                Text("No steps added yet")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(DesignSystem.Colors.backgroundSecondary)
                    .cornerRadius(DesignSystem.CornerRadius.md)
            } else {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.accent)
                            .frame(width: 30)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.instruction)
                                .font(DesignSystem.Typography.body)
                            if let timer = step.timerMinutes {
                                Label("\(timer) minutes", systemImage: "timer")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { 
                            withAnimation(.spring()) {
                                var items = steps
                                items.remove(at: index)
                                steps = items
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(DesignSystem.Colors.backgroundSecondary)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddStepView { step in
                withAnimation(.spring()) {
                    steps.append(step)
                }
                showingAdd = false
            }
        }
    }
}

struct AddStepView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (RecipeStep) -> Void
    
    @State private var instruction = ""
    @State private var hasTimer = false
    @State private var timerMinutes = 0
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Instruction", text: $instruction, axis: .vertical)
                    .lineLimit(3...8)
                
                Toggle("Add Timer", isOn: $hasTimer)
                
                if hasTimer {
                    Stepper("Timer: \(timerMinutes) minutes", value: $timerMinutes, in: 1...180)
                }
            }
            .navigationTitle("Add Step")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let step = RecipeStep(
                            instruction: instruction,
                            timerMinutes: hasTimer ? timerMinutes : nil
                        )
                        onAdd(step)
                    }
                    .disabled(instruction.isEmpty)
                }
            }
        }
    }
}

// MARK: - Detail View
struct ModernRecipeDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var recipe: Recipe
    
    @State private var showCookMode = false
    @State private var showingEdit = false
    @State private var showingDeleteAlert = false
    @State private var showingAddToList = false
    @State private var currentServings: Int
    
    init(recipe: Recipe) {
        self.recipe = recipe
        _currentServings = State(initialValue: Int(recipe.servings ?? "1") ?? 1)
    }

    var body: some View {
        NavigationStack {
        ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                if let imageUrl = recipe.imageUrl, !imageUrl.isEmpty {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                                .frame(height: 300)
                            .clipped()
                    } placeholder: {
                            Rectangle()
                            .fill(DesignSystem.Colors.backgroundSecondary)
                                .frame(height: 300)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        VStack(alignment: .leading, spacing: 8) {
                Text(recipe.name ?? "Untitled Recipe")
                    .font(DesignSystem.Typography.largeTitle)
                    .fontWeight(.bold)
                            
                            if let category = recipe.cuisine {
                                HStack {
                                    if let cat = RecipeCategory.allCases.first(where: { $0.rawValue == category }) {
                                        Image(systemName: cat.icon)
                                        Text(category)
                                    } else {
                                        Text(category)
                                    }
                                }
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            
                            if recipe.rating > 0 {
                                HStack(spacing: 4) {
                                    ForEach(1...5, id: \.self) { i in
                                        Image(systemName: i <= recipe.rating ? "star.fill" : "star")
                                            .foregroundColor(i <= recipe.rating ? .yellow : DesignSystem.Colors.textTertiary)
                                    }
                                }
                            }
                        }

                if let desc = recipe.recipeDescription, !desc.isEmpty {
                    Text(desc)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }

                        HStack(spacing: 24) {
                            if recipe.prepTime > 0 {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Prep Time")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                    HStack {
                                        Image(systemName: "clock")
                                        Text("\(recipe.prepTime)m")
                                    }
                                    .font(DesignSystem.Typography.body)
                                    .fontWeight(.medium)
                                }
                            }
                            
                            if recipe.cookTime > 0 {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Cook Time")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                    HStack {
                                        Image(systemName: "flame")
                                        Text("\(recipe.cookTime)m")
                                    }
                                    .font(DesignSystem.Typography.body)
                                    .fontWeight(.medium)
                                }
                            }
                            
                            if (recipe.prepTime + recipe.cookTime) > 0 {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Total Time")
                                        .font(DesignSystem.Typography.caption)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                    HStack {
                                        Image(systemName: "timer")
                                        Text("\(recipe.totalTime)m")
                                    }
                                    .font(DesignSystem.Typography.body)
                                    .fontWeight(.medium)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(DesignSystem.Colors.backgroundSecondary)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                        
                        // Dietary tags removed - not in Core Data model
                        
                        Divider()
                        
                        let ingredients = recipe.ingredientsArray
                        if !ingredients.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Ingredients")
                                        .font(DesignSystem.Typography.title2)
                                        .fontWeight(.semibold)
                                    Spacer()
                                    if let servingsString = recipe.servings, let servingsInt = Int(servingsString), servingsInt > 0 {
                                        HStack {
                                            Button(action: { if currentServings > 1 { currentServings -= 1 } }) {
                                                Image(systemName: "minus.circle")
                                            }
                                            Text("\(currentServings)")
                                                .frame(width: 30)
                                            Button(action: { currentServings += 1 }) {
                                                Image(systemName: "plus.circle")
                                            }
                                        }
                                        .font(DesignSystem.Typography.body)
                                    }
                                }
                                
                                ForEach(ingredients) { ingredient in
                                    HStack {
                                        Text("•")
                                        Text(scaledIngredient(ingredient))
                                            .font(DesignSystem.Typography.body)
                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                                
                                Button(action: { showingAddToList = true }) {
                                    HStack {
                                        Image(systemName: "cart.badge.plus")
                                        Text("Add to Shopping List")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(DesignSystem.Colors.backgroundSecondary)
                                    .foregroundColor(DesignSystem.Colors.accent)
                                    .cornerRadius(DesignSystem.CornerRadius.md)
                                }
                            }
                        }
                        
                        Divider()

                if let instructions = recipe.instructions, !instructions.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                        Text("Instructions")
                                    .font(DesignSystem.Typography.title2)
                            .fontWeight(.semibold)
                                
                        Text(instructions)
                            .font(DesignSystem.Typography.body)
                    }
                            
                            Button(action: { showCookMode = true }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Start Cook Mode")
                                }
                        .frame(maxWidth: .infinity)
                        .padding()
                                .background(
                                    LinearGradient(
                                        colors: [DesignSystem.Colors.accent, DesignSystem.Colors.accent.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        .foregroundColor(.white)
                                .cornerRadius(DesignSystem.CornerRadius.lg)
                                .shadow(color: DesignSystem.Colors.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                        }
                        
                        // Notes section removed - not in Core Data model
            }
            .padding(DesignSystem.Spacing.lg)
                }
        }
        .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
        .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: { showingEdit = true }) {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(action: toggleFavorite) {
                            Label(
                                recipe.rating >= 4 ? "Remove from Favorites" : "Add to Favorites",
                                systemImage: recipe.rating >= 4 ? "heart.slash" : "heart"
                            )
                        }
                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showCookMode) {
            EnhancedCookModeView(recipe: recipe)
        }
        .sheet(isPresented: $showingEdit) {
            ModernAddRecipeView(editingRecipe: recipe)
        }
        .sheet(isPresented: $showingAddToList) {
            AddRecipeIngredientsToListView(recipe: recipe)
        }
        .alert("Delete Recipe?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteRecipe()
            }
        } message: {
            Text("This action cannot be undone.")
        }
    }
    
    private func scaledIngredient(_ ingredient: RecipeIngredient) -> String {
        guard let servingsString = recipe.servings,
              let originalServings = Double(servingsString),
              originalServings > 0 else {
            return "\(ingredient.amount) \(ingredient.unit ?? "") \(ingredient.name ?? "")"
        }
        
        let scale = Double(currentServings) / originalServings
        let amount = ingredient.amount
        let scaled = amount * scale
        let formatted = scaled.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(scaled)) : String(format: "%.1f", scaled)
        return "\(formatted) \(ingredient.unit ?? "") \(ingredient.name ?? "")"
    }
    
    private func toggleFavorite() {
        lightHaptic()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            // Toggle favorite by changing rating
            recipe.rating = recipe.rating >= 4 ? 0 : 5
        }
        
        do {
            try viewContext.save()
        } catch {
            print("Error saving recipe: \(error.localizedDescription)")
            // In a real app, you might want to show an alert to the user
        }
    }
    
    private func deleteRecipe() {
        viewContext.delete(recipe)
        
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error deleting recipe: \(error.localizedDescription)")
            // In a real app, you might want to show an alert to the user
        }
    }
}

// MARK: - Add Recipe Ingredients to Shopping List
struct AddRecipeIngredientsToListView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("shoppingListData") private var shoppingListData = ""
    let recipe: Recipe
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "cart.fill.badge.plus")
                    .font(.system(size: 60))
                    .foregroundColor(DesignSystem.Colors.accent)
                
                Text("Add Ingredients?")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.semibold)
                
                Text("All ingredients from \"\(recipe.name ?? "this recipe")\" will be added to your shopping list.")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: addIngredientsToList) {
                        Text("Add to Shopping List")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(DesignSystem.Colors.accent)
                            .foregroundColor(.white)
                            .cornerRadius(DesignSystem.CornerRadius.lg)
                    }
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding()
            }
            .padding()
            .navigationTitle("Add Ingredients")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func addIngredientsToList() {
        let ingredients = recipe.ingredientsArray
        
        var currentList: [ShoppingListItem] = []
        if let data = shoppingListData.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([ShoppingListItem].self, from: data) {
            currentList = decoded
        }
        
        for ingredient in ingredients {
            let item = ShoppingListItem(
                name: ingredient.name ?? "",
                amount: String(ingredient.amount),
                unit: ingredient.unit ?? "",
                category: "Groceries",
                fromRecipe: recipe.name ?? ""
            )
            currentList.append(item)
        }
        
        if let encoded = try? JSONEncoder().encode(currentList),
           let jsonString = String(data: encoded, encoding: .utf8) {
            shoppingListData = jsonString
        }
        
        lightHaptic()
        dismiss()
    }
}

// MARK: - Enhanced Cook Mode
struct EnhancedCookModeView: View {
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe
    
    @State private var steps: [RecipeStep] = []
    @State private var currentStepIndex = 0
    @State private var activeTimers: [UUID: TimerState] = [:]
    
    struct TimerState {
        var totalSeconds: Int
        var remainingSeconds: Int
        var isRunning: Bool
        var timer: Timer?
    }
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                    .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                    Text("Cook Mode")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(currentStepIndex + 1)/\(steps.count)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                }
                .background(Color.black.opacity(0.5))
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 4)
                        
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: geometry.size.width * CGFloat(currentStepIndex + 1) / CGFloat(steps.count), height: 4)
                    }
                }
                .frame(height: 4)
                
                if !steps.isEmpty && currentStepIndex < steps.count {
                    let step = steps[currentStepIndex]
                    ScrollView {
                        VStack(alignment: .leading, spacing: 32) {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Step \(currentStepIndex + 1)")
                            .font(.title3)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                Text(step.instruction)
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                                
                                if let timerMinutes = step.timerMinutes {
                                    timerView(for: step, minutes: timerMinutes)
                                }
                            }
                            
                            Spacer(minLength: 40)
                        }
                        .padding(32)
                    }
                } else {
                    completionView
                }
                
                HStack(spacing: 20) {
                    Button(action: previousStep) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Previous")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                    }
                    .disabled(currentStepIndex == 0)
                    .opacity(currentStepIndex == 0 ? 0.3 : 1)
                    
                    Button(action: nextStep) {
                        HStack {
                            Text(currentStepIndex == steps.count - 1 ? "Finish" : "Next")
                            Image(systemName: "chevron.right")
                }
                .font(.headline)
                .foregroundColor(.black)
                .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
            }
            .padding()
        }
    }
        .onAppear {
            loadSteps()
        }
        .onDisappear {
            stopAllTimers()
        }
    }
    
    private var completionView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            Text("Recipe Complete!")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Great job! Your \(recipe.name ?? "recipe") is ready to enjoy.")
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            Button(action: { dismiss() }) {
                Text("Done")
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                    .cornerRadius(12)
            }
            .padding()
        }
    }
    
    private func timerView(for step: RecipeStep, minutes: Int) -> some View {
        VStack(spacing: 16) {
            if let timerState = activeTimers[step.id] {
                Text(timeString(from: timerState.remainingSeconds))
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .foregroundColor(timerState.remainingSeconds <= 10 ? .red : .white)
                    .monospacedDigit()
                
                HStack(spacing: 16) {
                    Button(action: { toggleTimer(for: step) }) {
                        Image(systemName: timerState.isRunning ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                    }
                    
                    Button(action: { resetTimer(for: step) }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                    }
                }
            } else {
                Button(action: { startTimer(for: step, minutes: minutes) }) {
                    VStack {
                        Image(systemName: "timer")
                            .font(.system(size: 40))
                        Text("Start \(minutes)min Timer")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func startTimer(for step: RecipeStep, minutes: Int) {
        let totalSeconds = minutes * 60
        activeTimers[step.id] = TimerState(
            totalSeconds: totalSeconds,
            remainingSeconds: totalSeconds,
            isRunning: true,
            timer: nil
        )
        
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if var state = activeTimers[step.id] {
                state.remainingSeconds -= 1
                if state.remainingSeconds <= 0 {
                    state.isRunning = false
                    state.timer?.invalidate()
                    state.timer = nil
                    lightHaptic()
                }
                activeTimers[step.id] = state
            }
        }
        
        activeTimers[step.id]?.timer = timer
    }
    
    private func toggleTimer(for step: RecipeStep) {
        if var state = activeTimers[step.id] {
            state.isRunning.toggle()
            if state.isRunning {
                let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                    if var state = activeTimers[step.id] {
                        state.remainingSeconds -= 1
                        if state.remainingSeconds <= 0 {
                            state.isRunning = false
                            state.timer?.invalidate()
                            state.timer = nil
                            lightHaptic()
                        }
                        activeTimers[step.id] = state
                    }
                }
                state.timer = timer
            } else {
                state.timer?.invalidate()
                state.timer = nil
            }
            activeTimers[step.id] = state
        }
    }
    
    private func resetTimer(for step: RecipeStep) {
        if var state = activeTimers[step.id] {
            state.timer?.invalidate()
            state.remainingSeconds = state.totalSeconds
            state.isRunning = false
            state.timer = nil
            activeTimers[step.id] = state
        }
    }
    
    private func stopAllTimers() {
        for (_, state) in activeTimers {
            state.timer?.invalidate()
        }
        activeTimers.removeAll()
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func loadSteps() {
        // Load steps from instructions
        if let instructions = recipe.instructions, !instructions.isEmpty {
            steps = [RecipeStep(instruction: instructions)]
        }
    }
    
    private func previousStep() {
        if currentStepIndex > 0 {
            currentStepIndex -= 1
        }
    }
    
    private func nextStep() {
        if currentStepIndex < steps.count - 1 {
            currentStepIndex += 1
        } else {
            dismiss()
        }
    }
}

// MARK: - Shopping List View
struct ShoppingListMainView: View {
    @AppStorage("shoppingListData") private var shoppingListData = ""
    @State private var shoppingItems: [ShoppingListItem] = []
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            List {
                ForEach($shoppingItems) { $item in
                    HStack {
                        Button(action: { item.isChecked.toggle(); saveList() }) {
                            Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(item.isChecked ? .green : .gray)
                        }
                        VStack(alignment: .leading) {
                            Text(item.name)
                                .font(.headline)
                            if !item.amount.isEmpty {
                                Text("\(item.amount) \(item.unit)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if let recipe = item.fromRecipe {
                            Text(recipe)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Shopping List")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAdd = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .onAppear(perform: loadList)
            .sheet(isPresented: $showingAdd) {
                AddShoppingItemView { item in
                    shoppingItems.append(item)
                    saveList()
                    showingAdd = false
                }
            }
        }
    }

    private func loadList() {
        if let data = shoppingListData.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([ShoppingListItem].self, from: data) {
            shoppingItems = decoded
        }
    }

    private func saveList() {
        if let encoded = try? JSONEncoder().encode(shoppingItems),
           let jsonString = String(data: encoded, encoding: .utf8) {
            shoppingListData = jsonString
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        shoppingItems.remove(atOffsets: offsets)
        saveList()
    }
}

struct AddShoppingItemView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (ShoppingListItem) -> Void
    
    @State private var name = ""
    @State private var amount = ""
    @State private var unit = "unit"
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Item Name", text: $name)
                TextField("Amount", text: $amount)
                TextField("Unit", text: $unit)
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd(ShoppingListItem(name: name, amount: amount, unit: unit))
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Pantry Main View (Fridge + Spices)
struct PantryMainView: View {
    var body: some View {
        TabView {
            FridgeView()
                .tabItem { Label("Fridge", systemImage: "refrigerator.fill") }
            
            SpiceCabinetView()
                .tabItem { Label("Spices", systemImage: "leaf.fill") }
        }
    }
}

// MARK: - Fridge View
struct FridgeView: View {
    @AppStorage("fridgeData") private var fridgeData = ""
    @State private var items: [PantryItem] = []
    @State private var showingAdd = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    VStack(alignment: .leading) {
                        Text(item.name)
                            .font(.headline)
                        HStack {
                            Text("\(item.quantity) \(item.unit)")
                            if let exp = item.expirationDate {
                                Text("• Expires \(exp, style: .date)")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("What's in My Fridge")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAdd = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .onAppear(perform: loadData)
            .sheet(isPresented: $showingAdd) {
                AddPantryItemView(category: .fridge) { item in
                    items.append(item)
                    saveData()
                    showingAdd = false
                }
            }
        }
    }
    
    private func loadData() {
        if let data = fridgeData.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([PantryItem].self, from: data) {
            items = decoded
        }
    }
    
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(items),
           let jsonString = String(data: encoded, encoding: .utf8) {
            fridgeData = jsonString
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        saveData()
    }
}

// MARK: - Spice Cabinet View
struct SpiceCabinetView: View {
    @AppStorage("spiceData") private var spiceData = ""
    @State private var spices: [PantryItem] = []
    @State private var showingAdd = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(spices) { spice in
                    VStack(alignment: .leading) {
                        Text(spice.name)
                            .font(.headline)
                        if !spice.quantity.isEmpty {
                            Text("\(spice.quantity) \(spice.unit)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Spice Cabinet")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingAdd = true }) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .onAppear(perform: loadData)
            .sheet(isPresented: $showingAdd) {
                AddPantryItemView(category: .spices) { spice in
                    spices.append(spice)
                    saveData()
                    showingAdd = false
                }
            }
        }
    }
    
    private func loadData() {
        if let data = spiceData.data(using: .utf8),
           let decoded = try? JSONDecoder().decode([PantryItem].self, from: data) {
            spices = decoded
        }
    }
    
    private func saveData() {
        if let encoded = try? JSONEncoder().encode(spices),
           let jsonString = String(data: encoded, encoding: .utf8) {
            spiceData = jsonString
        }
    }
    
    private func deleteItems(at offsets: IndexSet) {
        spices.remove(atOffsets: offsets)
        saveData()
    }
}

// MARK: - Add Pantry Item View (Reusable)
struct AddPantryItemView: View {
    @Environment(\.dismiss) private var dismiss
    let category: PantryCategory
    let onAdd: (PantryItem) -> Void
    
    @State private var name = ""
    @State private var quantity = ""
    @State private var unit = ""
    @State private var expirationDate = Date()
    @State private var hasExpiration = false
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Item Info") {
                    TextField("Name", text: $name)
                    TextField("Quantity", text: $quantity)
                    TextField("Unit", text: $unit)
                }
                Section("Expiration") {
                    Toggle("Has Expiration Date", isOn: $hasExpiration)
                    if hasExpiration {
                        DatePicker("Expires On", selection: $expirationDate, displayedComponents: .date)
                    }
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("Add \(category.rawValue) Item")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let item = PantryItem(
                            name: name,
                            quantity: quantity,
                            unit: unit,
                            category: category,
                            expirationDate: hasExpiration ? expirationDate : nil,
                            notes: notes
                        )
                        onAdd(item)
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}