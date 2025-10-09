//
//  RecipeViews.swift
//  Slate
//
//  Created by UI Overhaul on 9/29/25.
//

import SwiftUI
import SwiftData

// MARK: - Ultra-Modern Recipe Views

// MARK: - Modern Recipe Main View
struct ModernRecipeMainView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sharedState: SharedStateManager
    
    @Query(sort: \Recipe.createdDate, order: .reverse) private var allRecipes: [Recipe]
    @Query(sort: \FridgeItem.createdDate, order: .reverse) private var allFridgeItems: [FridgeItem]
    @Query(sort: \SpiceItem.createdDate, order: .reverse) private var allSpiceItems: [SpiceItem]
    @Query(sort: \CartItem.createdDate, order: .reverse) private var allCartItems: [CartItem]
    
    @State private var selectedTab: RecipeTab = .recipes
    @State private var selectedCategory: RecipeCategory = .breakfast
    @State private var searchText = ""
    @State private var showingAddRecipe = false
    @State private var showingCategoryMenu = false
    
    enum RecipeTab: String, CaseIterable {
        case recipes = "Recipes"
        case fridge = "Fridge"
        case spices = "Spices"
        case cart = "Shopping Cart"
        
        var icon: String {
            switch self {
            case .recipes: return "fork.knife"
            case .fridge: return "refrigerator"
            case .spices: return "leaf"
            case .cart: return "cart"
            }
        }
        
        var color: Color {
            switch self {
            case .recipes: return .blue
            case .fridge: return .cyan
            case .spices: return .orange
            case .cart: return .green
            }
        }
    }
    
    // Computed properties - optimized since queries are already sorted
    private var filteredRecipes: [Recipe] {
        // Filter by category first (more efficient)
        let categoryRecipes = allRecipes.lazy.filter { $0.category == selectedCategory.rawValue }
        
        if searchText.isEmpty {
            return Array(categoryRecipes) // Already sorted by query
        } else {
            let searchLower = searchText.lowercased()
            return categoryRecipes.filter { recipe in
                recipe.name.lowercased().contains(searchLower) ||
                recipe.instructions.lowercased().contains(searchLower)
            } // Already sorted by query
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Recipes")
                            .font(DesignSystem.Typography.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text(selectedTab == .recipes ? "Discover and create amazing dishes" : 
                             selectedTab == .fridge ? "Manage your fridge contents" :
                             selectedTab == .spices ? "Organize your spice collection" :
                             "Track your shopping list")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    if selectedTab == .recipes {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            // Category hamburger menu button
                            Button(action: { showingCategoryMenu.toggle() }) {
                                ZStack {
                                    Circle()
                                        .fill(DesignSystem.Colors.backgroundTertiary)
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "line.3.horizontal")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                        .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Add recipe button
                    Button(action: { showingAddRecipe = true }) {
                        ZStack {
                            Circle()
                                .fill(DesignSystem.Colors.accent)
                                .frame(width: 44, height: 44)
                            
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                // Search bar (only for recipes)
                if selectedTab == .recipes {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    TextField("Search recipes...", text: $searchText)
                        .font(DesignSystem.Typography.body)
                            .textFieldStyle(.plain)
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(DesignSystem.Colors.backgroundTertiary)
                )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.lg)
            
            // Main navigation tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(RecipeTab.allCases, id: \.self) { tab in
                        ModernRecipeTabButton(
                            tab: tab,
                            isSelected: selectedTab == tab,
                            action: { selectedTab = tab }
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .padding(.vertical, DesignSystem.Spacing.md)
            
            // Content based on selected tab
            Group {
                switch selectedTab {
                case .recipes:
                    RecipeContentView(
                        filteredRecipes: filteredRecipes,
                        selectedCategory: selectedCategory,
                        searchText: $searchText,
                        selectedCategoryBinding: $selectedCategory
                    )
                case .fridge:
                    FridgeContentView(allFridgeItems: allFridgeItems)
                case .spices:
                    SpicesContentView(allSpiceItems: allSpiceItems)
                case .cart:
                    ShoppingCartContentView(allCartItems: allCartItems)
                }
            }
        }
        .background(DesignSystem.Colors.background)
        .sheet(isPresented: $showingAddRecipe) {
            ModernAddRecipeView(category: selectedCategory)
        }
        .sheet(isPresented: $showingCategoryMenu) {
            RecipeCategoryMenuView(
                selectedCategory: $selectedCategory,
                filteredRecipes: filteredRecipes
            )
        }
        .loadingOverlay(loadingManager: sharedState.loadingManager)
    }
}

// MARK: - Modern Recipe Tab Button
struct ModernRecipeTabButton: View {
    let tab: ModernRecipeMainView.RecipeTab
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: tab.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : tab.color)
                
                Text(tab.rawValue)
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(isSelected ? tab.color : DesignSystem.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .stroke(isSelected ? tab.color.opacity(0.3) : DesignSystem.Colors.textTertiary, lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Recipe Content View
struct RecipeContentView: View {
    let filteredRecipes: [Recipe]
    let selectedCategory: RecipeCategory
    @Binding var searchText: String
    @Binding var selectedCategoryBinding: RecipeCategory
    
    var body: some View {
        VStack(spacing: 0) {
            // Recipes content
            if filteredRecipes.isEmpty {
                ModernEmptyRecipesView(category: selectedCategory)
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(filteredRecipes, id: \.id) { recipe in
                            ModernRecipeCard(recipe: recipe)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
        }
    }
}

// MARK: - Modern Recipe Category Tab
struct ModernRecipeCategoryTab: View {
    let category: RecipeCategory
    let isSelected: Bool
    let recipeCount: Int
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : category.color)
                
                Text(category.rawValue)
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
                
                if recipeCount > 0 {
                    Text("\(recipeCount)")
                        .font(DesignSystem.Typography.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : DesignSystem.Colors.textSecondary)
                        .padding(.horizontal, DesignSystem.Spacing.xs)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs)
                                .fill(isSelected ? Color.white.opacity(0.2) : DesignSystem.Colors.backgroundTertiary)
                        )
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(isSelected ? category.color : DesignSystem.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .stroke(isSelected ? category.color.opacity(0.3) : DesignSystem.Colors.textTertiary, lineWidth: 1)
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Modern Recipe Card
struct ModernRecipeCard: View {
    let recipe: Recipe
    @State private var isHovered = false
    @State private var showingEditSheet = false
    @State private var showingImagePicker = false
    @State private var showingDetail = false
    @State private var selectedImage: UIImage?
    
    var body: some View {
        Button(action: { showingDetail = true }) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Recipe Image
            ZStack {
                if let image = recipe.image {
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(DesignSystem.Colors.backgroundTertiary)
                        .frame(height: 200)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 40))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        )
                }
                
                // Edit buttons overlay
                VStack {
                    HStack {
                        Spacer()
                        Button(action: { showingImagePicker = true }) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(
                                    Circle()
                                        .fill(Color.black.opacity(0.6))
                                )
                        }
                    }
                    Spacer()
                }
                .padding(DesignSystem.Spacing.sm)
            }
            .cornerRadius(DesignSystem.CornerRadius.md)
            
            // Recipe Info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Text(recipe.name)
                        .font(DesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineLimit(2)
                    
                    Spacer()
                    
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        if recipe.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.yellow)
                        }
                        
                        Button(action: { showingEditSheet = true }) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16))
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onTapGesture { }
                    }
                }
                
                // Recipe details
                if !recipe.servings.isEmpty || !recipe.cookingTime.isEmpty {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        if !recipe.servings.isEmpty {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "person.2")
                                    .font(.system(size: 12))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Text(recipe.servings)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                        
                        if !recipe.cookingTime.isEmpty {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                Text(recipe.cookingTime)
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                // Ingredients preview
                Text("\(recipe.ingredients?.count ?? 0) ingredients")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                // Recipe preview
                if !recipe.instructions.isEmpty {
                    Text(recipe.instructions)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                .fill(DesignSystem.Colors.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                )
        )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditRecipeView(recipe: recipe)
        }
        .sheet(isPresented: $showingImagePicker) {
            RecipeImagePicker(selectedImage: $selectedImage, recipe: recipe)
        }
        .sheet(isPresented: $showingDetail) {
            NavigationView {
                ModernRecipeDetailView(recipe: recipe)
            }
        }
    }
}

