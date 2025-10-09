//
//  SettingsViews.swift
//  InkSlate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI
import SwiftData

// MARK: - Settings Feature Views
struct SettingsView: View {
    @State private var showingMenuReorder = false
    @State private var showingPrivacySettings = false
    @State private var showingFactoryResetWarning = false
    @State private var showingFactoryResetConfirmation = false
    @EnvironmentObject var shared: SharedStateManager
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        List {
            Section("Menu Customization") {
                Button(action: {
                    showingMenuReorder = true
                }) {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                            .foregroundColor(DesignSystem.Colors.accent)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                        Text("Reorder Menu Items")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .font(.caption)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                    }
                }
                .foregroundColor(.primary)
            }
            
            Section("Privacy & Security") {
                Button(action: {
                    showingPrivacySettings = true
                }) {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(DesignSystem.Colors.accent)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                        Text("Privacy Settings")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .font(.caption)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                    }
                }
                .foregroundColor(.primary)
            }
            
            
            Section("Danger Zone") {
                Button(action: {
                    showingFactoryResetWarning = true
                }) {
                    HStack {
                        Image(systemName: "trash.circle.fill")
                            .foregroundColor(.red)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                        Text("Factory Reset")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .font(.caption)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                    }
                }
                .foregroundColor(.red)
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingMenuReorder) {
            MenuReorderView()
        }
        .sheet(isPresented: $showingPrivacySettings) {
            PrivacySettingsView()
        }
        .alert("⚠️ Factory Reset Warning", isPresented: $showingFactoryResetWarning) {
            Button("Continue", role: .destructive) {
                showingFactoryResetConfirmation = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete ALL your data including notes, journals, todos, recipes, and all other content. This action cannot be undone. Are you absolutely sure you want to continue?")
        }
        .alert("🔥 Final Confirmation", isPresented: $showingFactoryResetConfirmation) {
            Button("DELETE EVERYTHING", role: .destructive) {
                performFactoryReset()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This is your last chance to cancel. Clicking 'DELETE EVERYTHING' will permanently erase all your data from this device and iCloud. This cannot be undone.")
        }
    }
    
    private func performFactoryReset() {
        // Delete all SwiftData models
        do {
            // Delete all notes and folders
            let noteDescriptor = FetchDescriptor<Note>()
            let notes = try modelContext.fetch(noteDescriptor)
            for note in notes {
                modelContext.delete(note)
            }
            
            let folderDescriptor = FetchDescriptor<Folder>()
            let folders = try modelContext.fetch(folderDescriptor)
            for folder in folders {
                modelContext.delete(folder)
            }
            
            // Delete all journal books and entries
            let journalBookDescriptor = FetchDescriptor<JournalBook>()
            let journalBooks = try modelContext.fetch(journalBookDescriptor)
            for book in journalBooks {
                modelContext.delete(book)
            }
            
            let journalEntryDescriptor = FetchDescriptor<JournalEntry>()
            let journalEntries = try modelContext.fetch(journalEntryDescriptor)
            for entry in journalEntries {
                modelContext.delete(entry)
            }
            
            // Delete all todo tabs and tasks
            let todoTabDescriptor = FetchDescriptor<TodoTab>()
            let todoTabs = try modelContext.fetch(todoTabDescriptor)
            for tab in todoTabs {
                modelContext.delete(tab)
            }
            
            let todoTaskDescriptor = FetchDescriptor<TodoTask>()
            let todoTasks = try modelContext.fetch(todoTaskDescriptor)
            for task in todoTasks {
                modelContext.delete(task)
            }
            
            // Delete all recipes, ingredients, and related items
            let recipeDescriptor = FetchDescriptor<Recipe>()
            let recipes = try modelContext.fetch(recipeDescriptor)
            for recipe in recipes {
                modelContext.delete(recipe)
            }
            
            let recipeIngredientDescriptor = FetchDescriptor<RecipeIngredient>()
            let ingredients = try modelContext.fetch(recipeIngredientDescriptor)
            for ingredient in ingredients {
                modelContext.delete(ingredient)
            }
            
            let fridgeDescriptor = FetchDescriptor<FridgeItem>()
            let fridgeItems = try modelContext.fetch(fridgeDescriptor)
            for item in fridgeItems {
                modelContext.delete(item)
            }
            
            let spiceDescriptor = FetchDescriptor<SpiceItem>()
            let spiceItems = try modelContext.fetch(spiceDescriptor)
            for item in spiceItems {
                modelContext.delete(item)
            }
            
            let cartDescriptor = FetchDescriptor<CartItem>()
            let cartItems = try modelContext.fetch(cartDescriptor)
            for item in cartItems {
                modelContext.delete(item)
            }
            
            // Delete all mind maps and nodes
            let mindMapDescriptor = FetchDescriptor<MindMap>()
            let mindMaps = try modelContext.fetch(mindMapDescriptor)
            for mindMap in mindMaps {
                modelContext.delete(mindMap)
            }
            
            let mindMapNodeDescriptor = FetchDescriptor<MindMapNode>()
            let mindMapNodes = try modelContext.fetch(mindMapNodeDescriptor)
            for node in mindMapNodes {
                modelContext.delete(node)
            }
            
            // Delete all places and categories
            let placeCategoryDescriptor = FetchDescriptor<PlaceCategory>()
            let placeCategories = try modelContext.fetch(placeCategoryDescriptor)
            for category in placeCategories {
                modelContext.delete(category)
            }
            
            let placeDescriptor = FetchDescriptor<Place>()
            let places = try modelContext.fetch(placeDescriptor)
            for place in places {
                modelContext.delete(place)
            }
            
            // Delete all quotes
            let quoteDescriptor = FetchDescriptor<Quote>()
            let quotes = try modelContext.fetch(quoteDescriptor)
            for quote in quotes {
                modelContext.delete(quote)
            }
            
            // Delete all watchlist items
            let watchlistDescriptor = FetchDescriptor<WatchlistItem>()
            let watchlistItems = try modelContext.fetch(watchlistDescriptor)
            for item in watchlistItems {
                modelContext.delete(item)
            }
            
            // Save changes
            try modelContext.save()
            
            // Clear all UserDefaults
            let defaults = UserDefaults.standard
            let dictionary = defaults.dictionaryRepresentation()
            for key in dictionary.keys {
                defaults.removeObject(forKey: key)
            }
            defaults.synchronize()
            
            // Reset shared state
            shared.resetToDefaults()
            
        } catch {
            // Handle error silently - user doesn't need to see technical errors
        }
    }
}

