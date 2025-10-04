//
//  QuotesViews.swift
//  Slate
//
//  Created by UI Overhaul on 9/29/25.
//

import SwiftUI
import SwiftData

// MARK: - Ultra-Modern Quotes Views

// MARK: - Modern Quotes Main View
struct ModernQuotesMainView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loadingManager = LoadingStateManager()
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    @Query private var allQuotes: [Quote]
    @State private var selectedCategory: QuoteCategory? = .motivation
    @State private var searchText = ""
    @State private var showingAddQuote = false
    
    // Computed properties
    private var filteredQuotes: [Quote] {
        let categoryQuotes: [Quote]
        
        if let category = selectedCategory {
            categoryQuotes = allQuotes.filter { $0.category == category.rawValue }
        } else {
            // Show all quotes when no specific category is selected
            categoryQuotes = allQuotes
        }
        
        if searchText.isEmpty {
            return categoryQuotes.sorted { $0.createdDate > $1.createdDate }
        } else {
            return categoryQuotes.filter { quote in
                quote.text.localizedCaseInsensitiveContains(searchText) ||
                quote.author.localizedCaseInsensitiveContains(searchText)
            }.sorted { $0.createdDate > $1.createdDate }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Quotes")
                            .font(DesignSystem.Typography.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Inspire yourself with meaningful words")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    
                    Spacer()
                    
                    Button(action: { showingAddQuote = true }) {
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
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                    
                    TextField("Search quotes or authors...", text: $searchText)
                        .font(DesignSystem.Typography.body)
                        .textFieldStyle(.plain)
                }
                .padding(DesignSystem.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(DesignSystem.Colors.backgroundTertiary)
                )
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.top, DesignSystem.Spacing.lg)
            
            // Category tabs
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // "All" tab
                    ModernQuoteCategoryTab(
                        category: nil,
                        isSelected: selectedCategory == nil,
                        quoteCount: allQuotes.count,
                        action: { selectedCategory = nil }
                    )
                    
                    // Individual category tabs
                    ForEach(QuoteCategory.allCases, id: \.self) { category in
                        ModernQuoteCategoryTab(
                            category: category,
                            isSelected: selectedCategory == category,
                            quoteCount: allQuotes.filter { $0.category == category.rawValue }.count,
                            action: { selectedCategory = category }
                        )
                    }
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .padding(.vertical, DesignSystem.Spacing.md)
            
            // Quotes content
            if filteredQuotes.isEmpty {
                ModernEmptyQuotesView(category: selectedCategory)
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(filteredQuotes, id: \.id) { quote in
                            ModernQuoteCard(quote: quote)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.bottom, DesignSystem.Spacing.xl)
                }
            }
        }
        .background(DesignSystem.Colors.background)
        .sheet(isPresented: $showingAddQuote) {
            ModernAddQuoteView()
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
}

// MARK: - Modern Quote Category Tab
struct ModernQuoteCategoryTab: View {
    let category: QuoteCategory?
    let isSelected: Bool
    let quoteCount: Int
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: category?.icon ?? "list.bullet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : (category?.color ?? DesignSystem.Colors.accent))
                
                Text(category?.rawValue ?? "All")
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(isSelected ? .semibold : .medium)
                    .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
                
                if quoteCount > 0 {
                    Text("\(quoteCount)")
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
                    .fill(isSelected ? (category?.color ?? DesignSystem.Colors.accent) : DesignSystem.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .stroke(isSelected ? (category?.color ?? DesignSystem.Colors.accent).opacity(0.3) : DesignSystem.Colors.textTertiary, lineWidth: 1)
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

// MARK: - Modern Quote Card
struct ModernQuoteCard: View {
    let quote: Quote
    @State private var isHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Quote text
            Text("\"\(quote.text)\"")
                .font(DesignSystem.Typography.title3)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
            
            // Author
            HStack {
                Spacer()
                
                Text("— \(quote.author)")
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .italic()
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .minimalistCard(.outlined)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Modern Empty Quotes View
struct ModernEmptyQuotesView: View {
    let category: QuoteCategory?
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ZStack {
                Circle()
                    .fill((category?.color ?? DesignSystem.Colors.accent).opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: category?.icon ?? "list.bullet")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(category?.color ?? DesignSystem.Colors.accent)
            }
            
            VStack(spacing: DesignSystem.Spacing.sm) {
                if let category = category {
                    Text("No \(category.rawValue.lowercased()) quotes yet")
                        .font(DesignSystem.Typography.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("Add your first \(category.rawValue.lowercased()) quote to get started")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("No quotes yet")
                        .font(DesignSystem.Typography.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("Add your first quote to get started")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xl)
    }
}

// MARK: - Modern Add Quote View
struct ModernAddQuoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loadingManager = LoadingStateManager()
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    @State private var quoteText = ""
    @State private var author = ""
    @State private var selectedCategory: QuoteCategory = .motivation
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Header
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Add New Quote")
                            .font(DesignSystem.Typography.title1)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Share a meaningful quote that inspires you")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Form
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // Quote text
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Quote")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            ModernTaskTextField(
                                text: $quoteText,
                                placeholder: "Enter your quote here...",
                                isFocused: .constant(false),
                                isMultiline: true
                            )
                            .frame(minHeight: 120)
                        }
                        
                        // Author
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Author")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            ModernTaskTextField(
                                text: $author,
                                placeholder: "Enter author name",
                                isFocused: .constant(false),
                                isMultiline: false
                            )
                        }
                        
                        // Category
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Category")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            Picker("Category", selection: $selectedCategory) {
                                ForEach(QuoteCategory.allCases, id: \.self) { category in
                                    HStack {
                                        Image(systemName: category.icon)
                                        Text(category.rawValue)
                                    }.tag(category)
                                }
                            }
                            .pickerStyle(.menu)
                            .padding(DesignSystem.Spacing.md)
                            .minimalistCard(.outlined)
                        }
                    }
                }
                .padding(DesignSystem.Spacing.xl)
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveQuote()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.accent)
                    .disabled(quoteText.isEmpty || author.isEmpty)
                }
            }
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
    
    private func saveQuote() {
        loadingManager.startLoading(message: "Saving quote...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let newQuote = Quote(
                text: quoteText.trimmingCharacters(in: .whitespacesAndNewlines),
                author: author.trimmingCharacters(in: .whitespacesAndNewlines),
                category: selectedCategory.rawValue
            )
            
            modelContext.insert(newQuote)
            modelContext.saveWithDebounce(using: autoSaveManager)
            loadingManager.stopLoading()
            dismiss()
        }
    }
}