// MARK: - Modern Empty Recipes View
struct ModernEmptyRecipesView: View {
    let category: RecipeCategory
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(category.color.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: category.icon)
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(category.color)
            }
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("No \(category.rawValue.lowercased()) recipes yet")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Add your first \(category.rawValue.lowercased()) recipe to get started")
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xl)
    }
}

// MARK: - Enhanced Modern Add Recipe View
struct ModernAddRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loadingManager = LoadingStateManager()
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    let category: RecipeCategory
    @State private var selectedCategory: RecipeCategory
    @State private var currentStep: RecipeInputStep = .basicInfo
    @State private var recipeName = ""
    @State private var servings = "4"
    @State private var cookingTime = ""
    @State private var difficulty: RecipeDifficulty = .medium
    @State private var instructions = ""
    @State private var ingredients: [RecipeIngredient] = []
    @State private var newIngredientQuantity = ""
    @State private var newIngredientUnit = ""
    @State private var newIngredientItem = ""
    @State private var showingIngredientSuggestions = false
    @State private var showingCategoryMenu = false
    @State private var recipePreview = ""
    
    init(category: RecipeCategory) {
        self.category = category
        self._selectedCategory = State(initialValue: category)
    }
    
    enum RecipeInputStep: Int, CaseIterable {
        case basicInfo = 0
        case ingredients = 1
        case instructions = 2
        case review = 3
        
        var title: String {
            switch self {
            case .basicInfo: return "Basic Info"
            case .ingredients: return "Ingredients"
            case .instructions: return "Instructions"
            case .review: return "Review"
            }
        }
        
        var icon: String {
            switch self {
            case .basicInfo: return "info.circle"
            case .ingredients: return "list.bullet"
            case .instructions: return "text.alignleft"
            case .review: return "checkmark.circle"
            }
        }
    }
    
    enum RecipeDifficulty: String, CaseIterable {
        case easy = "Easy"
        case medium = "Medium"
        case hard = "Hard"
        
        var color: Color {
            switch self {
            case .easy: return .green
            case .medium: return .orange
            case .hard: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .easy: return "1.circle"
            case .medium: return "2.circle"
            case .hard: return "3.circle"
            }
        }
    }
    
    private var progressPercentage: Double {
        return Double(currentStep.rawValue) / Double(RecipeInputStep.allCases.count - 1)
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case .basicInfo:
            return !recipeName.isEmpty && !servings.isEmpty
        case .ingredients:
            return !ingredients.isEmpty
        case .instructions:
            return !instructions.isEmpty
        case .review:
            return true
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Enhanced Header with Progress
                VStack(spacing: DesignSystem.Spacing.md) {
                    // Category Header
                    HStack {
                        ZStack {
                            Circle()
                                .fill(category.color.opacity(0.1))
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: category.icon)
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(category.color)
                                .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                        }
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Create \(category.rawValue) Recipe")
                            .font(DesignSystem.Typography.title1)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                            Text("Step \(currentStep.rawValue + 1) of \(RecipeInputStep.allCases.count)")
                                .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                        
                        Spacer()
                    }
                    
                    // Progress Bar
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            ForEach(RecipeInputStep.allCases, id: \.rawValue) { step in
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    ZStack {
                                        Circle()
                                            .fill(step.rawValue <= currentStep.rawValue ? category.color : DesignSystem.Colors.backgroundTertiary)
                                            .frame(width: 32, height: 32)
                                        
                                        Image(systemName: step.rawValue < currentStep.rawValue ? "checkmark" : step.icon)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(step.rawValue <= currentStep.rawValue ? .white : DesignSystem.Colors.textTertiary)
                                    }
                                    
                                    if step != RecipeInputStep.allCases.last {
                                        Rectangle()
                                            .fill(step.rawValue < currentStep.rawValue ? category.color : DesignSystem.Colors.backgroundTertiary)
                                            .frame(height: 2)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }
                        
                        Text(currentStep.title)
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.medium)
                            .foregroundColor(category.color)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .fill(DesignSystem.Colors.surface)
                        .shadow(color: DesignSystem.Shadows.medium, radius: 8, x: 0, y: 4)
                )
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.md)
                
                // Content Area
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        switch currentStep {
                        case .basicInfo:
                            BasicInfoStepView(
                                recipeName: $recipeName,
                                servings: $servings,
                                cookingTime: $cookingTime,
                                difficulty: $difficulty,
                                selectedCategory: $selectedCategory,
                                showingCategoryMenu: $showingCategoryMenu
                            )
                        case .ingredients:
                            IngredientsStepView(
                                ingredients: $ingredients,
                                newIngredientQuantity: $newIngredientQuantity,
                                newIngredientUnit: $newIngredientUnit,
                                newIngredientItem: $newIngredientItem,
                                showingSuggestions: $showingIngredientSuggestions
                            )
                        case .instructions:
                            InstructionsStepView(
                                instructions: $instructions,
                                recipeName: recipeName,
                                ingredients: ingredients
                            )
                        case .review:
                            ReviewStepView(
                                recipeName: recipeName,
                                servings: servings,
                                cookingTime: cookingTime,
                                difficulty: difficulty,
                                ingredients: ingredients,
                                instructions: instructions,
                                category: category
                            )
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                }
                
                // Navigation Buttons
                HStack(spacing: DesignSystem.Spacing.md) {
                    if currentStep != .basicInfo {
                        Button(action: previousStep) {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                    .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                                Text("Previous")
                                    .font(DesignSystem.Typography.callout)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .fill(DesignSystem.Colors.backgroundTertiary)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    Spacer()
                    
                    Button(action: nextStep) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Text(currentStep == .review ? "Save Recipe" : "Next")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.semibold)
                            if currentStep != .review {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 16, weight: .semibold))
                                    .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                            }
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(canProceed ? category.color : DesignSystem.Colors.backgroundTertiary)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!canProceed)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
        }
        .sheet(isPresented: $showingCategoryMenu) {
            RecipeCategoryMenuView(
                selectedCategory: $selectedCategory,
                filteredRecipes: []
            )
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
    
    private func nextStep() {
        if currentStep == .review {
            saveRecipe()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep = RecipeInputStep(rawValue: currentStep.rawValue + 1) ?? .review
            }
        }
    }
    
    private func previousStep() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = RecipeInputStep(rawValue: currentStep.rawValue - 1) ?? .basicInfo
        }
    }
    
    private func saveRecipe() {
        loadingManager.startLoading(message: "Saving recipe...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let newRecipe = Recipe(
                name: recipeName.trimmingCharacters(in: .whitespacesAndNewlines),
                instructions: instructions.trimmingCharacters(in: .whitespacesAndNewlines),
                category: selectedCategory.rawValue
            )
            
            // Add additional recipe details
            newRecipe.servings = servings.trimmingCharacters(in: .whitespacesAndNewlines)
            newRecipe.cookingTime = cookingTime.trimmingCharacters(in: .whitespacesAndNewlines)
            newRecipe.difficulty = difficulty.rawValue
            
            // Insert recipe first
            modelContext.insert(newRecipe)
            
            // Add ingredients to recipe - INSERT EACH INGREDIENT
            for ingredient in ingredients {
                ingredient.recipe = newRecipe
                modelContext.insert(ingredient)
                newRecipe.ingredients?.append(ingredient)
            }
            
            modelContext.saveWithDebounce(using: autoSaveManager)
            loadingManager.stopLoading()
            dismiss()
        }
    }
}