// MARK: - Menu Reorder View
struct MenuReorderView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var menuItems: [MenuViewType] = MenuViewType.allCases
    @State private var hiddenItems: Set<MenuViewType> = []
    
    var body: some View {
        NavigationView {
            List {
                Section("Visible Menu Items") {
                    ForEach(menuItems.filter { !hiddenItems.contains($0) }, id: \.self) { item in
                        HStack {
                            Image(systemName: item.icon)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(item.rawValue)
                            Spacer()
                            Button(action: {
                                toggleVisibility(for: item)
                            }) {
                                Image(systemName: "eye.slash")
                                    .foregroundColor(.red)
                            }
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove(perform: moveVisibleItems)
                }
                
                if !hiddenItems.isEmpty {
                    Section("Hidden Menu Items") {
                        ForEach(Array(hiddenItems), id: \.self) { item in
                            HStack {
                                Image(systemName: item.icon)
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                Text(item.rawValue)
                                    .foregroundColor(.gray)
                                Spacer()
                                Button(action: {
                                    toggleVisibility(for: item)
                                }) {
                                    Image(systemName: "eye")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Customize Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMenuConfiguration()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadMenuConfiguration()
        }
    }
    
    private func moveVisibleItems(from source: IndexSet, to destination: Int) {
        let visibleItems = menuItems.filter { !hiddenItems.contains($0) }
        var newOrder = visibleItems
        newOrder.move(fromOffsets: source, toOffset: destination)
        
        // Update the main menuItems array with the new order
        var updatedMenuItems: [MenuViewType] = []
        for item in newOrder {
            if menuItems.contains(item) {
                updatedMenuItems.append(item)
            }
        }
        // Add hidden items at the end
        for item in menuItems {
            if hiddenItems.contains(item) && !updatedMenuItems.contains(item) {
                updatedMenuItems.append(item)
            }
        }
        menuItems = updatedMenuItems
    }
    
    private func toggleVisibility(for item: MenuViewType) {
        if hiddenItems.contains(item) {
            hiddenItems.remove(item)
        } else {
            hiddenItems.insert(item)
        }
    }
    
    private func loadMenuConfiguration() {
        // Load saved menu order
        if let savedOrder = UserDefaults.standard.array(forKey: "MenuOrder") as? [String] {
            let orderedItems = savedOrder.compactMap { MenuViewType(rawValue: $0) }
            if !orderedItems.isEmpty {
                menuItems = orderedItems
            }
        }
        
        // Load hidden items
        if let hiddenItemsData = UserDefaults.standard.array(forKey: "HiddenMenuItems") as? [String] {
            hiddenItems = Set(hiddenItemsData.compactMap { MenuViewType(rawValue: $0) })
        }
    }
    
    private func saveMenuConfiguration() {
        // Save menu order
        UserDefaults.standard.set(menuItems.map { $0.rawValue }, forKey: "MenuOrder")
        
        // Save hidden items
        UserDefaults.standard.set(Array(hiddenItems).map { $0.rawValue }, forKey: "HiddenMenuItems")
    }
}

// MARK: - Privacy Settings View
struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var analyticsEnabled = false
    @State private var crashReportingEnabled = true
    @State private var dataCollectionEnabled = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Analytics & Privacy") {
                    Toggle("Analytics", isOn: $analyticsEnabled)
                    Toggle("Crash Reporting", isOn: $crashReportingEnabled)
                    Toggle("Data Collection", isOn: $dataCollectionEnabled)
                }
                
                Section("Data Control") {
                    Button("Clear All Data") {
                        clearAllData()
                    }
                    .foregroundColor(.red)
                    
                    Button("Reset Privacy Settings") {
                        resetPrivacySettings()
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Privacy Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func clearAllData() {
        // Implement data clearing logic
    }
    
    private func resetPrivacySettings() {
        analyticsEnabled = false
        crashReportingEnabled = true
        dataCollectionEnabled = false
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}