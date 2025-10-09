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
    @Environment(\.modelContext) private var modelContext
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    let quote: Quote
    @State private var isHovered = false
    @State private var showingEditSheet = false
    @State private var showingDetailView = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Quote text
            Text("\"\(quote.text)\"")
                .font(DesignSystem.Typography.title3)
                .fontWeight(.medium)
                .foregroundColor(DesignSystem.Colors.textPrimary)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
            
            // Author and actions
            HStack {
                Text("— \(quote.author)")
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .italic()
                
                Spacer()
                
                // Action buttons
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Favorite button
                    Button(action: toggleFavorite) {
                        Image(systemName: quote.isFavorite ? "star.fill" : "star")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(quote.isFavorite ? .yellow : DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Edit button
                    Button(action: { showingEditSheet = true }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Delete button
                    Button(action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            // Category badge
            HStack {
                if let category = QuoteCategory(rawValue: quote.category) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: category.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(category.color)
                        
                        Text(category.rawValue)
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(category.color)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.vertical, DesignSystem.Spacing.xs)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                            .fill(category.color.opacity(0.1))
                    )
                }
                
                Spacer()
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
        .onTapGesture {
            showingDetailView = true
        }
        .contextMenu {
            Button(action: toggleFavorite) {
                Label(quote.isFavorite ? "Remove from Favorites" : "Add to Favorites", 
                      systemImage: quote.isFavorite ? "star.slash" : "star")
            }
            
            Button(action: { showingEditSheet = true }) {
                Label("Edit", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive, action: { showingDeleteAlert = true }) {
                Label("Delete", systemImage: "trash")
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ModernEditQuoteView(quote: quote)
        }
        .sheet(isPresented: $showingDetailView) {
            EnhancedModernQuoteDetailView(quote: quote)
        }
        .alert("Delete Quote", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteQuote()
            }
        } message: {
            Text("Are you sure you want to delete this quote? This action cannot be undone.")
        }
    }
    
    private func toggleFavorite() {
        withAnimation(.easeInOut(duration: 0.2)) {
            quote.isFavorite.toggle()
        }
        modelContext.saveWithDebounce(using: autoSaveManager)
    }
    
    private func deleteQuote() {
        withAnimation(.easeInOut(duration: 0.2)) {
            modelContext.delete(quote)
            modelContext.saveWithDebounce(using: autoSaveManager)
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

// MARK: - Modern Edit Quote View
struct ModernEditQuoteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var loadingManager = LoadingStateManager()
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    let quote: Quote
    @State private var quoteText: String
    @State private var author: String
    @State private var selectedCategory: QuoteCategory
    
    init(quote: Quote) {
        self.quote = quote
        self._quoteText = State(initialValue: quote.text)
        self._author = State(initialValue: quote.author)
        self._selectedCategory = State(initialValue: QuoteCategory(rawValue: quote.category) ?? .motivation)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Header
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Edit Quote")
                            .font(DesignSystem.Typography.title1)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Update your quote details")
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
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(DesignSystem.Colors.accent)
                    .disabled(quoteText.isEmpty || author.isEmpty)
                }
            }
        }
        .loadingOverlay(loadingManager: loadingManager)
    }
    
    private func saveChanges() {
        loadingManager.startLoading(message: "Saving changes...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            quote.text = quoteText.trimmingCharacters(in: .whitespacesAndNewlines)
            quote.author = author.trimmingCharacters(in: .whitespacesAndNewlines)
            quote.category = selectedCategory.rawValue
            
            modelContext.saveWithDebounce(using: autoSaveManager)
            loadingManager.stopLoading()
            dismiss()
        }
    }
}

// MARK: - Enhanced Modern Quote Detail View
struct EnhancedModernQuoteDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var autoSaveManager = AutoSaveManager()
    
    let quote: Quote
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    // Category badge
                    if let category = QuoteCategory(rawValue: quote.category) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(category.color.opacity(0.1))
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: category.icon)
                                    .font(.system(size: 28, weight: .semibold))
                                    .foregroundColor(category.color)
                            }
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                                Text(category.rawValue)
                                    .font(DesignSystem.Typography.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                                
                                Text("Quote Category")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                            }
                            
                            Spacer()
                            
                            // Favorite button
                            Button(action: toggleFavorite) {
                                Image(systemName: quote.isFavorite ? "star.fill" : "star")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(quote.isFavorite ? .yellow : DesignSystem.Colors.textSecondary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .minimalistCard(.outlined)
                    }
                    
                    // Quote text
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Quote")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        Text("\"\(quote.text)\"")
                            .font(DesignSystem.Typography.title2)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .minimalistCard(.outlined)
                    
                    // Author
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Author")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(DesignSystem.Colors.accent)
                            
                            Text(quote.author)
                                .font(DesignSystem.Typography.body)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .minimalistCard(.outlined)
                    
                    // Metadata
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Information")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            HStack {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .frame(width: 24)
                                
                                Text("Added on")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                Spacer()
                                
                                Text(quote.createdDate, style: .date)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                            
                            Divider()
                            
                            HStack {
                                Image(systemName: "clock")
                                    .font(.system(size: 16))
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                    .frame(width: 24)
                                
                                Text("Time")
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                Spacer()
                                
                                Text(quote.createdDate, style: .time)
                                    .font(DesignSystem.Typography.body)
                                    .foregroundColor(DesignSystem.Colors.textPrimary)
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .minimalistCard(.outlined)
                    
                    // Actions
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Button(action: { showingEditSheet = true }) {
                            HStack {
                                Image(systemName: "pencil")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Edit Quote")
                                    .font(DesignSystem.Typography.callout)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .fill(DesignSystem.Colors.accent)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { showingDeleteAlert = true }) {
                            HStack {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Delete Quote")
                                    .font(DesignSystem.Typography.callout)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                    .fill(Color.red.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.vertical, DesignSystem.Spacing.xl)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Quote Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.accent)
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            ModernEditQuoteView(quote: quote)
        }
        .alert("Delete Quote", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteQuote()
            }
        } message: {
            Text("Are you sure you want to delete this quote? This action cannot be undone.")
        }
    }
    
    private func toggleFavorite() {
        withAnimation(.easeInOut(duration: 0.2)) {
            quote.isFavorite.toggle()
        }
        modelContext.saveWithDebounce(using: autoSaveManager)
    }
    
    private func deleteQuote() {
        modelContext.delete(quote)
        modelContext.saveWithDebounce(using: autoSaveManager)
        dismiss()
    }
}