// MARK: - Recipe Step Views


// MARK: - Ingredients Step View
struct IngredientsStepView: View {
    @Binding var ingredients: [RecipeIngredient]
    @Binding var newIngredientQuantity: String
    @Binding var newIngredientUnit: String
    @Binding var newIngredientItem: String
    @Binding var showingSuggestions: Bool
    
    @State private var commonUnits = ["cups", "tbsp", "tsp", "oz", "lb", "g", "ml", "piece", "clove", "slice"]
    @State private var commonIngredients = ["flour", "sugar", "salt", "pepper", "oil", "butter", "eggs", "milk", "cheese", "onion", "garlic", "tomato", "carrot", "potato"]
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Header
            HStack {
                            Text("Ingredients")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                Spacer()
                
                Text("\(ingredients.count) items")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs)
                            .fill(DesignSystem.Colors.backgroundTertiary)
                    )
            }
            
            // Ingredients List
            if !ingredients.isEmpty {
                LazyVStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(ingredients, id: \.id) { ingredient in
                                    HStack {
                            // Quantity and Unit
                            HStack(spacing: 4) {
                                        Text(ingredient.quantity)
                                    .font(DesignSystem.Typography.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                
                                if !ingredient.item.isEmpty {
                                    Text("•")
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                            }
                            .frame(width: 80, alignment: .leading)
                                        
                            // Ingredient Name
                                        Text(ingredient.item)
                                            .font(DesignSystem.Typography.body)
                                            .foregroundColor(DesignSystem.Colors.textPrimary)
                                        
                                        Spacer()
                                        
                            // Remove Button
                                        Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                            ingredients.removeAll { $0.id == ingredient.id }
                                }
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 20))
                                                .foregroundColor(.red)
                                        }
                                    }
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(DesignSystem.Colors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                )
                        )
                    }
                }
            }
            
            // Add Ingredient Section
            VStack(spacing: DesignSystem.Spacing.md) {
                                HStack {
                    Text("Add Ingredient")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                }
                
                VStack(spacing: DesignSystem.Spacing.sm) {
                    // Simple ingredient input with optional quantity
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        // Optional quantity field (smaller)
                        TextField("2", text: $newIngredientQuantity)
                            .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                            .frame(width: 60)
                            .keyboardType(.decimalPad)
                            .onTapGesture {
                                // Add keyboard dismissal
                            }
                        
                        // Optional unit field (smaller)
                        TextField("cups", text: $newIngredientUnit)
                            .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                            .frame(width: 80)
                            .onTapGesture {
                                // Add keyboard dismissal
                            }
                        
                        // Main ingredient name field
                        TextField("Ingredient name (required)", text: $newIngredientItem)
                            .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                            .onTapGesture {
                                // Add keyboard dismissal
                            }
                    }
                                    
                    // Common Ingredients Quick Add
                    if !commonIngredients.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(commonIngredients, id: \.self) { ingredient in
                                    Button(action: {
                                        newIngredientItem = ingredient
                                    }) {
                                        Text(ingredient)
                                            .font(DesignSystem.Typography.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                            .padding(.horizontal, DesignSystem.Spacing.sm)
                                            .padding(.vertical, DesignSystem.Spacing.xs)
                                            .background(
                                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                                    .fill(DesignSystem.Colors.backgroundTertiary)
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, DesignSystem.Spacing.md)
                        }
                    }
                    
                    // Add Button
                    Button(action: addIngredient) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Add Ingredient")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(canAddIngredient ? DesignSystem.Colors.accent : DesignSystem.Colors.backgroundTertiary)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!canAddIngredient)
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .fill(DesignSystem.Colors.backgroundTertiary)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                .stroke(DesignSystem.Colors.border, lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private var canAddIngredient: Bool {
        return !newIngredientItem.isEmpty
    }
    
    private func addIngredient() {
        guard canAddIngredient else { return }
        
        // Create quantity text - if both quantity and unit are empty, use "As needed"
        let quantityText: String
        if newIngredientQuantity.isEmpty && newIngredientUnit.isEmpty {
            quantityText = "As needed"
        } else if newIngredientQuantity.isEmpty {
            quantityText = newIngredientUnit
        } else if newIngredientUnit.isEmpty {
            quantityText = newIngredientQuantity
        } else {
            quantityText = "\(newIngredientQuantity) \(newIngredientUnit)"
        }
        
        let newIngredient = RecipeIngredient(
            quantity: quantityText,
            item: newIngredientItem.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        withAnimation(.easeInOut(duration: 0.2)) {
            ingredients.append(newIngredient)
        }
        
        // Clear fields
        newIngredientQuantity = ""
        newIngredientUnit = ""
        newIngredientItem = ""
    }
}

// MARK: - Basic Info Step View
struct BasicInfoStepView: View {
    @Binding var recipeName: String
    @Binding var servings: String
    @Binding var cookingTime: String
    @Binding var difficulty: ModernAddRecipeView.RecipeDifficulty
    @Binding var selectedCategory: RecipeCategory
    @Binding var showingCategoryMenu: Bool
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Recipe Name
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Recipe Name")
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                TextField("Enter recipe name", text: $recipeName)
                    .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
            }
            
            // Servings and Cooking Time
            HStack(spacing: DesignSystem.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Servings")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    TextField("4", text: $servings)
                        .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                        .keyboardType(.numberPad)
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Cooking Time")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    TextField("30 min", text: $cookingTime)
                        .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                }
            }
            
            // Difficulty Level
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Difficulty")
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(ModernAddRecipeView.RecipeDifficulty.allCases, id: \.self) { level in
                        Button(action: { difficulty = level }) {
                            HStack(spacing: DesignSystem.Spacing.xs) {
                                Image(systemName: level.icon)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(level.rawValue)
                                    .font(DesignSystem.Typography.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(difficulty == level ? .white : level.color)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                    .fill(difficulty == level ? level.color : level.color.opacity(0.1))
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            
            // Category Selection Card
            Button(action: { showingCategoryMenu = true }) {
                HStack {
                    Image(systemName: selectedCategory.icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(selectedCategory.color)
                        .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Category")
                            .font(DesignSystem.Typography.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text(selectedCategory.rawValue)
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(selectedCategory.color.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .stroke(selectedCategory.color.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Instructions Step View
struct InstructionsStepView: View {
    @Binding var instructions: String
    let recipeName: String
    let ingredients: [RecipeIngredient]
    
    @State private var cookingSteps: [CookingStep] = []
    @State private var newStepText = ""
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Header
            HStack {
                Text("Cooking Instructions")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
                
                Text("\(cookingSteps.count) steps")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs)
                            .fill(DesignSystem.Colors.backgroundTertiary)
                    )
            }
            
            
            // Cooking Steps List
            if !cookingSteps.isEmpty {
                LazyVStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(cookingSteps, id: \.id) { step in
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
                            // Step Number
                            ZStack {
                                Circle()
                                    .fill(DesignSystem.Colors.accent)
                                    .frame(width: 32, height: 32)
                                
                                Text("\(step.order)")
                                    .font(DesignSystem.Typography.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                            
                            // Step Text
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text(step.text)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                    .lineLimit(nil)
                                
                                if let duration = step.duration, !duration.isEmpty {
                                    HStack(spacing: DesignSystem.Spacing.xs) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 12))
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                        Text(duration)
                                            .font(DesignSystem.Typography.caption)
                                            .foregroundColor(DesignSystem.Colors.textSecondary)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            // Remove Button
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    removeStep(step)
                                }
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(DesignSystem.Colors.surface)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                )
                        )
                    }
                }
            }
            
            // Add New Step Section
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    Text("Add Cooking Step")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                }
                
                VStack(spacing: DesignSystem.Spacing.sm) {
                    TextField("Enter cooking step", text: $newStepText)
                        .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                    
                    // Add Button
                    Button(action: addStep) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Add Step")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(canAddStep ? DesignSystem.Colors.accent : DesignSystem.Colors.backgroundTertiary)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .disabled(!canAddStep)
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .fill(DesignSystem.Colors.backgroundTertiary)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                .stroke(DesignSystem.Colors.border, lineWidth: 1)
                        )
                )
            }
            
            // Instructions Text (Fallback)
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Text("Full Instructions (Optional)")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    if !instructions.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.green)
                    }
                }
                
                TextEditor(text: $instructions)
                    .font(DesignSystem.Typography.body)
                    .frame(minHeight: 100)
                    .padding(DesignSystem.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .fill(DesignSystem.Colors.background)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
                            )
                    )
            }
        }
        .onAppear {
            // Convert existing instructions to steps if they exist
            if !instructions.isEmpty && cookingSteps.isEmpty {
                convertInstructionsToSteps()
            }
        }
        .onChange(of: cookingSteps) { oldValue, newValue in
            // Update the instructions text with the steps
            updateInstructionsFromSteps()
        }
    }
    
    private var canAddStep: Bool {
        return !newStepText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func addStep() {
        guard canAddStep else { return }
        
        let newStep = CookingStep(
            order: cookingSteps.count + 1,
            text: newStepText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        withAnimation(.easeInOut(duration: 0.2)) {
            cookingSteps.append(newStep)
        }
        
        newStepText = ""
    }
    
    private func addQuickStep(_ stepText: String) {
        let newStep = CookingStep(
            order: cookingSteps.count + 1,
            text: stepText
        )
        
        withAnimation(.easeInOut(duration: 0.2)) {
            cookingSteps.append(newStep)
        }
    }
    
    private func removeStep(_ step: CookingStep) {
        cookingSteps.removeAll { $0.id == step.id }
        // Reorder remaining steps
        for index in cookingSteps.indices {
            cookingSteps[index].order = index + 1
        }
    }
    
    private func convertInstructionsToSteps() {
        let lines = instructions.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        cookingSteps = lines.enumerated().map { index, line in
            CookingStep(order: index + 1, text: line)
        }
    }
    
    private func updateInstructionsFromSteps() {
        if !cookingSteps.isEmpty {
            instructions = cookingSteps
                .sorted { $0.order < $1.order }
                .map { "\($0.order). \($0.text)" }
                .joined(separator: "\n\n")
        }
    }
}

// MARK: - Review Step View
struct ReviewStepView: View {
    let recipeName: String
    let servings: String
    let cookingTime: String
    let difficulty: ModernAddRecipeView.RecipeDifficulty
    let ingredients: [RecipeIngredient]
    let instructions: String
    let category: RecipeCategory
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Recipe Header
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(category.color.opacity(0.1))
                            .frame(width: 60, height: 60)
                        
                        Image(systemName: category.icon)
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(category.color)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(recipeName)
                            .font(DesignSystem.Typography.title1)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text(category.rawValue)
                            .font(DesignSystem.Typography.callout)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                    Spacer()
                }
                
                // Recipe Stats
                HStack(spacing: DesignSystem.Spacing.lg) {
                    StatItem(icon: "person.2", value: servings, label: "Servings")
                    StatItem(icon: "clock", value: cookingTime, label: "Time")
                    StatItem(icon: difficulty.icon, value: difficulty.rawValue, label: "Difficulty", color: difficulty.color)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.surface)
                    .shadow(color: DesignSystem.Shadows.medium, radius: 8, x: 0, y: 4)
            )
            
            // Ingredients Summary
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Text("Ingredients (\(ingredients.count))")
                        .font(DesignSystem.Typography.title2)
                    .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                }
                
                LazyVStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(ingredients, id: \.id) { ingredient in
                        HStack {
                            Text(ingredient.quantity)
                                .font(DesignSystem.Typography.body)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .frame(width: 80, alignment: .leading)
                            
                            Text(ingredient.item)
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Spacer()
                        }
                        .padding(DesignSystem.Spacing.sm)
                    }
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                    .fill(DesignSystem.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
            )
            
            // Instructions Summary
            if !instructions.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Text("Instructions")
                            .font(DesignSystem.Typography.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Spacer()
                    }
                    
                    Text(instructions)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineSpacing(4)
                }
                .padding(DesignSystem.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                        .fill(DesignSystem.Colors.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                .stroke(DesignSystem.Colors.border, lineWidth: 1)
                        )
                )
            }
        }
    }
}

// MARK: - Stat Item Helper View
struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    init(icon: String, value: String, label: String, color: Color = DesignSystem.Colors.textSecondary) {
        self.icon = icon
        self.value = value
        self.label = label
        self.color = color
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(color)
                .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
            
            Text(value)
                .font(DesignSystem.Typography.callout)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Cooking Step Model
struct CookingStep: Identifiable, Equatable {
    let id = UUID()
    var order: Int
    var text: String
    var duration: String? = nil
    
    static func == (lhs: CookingStep, rhs: CookingStep) -> Bool {
        return lhs.id == rhs.id && lhs.order == rhs.order && lhs.text == rhs.text && lhs.duration == rhs.duration
    }
}

// MARK: - Modern Recipe Detail View
struct ModernRecipeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loadingManager = LoadingStateManager()
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    let recipe: Recipe
    @State private var showingAddToCart = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Recipe header
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text(recipe.name)
                                .font(DesignSystem.Typography.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Text(recipe.category)
                                .font(DesignSystem.Typography.callout)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            toggleFavorite()
                        }) {
                            Image(systemName: recipe.isFavorite ? "star.fill" : "star")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(recipe.isFavorite ? .yellow : DesignSystem.Colors.textSecondary)
                        }
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .minimalistCard(.outlined)
                
                // Ingredients section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Text("Ingredients")
                            .font(DesignSystem.Typography.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Spacer()
                        
                        Button("Add to Cart") {
                            showingAddToCart = true
                        }
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.accent)
                    }
                    
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(recipe.ingredients ?? [], id: \.id) { ingredient in
                            ModernIngredientRow(ingredient: ingredient)
                        }
                    }
                }
                .padding(DesignSystem.Spacing.lg)
                .minimalistCard(.outlined)
                
                // Instructions section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Instructions")
                        .font(DesignSystem.Typography.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text(recipe.instructions)
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .lineSpacing(4)
                }
                .padding(DesignSystem.Spacing.lg)
                .minimalistCard(.outlined)
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .background(DesignSystem.Colors.background)
        .navigationBarTitleDisplayMode(.inline)
        .alert("Add to Shopping Cart", isPresented: $showingAddToCart) {
            Button("Add All Ingredients") {
                addAllIngredientsToCart()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Add all missing ingredients to your shopping cart?")
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
    
    private func toggleFavorite() {
        recipe.isFavorite.toggle()
        modelContext.saveWithDebounce(using: autoSaveManager)
    }
    
    private func addAllIngredientsToCart() {
        loadingManager.startLoading(message: "Adding to cart...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            for ingredient in recipe.ingredients ?? [] {
                let cartItem = CartItem(
                    name: ingredient.item,
                    quantity: ingredient.quantity
                )
                modelContext.insert(cartItem)
            }
            
            modelContext.saveWithDebounce(using: autoSaveManager)
            loadingManager.stopLoading()
        }
    }
}

// MARK: - Modern Ingredient Row
struct ModernIngredientRow: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var autoSaveManager = AutoSaveManager()
    @StateObject private var loadingManager = LoadingStateManager()
    
    let ingredient: RecipeIngredient
    @State private var showingAddedConfirmation = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(ingredient.item)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(ingredient.quantity)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            Button(action: addToCart) {
                Image(systemName: showingAddedConfirmation ? "checkmark.circle.fill" : "cart.badge.plus")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(showingAddedConfirmation ? .green : DesignSystem.Colors.accent)
                    .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(DesignSystem.Spacing.md)
        .minimalistCard(.outlined)
    }
    
    private func addToCart() {
        loadingManager.startLoading(message: "Adding to cart...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let cartItem = CartItem(
                name: ingredient.item,
                quantity: ingredient.quantity
            )
            modelContext.insert(cartItem)
            modelContext.saveWithDebounce(using: autoSaveManager)
            
            withAnimation {
                showingAddedConfirmation = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    showingAddedConfirmation = false
                }
            }
            
            loadingManager.stopLoading()
        }
    }
}

// MARK: - Fridge Content View
struct FridgeContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loadingManager = LoadingStateManager()
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    let allFridgeItems: [FridgeItem]
    @State private var showingAddItem = false
    @State private var newItemName = ""
    @State private var newItemQuantity = ""
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            if allFridgeItems.isEmpty {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    ZStack {
                        Circle()
                            .fill(Color.cyan.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "refrigerator")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(.cyan)
                    }
                    
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Text("Your fridge is empty")
                            .font(DesignSystem.Typography.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Add items to track what's in your fridge")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: { showingAddItem = true }) {
                        Text("Add First Item")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .fill(Color.cyan)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(DesignSystem.Spacing.xl)
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(allFridgeItems, id: \.id) { item in
                            FridgeItemRow(item: item)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
                
                // Add button
                HStack {
                    Spacer()
                    Button(action: { showingAddItem = true }) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Add Item")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(Color.cyan)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            }
        }
        .background(DesignSystem.Colors.background)
        .sheet(isPresented: $showingAddItem) {
            AddFridgeItemView()
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
}

// MARK: - Fridge Item Row
struct FridgeItemRow: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    let item: FridgeItem
    @State private var showingEdit = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(item.name)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Qty: \(item.quantity)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            Button(action: { showingEdit = true }) {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.accent)
                    .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
            }
            
            Button(action: deleteItem) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .minimalistCard(.outlined)
        .sheet(isPresented: $showingEdit) {
            EditFridgeItemView(item: item)
        }
    }
    
    private func deleteItem() {
        modelContext.delete(item)
        modelContext.saveWithDebounce(using: autoSaveManager)
    }
}

// MARK: - Add Fridge Item View
struct AddFridgeItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loadingManager = LoadingStateManager()
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    @State private var itemName = ""
    @State private var itemQuantity = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Item Name")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    TextField("Enter item name", text: $itemName)
                        .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Quantity")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    TextField("Enter quantity", text: $itemQuantity)
                        .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                }
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.xl)
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveItem()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.accent)
                    .disabled(itemName.isEmpty)
                }
            }
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
    
    private func saveItem() {
        loadingManager.startLoading(message: "Saving item...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let newItem = FridgeItem(
                name: itemName.trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: itemQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            modelContext.insert(newItem)
            modelContext.saveWithDebounce(using: autoSaveManager)
            loadingManager.stopLoading()
            dismiss()
        }
    }
}

// MARK: - Edit Fridge Item View
struct EditFridgeItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loadingManager = LoadingStateManager()
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    let item: FridgeItem
    @State private var itemName: String
    @State private var itemQuantity: String
    
    init(item: FridgeItem) {
        self.item = item
        self._itemName = State(initialValue: item.name)
        self._itemQuantity = State(initialValue: item.quantity)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Item Name")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    TextField("Enter item name", text: $itemName)
                        .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Quantity")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    TextField("Enter quantity", text: $itemQuantity)
                        .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                }
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.xl)
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.accent)
                    .disabled(itemName.isEmpty)
                }
            }
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
    
    private func saveChanges() {
        loadingManager.startLoading(message: "Saving changes...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            item.name = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
            item.quantity = itemQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
            
            modelContext.saveWithDebounce(using: autoSaveManager)
            loadingManager.stopLoading()
            dismiss()
        }
    }
}

// MARK: - Spices Content View
struct SpicesContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loadingManager = LoadingStateManager()
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    let allSpiceItems: [SpiceItem]
    @State private var showingAddSpice = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            if allSpiceItems.isEmpty {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "leaf")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(.orange)
                    }
                    
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Text("No spices yet")
                            .font(DesignSystem.Typography.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Add spices to organize your collection")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: { showingAddSpice = true }) {
                        Text("Add First Spice")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .fill(Color.orange)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(DesignSystem.Spacing.xl)
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(allSpiceItems, id: \.id) { spice in
                            SpiceItemRow(spice: spice)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
                
                // Add button
                HStack {
                    Spacer()
                    Button(action: { showingAddSpice = true }) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Add Spice")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(Color.orange)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            }
        }
        .background(DesignSystem.Colors.background)
        .sheet(isPresented: $showingAddSpice) {
            AddSpiceItemView()
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
}

// MARK: - Spice Item Row
struct SpiceItemRow: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    let spice: SpiceItem
    @State private var showingEdit = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(spice.name)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text("Qty: \(spice.quantity)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            Button(action: { showingEdit = true }) {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.accent)
                    .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
            }
            
            Button(action: deleteSpice) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .minimalistCard(.outlined)
        .sheet(isPresented: $showingEdit) {
            EditSpiceItemView(spice: spice)
        }
    }
    
    private func deleteSpice() {
        modelContext.delete(spice)
        modelContext.saveWithDebounce(using: autoSaveManager)
    }
}

// MARK: - Add Spice Item View
struct AddSpiceItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loadingManager = LoadingStateManager()
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    @State private var spiceName = ""
    @State private var spiceQuantity = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Spice Name")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    TextField("Enter spice name", text: $spiceName)
                        .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Quantity")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    TextField("Enter quantity", text: $spiceQuantity)
                        .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                }
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.xl)
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSpice()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.accent)
                    .disabled(spiceName.isEmpty)
                }
            }
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
    
    private func saveSpice() {
        loadingManager.startLoading(message: "Saving spice...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let newSpice = SpiceItem(
                name: spiceName.trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: spiceQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            modelContext.insert(newSpice)
            modelContext.saveWithDebounce(using: autoSaveManager)
            loadingManager.stopLoading()
            dismiss()
        }
    }
}

// MARK: - Edit Spice Item View
struct EditSpiceItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loadingManager = LoadingStateManager()
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    let spice: SpiceItem
    @State private var spiceName: String
    @State private var spiceQuantity: String
    
    init(spice: SpiceItem) {
        self.spice = spice
        self._spiceName = State(initialValue: spice.name)
        self._spiceQuantity = State(initialValue: spice.quantity)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Spice Name")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    TextField("Enter spice name", text: $spiceName)
                        .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Quantity")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    TextField("Enter quantity", text: $spiceQuantity)
                        .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                }
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.xl)
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.accent)
                    .disabled(spiceName.isEmpty)
                }
            }
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
    
    private func saveChanges() {
        loadingManager.startLoading(message: "Saving changes...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            spice.name = spiceName.trimmingCharacters(in: .whitespacesAndNewlines)
            spice.quantity = spiceQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
            
            modelContext.saveWithDebounce(using: autoSaveManager)
            loadingManager.stopLoading()
            dismiss()
        }
    }
}

// MARK: - Shopping Cart Content View
struct ShoppingCartContentView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loadingManager = LoadingStateManager()
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    let allCartItems: [CartItem]
    @State private var showingAddItem = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            if allCartItems.isEmpty {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "cart")
                            .font(.system(size: 32, weight: .light))
                            .foregroundColor(.green)
                    }
                    
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Text("Shopping cart is empty")
                            .font(DesignSystem.Typography.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Add items to your shopping list")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button(action: { showingAddItem = true }) {
                        Text("Add First Item")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .fill(Color.green)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(DesignSystem.Spacing.xl)
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(allCartItems, id: \.id) { item in
                            CartItemRow(item: item)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
                
                // Add button
                HStack {
                    Spacer()
                    Button(action: { showingAddItem = true }) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Add Item")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.lg)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                .fill(Color.green)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
            }
        }
        .background(DesignSystem.Colors.background)
        .sheet(isPresented: $showingAddItem) {
            AddCartItemView()
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
}

// MARK: - Cart Item Row
struct CartItemRow: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    let item: CartItem
    @State private var showingEdit = false
    
    var body: some View {
        HStack {
            Button(action: togglePurchased) {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(item.isPurchased ? .green : DesignSystem.Colors.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(item.name)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .foregroundColor(item.isPurchased ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)
                    .strikethrough(item.isPurchased)
                
                Text("Qty: \(item.quantity)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
            
            Button(action: { showingEdit = true }) {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(DesignSystem.Colors.accent)
                    .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
            }
            
            Button(action: deleteItem) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.red)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .minimalistCard(.outlined)
        .sheet(isPresented: $showingEdit) {
            EditCartItemView(item: item)
        }
    }
    
    private func togglePurchased() {
        item.isPurchased.toggle()
        modelContext.saveWithDebounce(using: autoSaveManager)
    }
    
    private func deleteItem() {
        modelContext.delete(item)
        modelContext.saveWithDebounce(using: autoSaveManager)
    }
}

// MARK: - Add Cart Item View
struct AddCartItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loadingManager = LoadingStateManager()
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    @State private var itemName = ""
    @State private var itemQuantity = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Item Name")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    TextField("Enter item name", text: $itemName)
                        .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Quantity")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    TextField("Enter quantity", text: $itemQuantity)
                        .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                }
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.xl)
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveItem()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.accent)
                    .disabled(itemName.isEmpty)
                }
            }
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
    
    private func saveItem() {
        loadingManager.startLoading(message: "Saving item...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let newItem = CartItem(
                name: itemName.trimmingCharacters(in: .whitespacesAndNewlines),
                quantity: itemQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            
            modelContext.insert(newItem)
            modelContext.saveWithDebounce(using: autoSaveManager)
            loadingManager.stopLoading()
            dismiss()
        }
    }
}

// MARK: - Edit Cart Item View
struct EditCartItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loadingManager = LoadingStateManager()
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    let item: CartItem
    @State private var itemName: String
    @State private var itemQuantity: String
    
    init(item: CartItem) {
        self.item = item
        self._itemName = State(initialValue: item.name)
        self._itemQuantity = State(initialValue: item.quantity)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Item Name")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    TextField("Enter item name", text: $itemName)
                        .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Quantity")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    TextField("Enter quantity", text: $itemQuantity)
                        .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                }
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.xl)
            .background(DesignSystem.Colors.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.accent)
                    .disabled(itemName.isEmpty)
                }
            }
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
    
    private func saveChanges() {
        loadingManager.startLoading(message: "Saving changes...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            item.name = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
            item.quantity = itemQuantity.trimmingCharacters(in: .whitespacesAndNewlines)
            
            modelContext.saveWithDebounce(using: autoSaveManager)
            loadingManager.stopLoading()
            dismiss()
        }
    }
}


// MARK: - Recipe Category Menu View
struct RecipeCategoryMenuView: View {
    @Binding var selectedCategory: RecipeCategory
    let filteredRecipes: [Recipe]
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Recipe.createdDate, order: .reverse) private var allRecipes: [Recipe]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Recipe Categories")
                        .font(DesignSystem.Typography.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Spacer()
                    
                    Button("Done") {
                        dismiss()
                    }
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.accent)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.top, DesignSystem.Spacing.lg)
                
                // Category list
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(RecipeCategory.allCases, id: \.self) { category in
                            RecipeCategoryMenuItem(
                                category: category,
                                isSelected: selectedCategory == category,
                                recipeCount: allRecipes.filter { $0.category == category.rawValue }.count,
                                action: {
                                    selectedCategory = category
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.top, DesignSystem.Spacing.lg)
                }
            }
            .background(DesignSystem.Colors.background)
        }
    }
}

// MARK: - Recipe Category Menu Item
struct RecipeCategoryMenuItem: View {
    let category: RecipeCategory
    let isSelected: Bool
    let recipeCount: Int
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Category icon
                ZStack {
                    Circle()
                        .fill(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.backgroundTertiary)
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: category.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
                }
                
                // Category info
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(category.rawValue)
                        .font(DesignSystem.Typography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("\(recipeCount) recipe\(recipeCount == 1 ? "" : "s")")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(DesignSystem.Colors.accent)
                }
            }
            .padding(DesignSystem.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(isSelected ? DesignSystem.Colors.accent.opacity(0.1) : DesignSystem.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .stroke(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}


// MARK: - Edit Recipe View
struct EditRecipeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loadingManager = LoadingStateManager()
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    let recipe: Recipe
    @State private var recipeName: String
    @State private var servings: String
    @State private var cookingTime: String
    @State private var difficulty: String
    @State private var instructions: String
    @State private var selectedCategory: RecipeCategory
    @State private var ingredients: [RecipeIngredient] = []
    @State private var newIngredientQuantity = ""
    @State private var newIngredientUnit = ""
    @State private var newIngredientItem = ""
    
    init(recipe: Recipe) {
        self.recipe = recipe
        self._recipeName = State(initialValue: recipe.name)
        self._servings = State(initialValue: recipe.servings)
        self._cookingTime = State(initialValue: recipe.cookingTime)
        self._difficulty = State(initialValue: recipe.difficulty)
        self._instructions = State(initialValue: recipe.instructions)
        self._selectedCategory = State(initialValue: RecipeCategory(rawValue: recipe.category) ?? .breakfast)
        self._ingredients = State(initialValue: recipe.ingredients ?? [])
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Recipe Name
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Recipe Name")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        TextField("Enter recipe name", text: $recipeName)
                            .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                    }
                    
                    // Servings and Cooking Time
                    HStack(spacing: DesignSystem.Spacing.md) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Servings")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            TextField("4", text: $servings)
                                .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                                .keyboardType(.numberPad)
                        }
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Cooking Time")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            TextField("30 min", text: $cookingTime)
                                .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                        }
                    }
                    
                    // Ingredients Section
                    VStack(spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Text("Ingredients")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.semibold)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Spacer()
                            
                            Text("\(ingredients.count) items")
                                .font(DesignSystem.Typography.caption)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        // Ingredients List
                        if !ingredients.isEmpty {
                            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                                ForEach(ingredients, id: \.id) { ingredient in
                                    HStack {
                                        HStack(spacing: 4) {
                                            Text(ingredient.quantity)
                                                .font(DesignSystem.Typography.body)
                                                .fontWeight(.medium)
                                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                            
                                            if !ingredient.item.isEmpty {
                                                Text("•")
                                                    .font(DesignSystem.Typography.caption)
                                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                            }
                                        }
                                        .frame(width: 80, alignment: .leading)
                                        
                                        Text(ingredient.item)
                                            .font(DesignSystem.Typography.body)
                                            .foregroundColor(DesignSystem.Colors.textPrimary)
                                        
                                        Spacer()
                                        
                                        Button(action: {
                                            ingredients.removeAll { $0.id == ingredient.id }
                                            modelContext.delete(ingredient)
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.red)
                                        }
                                    }
                                    .padding(DesignSystem.Spacing.md)
                                    .background(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                            .fill(DesignSystem.Colors.surface)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                            )
                                    )
                                }
                            }
                        }
                        
                        // Add Ingredient
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                TextField("2", text: $newIngredientQuantity)
                                    .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                                    .frame(width: 60)
                                    .keyboardType(.decimalPad)
                                
                                TextField("cups", text: $newIngredientUnit)
                                    .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                                    .frame(width: 80)
                                
                                TextField("Ingredient name", text: $newIngredientItem)
                                    .textFieldStyle(MinimalistInputFieldStyle(state: .normal))
                            }
                            
                            Button(action: addIngredient) {
                                HStack(spacing: DesignSystem.Spacing.sm) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Add Ingredient")
                                        .font(DesignSystem.Typography.callout)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, DesignSystem.Spacing.md)
                                .background(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                        .fill(canAddIngredient ? DesignSystem.Colors.accent : DesignSystem.Colors.backgroundTertiary)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .disabled(!canAddIngredient)
                        }
                        .padding(DesignSystem.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                .fill(DesignSystem.Colors.backgroundTertiary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                                        .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                )
                        )
                    }
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Instructions")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        TextEditor(text: $instructions)
                            .font(DesignSystem.Typography.body)
                            .frame(minHeight: 100)
                            .padding(DesignSystem.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .fill(DesignSystem.Colors.background)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Edit Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveRecipe()
                    }
                    .foregroundColor(DesignSystem.Colors.accent)
                    .disabled(recipeName.isEmpty)
                }
            }
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
    
    private var canAddIngredient: Bool {
        return !newIngredientItem.isEmpty
    }
    
    private func addIngredient() {
        guard canAddIngredient else { return }
        
        let quantityText: String
        if newIngredientQuantity.isEmpty && newIngredientUnit.isEmpty {
            quantityText = "As needed"
        } else if newIngredientQuantity.isEmpty {
            quantityText = newIngredientUnit
        } else if newIngredientUnit.isEmpty {
            quantityText = newIngredientQuantity
        } else {
            quantityText = "\(newIngredientQuantity) \(newIngredientUnit)"
        }
        
        let newIngredient = RecipeIngredient(
            quantity: quantityText,
            item: newIngredientItem.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        ingredients.append(newIngredient)
        recipe.ingredients?.append(newIngredient)
        newIngredient.recipe = recipe
        
        newIngredientQuantity = ""
        newIngredientUnit = ""
        newIngredientItem = ""
    }
    
    private func saveRecipe() {
        loadingManager.startLoading(message: "Saving recipe...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            recipe.name = recipeName.trimmingCharacters(in: .whitespacesAndNewlines)
            recipe.servings = servings.trimmingCharacters(in: .whitespacesAndNewlines)
            recipe.cookingTime = cookingTime.trimmingCharacters(in: .whitespacesAndNewlines)
            recipe.difficulty = difficulty
            recipe.instructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
            recipe.category = selectedCategory.rawValue
            
            modelContext.saveWithDebounce(using: autoSaveManager)
            loadingManager.stopLoading()
            dismiss()
        }
    }
}

// MARK: - Recipe Image Picker
struct RecipeImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    let recipe: Recipe
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: RecipeImagePicker
        @StateObject private var autoSaveManager = AutoSaveManager()
        
        init(_ parent: RecipeImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
                parent.recipe.imageData = image.jpegData(compressionQuality: 0.8) ?? Data()
                
                // Save the image changes
                if let context = parent.recipe.modelContext {
                    context.saveWithDebounce(using: autoSaveManager)
                }
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
