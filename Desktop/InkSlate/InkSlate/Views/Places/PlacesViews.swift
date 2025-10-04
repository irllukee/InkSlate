import SwiftUI
import SwiftData
import UIKit

// MARK: - Main Places View
struct PlacesMainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allCategories: [PlaceCategory]
    
    @State private var selectedTab: PlaceType = .restaurant
    @State private var searchText = ""
    
    enum PlaceType: String, CaseIterable {
        case restaurant = "Restaurants"
        case activity = "Activities"
        case place = "Places"
    }
    
    private var categories: [PlaceCategory] {
        allCategories.filter { $0.type == selectedTab.rawValue.lowercased() }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Type tabs
                Picker("Type", selection: $selectedTab) {
                    ForEach(PlaceType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Category view
                PlacesCategoryView(
                    type: selectedTab.rawValue.lowercased(),
                    categories: categories,
                    searchText: $searchText
                )
            }
            .navigationTitle("Places & Reviews")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search places")
        }
    }
}

// MARK: - Places Category View
struct PlacesCategoryView: View {
    let type: String
    let categories: [PlaceCategory]
    @Binding var searchText: String
    @Environment(\.modelContext) private var modelContext
    @Query private var allPlaces: [Place]
    
    @State private var showingNewCategory = false
    @State private var selectedCategory: PlaceCategory?
    @State private var isEditing = false
    @State private var selectedCategoriesToDelete: Set<PlaceCategory> = []
    
    private var places: [Place] {
        allPlaces.filter { $0.category?.type == type }
    }
    
    private var wishlistCount: Int {
        places.filter { !$0.hasVisited }.count
    }
    
    private var favoritesCount: Int {
        places.filter { $0.hasVisited && $0.overallRating >= 8 }.count
    }
    
    var body: some View {
        List {
            // Wishlist section
            Section("Want to Try") {
                NavigationLink(destination: PlacesListView(
                    category: nil,
                    type: type,
                    wishlistOnly: true,
                    searchText: searchText
                )) {
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundColor(.yellow)
                        Text("Wishlist")
                        Spacer()
                        Text("\(wishlistCount)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Favorites section
            Section("Favorites") {
                NavigationLink(destination: PlacesListView(
                    category: nil,
                    type: type,
                    favoritesOnly: true,
                    searchText: searchText
                )) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("Top Rated")
                        Spacer()
                        Text("\(favoritesCount)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Categories
            Section("Categories") {
                ForEach(categories, id: \.id) { category in
                    HStack {
                        if isEditing {
                            Button {
                                toggleSelection(for: category)
                            } label: {
                                Image(systemName: selectedCategoriesToDelete.contains(category) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        NavigationLink(destination: PlacesListView(
                            category: category,
                            type: type,
                            searchText: searchText
                        )) {
                            HStack {
                                Image(systemName: iconForType(type))
                                    .foregroundColor(.blue)
                                Text(category.name)
                                Spacer()
                                Text("\(places.filter { $0.category?.id == category.id }.count)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .disabled(isEditing)
                    }
                }
                .onDelete(perform: isEditing ? nil : deleteCategories)
                
                if !isEditing {
                    Button {
                        showingNewCategory = true
                    } label: {
                        Label("New Category", systemImage: "plus.circle.fill")
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if categories.isEmpty {
                Section {
                    Text("No categories yet. Create one to get started!")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if isEditing {
                        Button("Delete Selected (\(selectedCategoriesToDelete.count))") {
                            deleteSelectedCategories()
                        }
                        .disabled(selectedCategoriesToDelete.isEmpty)
                        .foregroundColor(.red)
                        
                        Button("Delete All", role: .destructive) {
                            deleteAllCategories()
                        }
                        .disabled(categories.isEmpty)
                        
                        Button("Cancel") {
                            isEditing = false
                            selectedCategoriesToDelete.removeAll()
                        }
                    } else {
                        Button("Edit") {
                            isEditing = true
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewCategory) {
            NewCategoryView(type: type)
        }
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case "restaurants": return "fork.knife"
        case "activities": return "figure.run"
        case "places": return "mappin.and.ellipse"
        default: return "folder"
        }
    }
    
    private func toggleSelection(for category: PlaceCategory) {
        if selectedCategoriesToDelete.contains(category) {
            selectedCategoriesToDelete.remove(category)
        } else {
            selectedCategoriesToDelete.insert(category)
        }
    }
    
    private func deleteSelectedCategories() {
        for category in selectedCategoriesToDelete {
            // First, remove the category from all places that use it
            let placesInCategory = places.filter { $0.category?.id == category.id }
            for place in placesInCategory {
                place.category = nil
            }
            // Then delete the category
            modelContext.delete(category)
        }
        selectedCategoriesToDelete.removeAll()
        isEditing = false
    }
    
    private func deleteAllCategories() {
        for category in categories {
            // First, remove the category from all places that use it
            let placesInCategory = places.filter { $0.category?.id == category.id }
            for place in placesInCategory {
                place.category = nil
            }
            // Then delete the category
            modelContext.delete(category)
        }
        selectedCategoriesToDelete.removeAll()
        isEditing = false
    }
    
    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            let category = categories[index]
            // First, remove the category from all places that use it
            let placesInCategory = places.filter { $0.category?.id == category.id }
            for place in placesInCategory {
                place.category = nil
            }
            // Then delete the category
            modelContext.delete(category)
        }
    }
}

// MARK: - New Category View
struct NewCategoryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let type: String
    @State private var categoryName = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Category Name") {
                    TextField("e.g., Italian, Coffee Shops, Parks", text: $categoryName)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let category = PlaceCategory(name: categoryName, type: type)
                        modelContext.insert(category)
                        dismiss()
                    }
                    .disabled(categoryName.isEmpty)
                }
            }
        }
    }
}

// MARK: - Places List View
struct PlacesListView: View {
    let category: PlaceCategory?
    let type: String
    var wishlistOnly: Bool = false
    var favoritesOnly: Bool = false
    var searchText: String = ""
    
    @Environment(\.modelContext) private var modelContext
    @Query private var allPlaces: [Place]
    
    @State private var showingNewPlace = false
    @State private var selectedPlace: Place?
    
    private var places: [Place] {
        // Use lazy filtering for better performance
        var filtered: [Place]
        
        if wishlistOnly {
            filtered = allPlaces.lazy.filter { !$0.hasVisited && $0.category?.type == type }
        } else if favoritesOnly {
            filtered = allPlaces.lazy.filter { $0.hasVisited && $0.overallRating >= 8 && $0.category?.type == type }
        } else if let category = category {
            filtered = allPlaces.lazy.filter { $0.category?.id == category.id }
        } else {
            filtered = []
        }
        
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            filtered = filtered.filter { place in
                place.name.lowercased().contains(searchLower) ||
                place.location.lowercased().contains(searchLower)
            }
        }
        
        // Sort only once at the end
        return filtered.sorted { first, second in
            if first.hasVisited != second.hasVisited {
                return !first.hasVisited && second.hasVisited
            }
            return first.overallRating > second.overallRating
        }
    }
    
    private var title: String {
        if wishlistOnly {
            return "Wishlist"
        } else if favoritesOnly {
            return "Top Rated"
        } else {
            return category?.name ?? "Places"
        }
    }
    
    var body: some View {
        List {
            ForEach(places, id: \.id) { place in
                Button {
                    selectedPlace = place
                } label: {
                    PlaceRowView(place: place)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    modelContext.delete(places[index])
                }
            }
            
            if places.isEmpty {
                Text("No places yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingNewPlace = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                }
            }
        }
        .sheet(isPresented: $showingNewPlace) {
            PlaceEditorView(category: category, place: nil, type: type)
        }
        .sheet(item: $selectedPlace) { place in
            PlaceDetailView(place: place)
        }
    }
}

// MARK: - Place Row View
struct PlaceRowView: View {
    let place: Place
    
    var body: some View {
        HStack(spacing: 12) {
            // Photo thumbnail
            if !place.photoData.isEmpty, let uiImage = UIImage(data: place.photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(place.name)
                        .font(.headline)
                    
                    if !place.hasVisited {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                
                if !place.location.isEmpty {
                    Text(place.location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    // Overall rating
                    if place.hasVisited {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("\(place.overallRating)/10")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Price range
                    if !place.priceRange.isEmpty {
                        Text(place.priceRange)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    
                    // Would return
                    if place.hasVisited && place.wouldReturn {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    
                    // Date visited
                    if place.dateVisited != Date.distantPast {
                            Text(place.dateVisited, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Place Detail View
struct PlaceDetailView: View {
    let place: Place
    @State private var showingEditSheet = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Photo
                    if !place.photoData.isEmpty, let uiImage = UIImage(data: place.photoData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Basic info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(place.name)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        if !place.location.isEmpty {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .foregroundColor(.red)
                                Text(place.location)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if !place.address.isEmpty {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.blue)
                                Text(place.address)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        HStack(spacing: 16) {
                            if !place.priceRange.isEmpty {
                                Label(place.priceRange, systemImage: "dollarsign.circle.fill")
                                    .foregroundColor(.green)
                            }
                            
                            if !place.cuisineType.isEmpty {
                                Label(place.cuisineType, systemImage: "fork.knife")
                                    .foregroundColor(.orange)
                            }
                        }
                        .font(.subheadline)
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Status
                    if place.hasVisited {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: place.wouldReturn ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(place.wouldReturn ? .green : .red)
                                Text(place.wouldReturn ? "Would Return" : "Would Not Return")
                                    .font(.headline)
                            }
                            
                            if place.dateVisited != Date.distantPast {
                                HStack {
                                    Image(systemName: "calendar")
                                    Text("Visited: \(place.dateVisited, style: .date)")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                            Text("On Wishlist")
                                .font(.headline)
                        }
                        .padding(.horizontal)
                    }
                    
                    // Ratings (only if visited)
                    if place.hasVisited {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ratings")
                                .font(.headline)
                            
                            RatingRow(title: "Overall", rating: place.overallRating, color: .orange)
                            RatingRow(title: "Price", rating: place.priceRating, color: .green)
                            RatingRow(title: "Quality", rating: place.qualityRating, color: .blue)
                            RatingRow(title: "Atmosphere", rating: place.atmosphereRating, color: .purple)
                            RatingRow(title: "Fun Factor", rating: place.funFactorRating, color: .pink)
                            RatingRow(title: "Scenery", rating: place.sceneryRating, color: .teal)
                        }
                        .padding(.horizontal)
                        
                        Divider()
                    }
                    
                    // Additional details
                    if !place.bestTimeToGo.isEmpty {
                        DetailSection(icon: "clock.fill", title: "Best Time to Go", content: place.bestTimeToGo)
                    }
                    
                    if !place.whoToBring.isEmpty {
                        DetailSection(icon: "person.2.fill", title: "Who to Bring", content: place.whoToBring)
                    }
                    
                    if !place.entryFee.isEmpty {
                        DetailSection(icon: "ticket.fill", title: "Entry Fee", content: place.entryFee)
                    }
                    
                    if !place.dishRecommendations.isEmpty {
                        DetailSection(icon: "star.fill", title: "Dish Recommendations", content: place.dishRecommendations)
                    }
                    
                    // Pros and Cons
                    if place.hasVisited {
                        if !place.pros.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "hand.thumbsup.fill")
                                        .foregroundColor(.green)
                                    Text("Pros")
                                        .font(.headline)
                                }
                                Text(place.pros)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                        
                        if !place.cons.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "hand.thumbsdown.fill")
                                        .foregroundColor(.red)
                                    Text("Cons")
                                        .font(.headline)
                                }
                                Text(place.cons)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Notes
                    if !place.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "note.text")
                                Text("Notes")
                                    .font(.headline)
                            }
                            Text(place.notes)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Text("Edit")
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                PlaceEditorView(
                    category: place.category,
                    place: place,
                    type: place.category?.type ?? "restaurants"
                )
            }
        }
    }
}

// MARK: - Rating Row
struct RatingRow: View {
    let title: String
    let rating: Int16
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .frame(width: 100, alignment: .leading)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 8)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: CGFloat(rating) * 20, height: 8)
            }
            
            Text("\(rating)/10")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

// MARK: - Detail Section
struct DetailSection: View {
    let icon: String
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .font(.headline)
            }
            Text(content)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

// MARK: - Place Editor View
struct PlaceEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var allCategories: [PlaceCategory]
    
    let category: PlaceCategory?
    let place: Place?
    let type: String
    
    @State private var name = ""
    @State private var location = ""
    @State private var address = ""
    @State private var priceRange = ""
    @State private var cuisineType = ""
    @State private var bestTimeToGo = ""
    @State private var whoToBring = ""
    @State private var entryFee = ""
    @State private var dishRecommendations = ""
    @State private var notes = ""
    @State private var hasVisited = false
    @State private var dateVisited = Date()
    @State private var wouldReturn = true
    @State private var priceRating: Double = 5
    @State private var qualityRating: Double = 5
    @State private var atmosphereRating: Double = 5
    @State private var funFactorRating: Double = 5
    @State private var sceneryRating: Double = 5
    @State private var overallRating: Double = 5
    @State private var pros = ""
    @State private var cons = ""
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var selectedCategory: PlaceCategory?
    
    private var categories: [PlaceCategory] {
        allCategories.filter { $0.type == type }
    }
    
    init(category: PlaceCategory?, place: Place?, type: String) {
        self.category = category
        self.place = place
        self.type = type
        
        _selectedCategory = State(initialValue: place?.category ?? category)
        _name = State(initialValue: place?.name ?? "")
        _location = State(initialValue: place?.location ?? "")
        _address = State(initialValue: place?.address ?? "")
        _priceRange = State(initialValue: place?.priceRange ?? "")
        _cuisineType = State(initialValue: place?.cuisineType ?? "")
        _bestTimeToGo = State(initialValue: place?.bestTimeToGo ?? "")
        _whoToBring = State(initialValue: place?.whoToBring ?? "")
        _entryFee = State(initialValue: place?.entryFee ?? "")
        _dishRecommendations = State(initialValue: place?.dishRecommendations ?? "")
        _notes = State(initialValue: place?.notes ?? "")
        _hasVisited = State(initialValue: place?.hasVisited ?? false)
        _dateVisited = State(initialValue: place?.dateVisited ?? Date())
        _wouldReturn = State(initialValue: place?.wouldReturn ?? true)
        _priceRating = State(initialValue: Double(place?.priceRating ?? 5))
        _qualityRating = State(initialValue: Double(place?.qualityRating ?? 5))
        _atmosphereRating = State(initialValue: Double(place?.atmosphereRating ?? 5))
        _funFactorRating = State(initialValue: Double(place?.funFactorRating ?? 5))
        _sceneryRating = State(initialValue: Double(place?.sceneryRating ?? 5))
        _overallRating = State(initialValue: Double(place?.overallRating ?? 5))
        _pros = State(initialValue: place?.pros ?? "")
        _cons = State(initialValue: place?.cons ?? "")
        
        if let photoData = place?.photoData {
            _selectedImage = State(initialValue: UIImage(data: photoData))
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Basic Information Section
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Basic Information")
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    VStack(spacing: DesignSystem.Spacing.md) {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Name")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            ModernTaskTextField(
                                text: $name,
                                placeholder: "Enter place name",
                                isFocused: .constant(false),
                                isMultiline: false
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Location/City")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            ModernTaskTextField(
                                text: $location,
                                placeholder: "Enter city or location",
                                isFocused: .constant(false),
                                isMultiline: false
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Address (optional)")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.textSecondary)
                            
                            ModernTaskTextField(
                                text: $address,
                                placeholder: "Enter full address",
                                isFocused: .constant(false),
                                isMultiline: false
                            )
                        }
                    }
                    
                    Picker("Category", selection: $selectedCategory) {
                        Text("Select Category").tag(nil as PlaceCategory?)
                        ForEach(categories, id: \.id) { cat in
                            Text(cat.name).tag(cat as PlaceCategory?)
                        }
                    }
                }
                
                Section("Details") {
                    Picker("Price Range", selection: $priceRange) {
                        Text("Not set").tag("")
                        Text("$").tag("$")
                        Text("$$").tag("$$")
                        Text("$$$").tag("$$$")
                        Text("$$$$").tag("$$$$")
                    }
                    
                    if type == "restaurants" {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Cuisine Type")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            ModernTaskTextField(
                                text: $cuisineType,
                                placeholder: "Enter cuisine type",
                                isFocused: .constant(false),
                                isMultiline: false
                            )
                        }
                        
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("Dish Recommendations")
                                .font(DesignSystem.Typography.callout)
                                .fontWeight(.medium)
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                            
                            ModernTaskTextField(
                                text: $dishRecommendations,
                                placeholder: "Enter dish recommendations",
                                isFocused: .constant(false),
                                isMultiline: false
                            )
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Best Time to Go")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        ModernTaskTextField(
                            text: $bestTimeToGo,
                            placeholder: "Enter best time to visit",
                            isFocused: .constant(false),
                            isMultiline: false
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Who to Bring")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        ModernTaskTextField(
                            text: $whoToBring,
                            placeholder: "Enter who to bring",
                            isFocused: .constant(false),
                            isMultiline: false
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Entry Fee/Cost")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        ModernTaskTextField(
                            text: $entryFee,
                            placeholder: "Enter cost or entry fee",
                            isFocused: .constant(false),
                            isMultiline: false
                        )
                    }
                }
                
                // Photo Section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Photo")
                        .font(DesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                    }
                    
                    Button {
                        showingImagePicker = true
                    } label: {
                        Label(selectedImage == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                    }
                }
                
                // Visit Status Section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Visit Status")
                        .font(DesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Toggle("I've Been Here", isOn: $hasVisited)
                    
                    if hasVisited {
                        DatePicker("Date Visited", selection: $dateVisited, displayedComponents: .date)
                        Toggle("Would Return", isOn: $wouldReturn)
                    }
                }
                
                if hasVisited {
                    // Ratings Section
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Ratings")
                            .font(DesignSystem.Typography.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        VStack(spacing: 16) {
                            RatingSlider(title: "Overall", rating: $overallRating, color: .orange)
                            RatingSlider(title: "Price", rating: $priceRating, color: .green)
                            RatingSlider(title: "Quality", rating: $qualityRating, color: .blue)
                            RatingSlider(title: "Atmosphere", rating: $atmosphereRating, color: .purple)
                            RatingSlider(title: "Fun Factor", rating: $funFactorRating, color: .pink)
                            RatingSlider(title: "Scenery", rating: $sceneryRating, color: .teal)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Pros")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        ModernTaskTextField(
                            text: $pros,
                            placeholder: "Enter the pros of this place...",
                            isFocused: .constant(false),
                            isMultiline: true
                        )
                        .frame(minHeight: 80)
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Cons")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        ModernTaskTextField(
                            text: $cons,
                            placeholder: "Enter the cons of this place...",
                            isFocused: .constant(false),
                            isMultiline: true
                        )
                        .frame(minHeight: 80)
                    }
                }
                
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Notes")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    ModernTaskTextField(
                        text: $notes,
                        placeholder: "Add any additional notes...",
                        isFocused: .constant(false),
                        isMultiline: true
                    )
                    .frame(minHeight: 100)
                }
                }
                .padding(DesignSystem.Spacing.lg)
                .background(DesignSystem.Colors.background)
            }
            .navigationTitle(place == nil ? "New Place" : "Edit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePlace()
                        dismiss()
                    }
                    .disabled(name.isEmpty || selectedCategory == nil)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }
    
    private func savePlace() {
        let photoData = selectedImage?.jpegData(compressionQuality: 0.8)
        
        if let existingPlace = place {
            // Update existing place
            existingPlace.name = name
            existingPlace.location = location.isEmpty ? "" : location
            existingPlace.address = address.isEmpty ? "" : address
            existingPlace.priceRange = priceRange.isEmpty ? "" : priceRange
            existingPlace.cuisineType = cuisineType.isEmpty ? "" : cuisineType
            existingPlace.bestTimeToGo = bestTimeToGo.isEmpty ? "" : bestTimeToGo
            existingPlace.whoToBring = whoToBring.isEmpty ? "" : whoToBring
            existingPlace.entryFee = entryFee.isEmpty ? "" : entryFee
            existingPlace.dishRecommendations = dishRecommendations.isEmpty ? "" : dishRecommendations
            existingPlace.notes = notes.isEmpty ? "" : notes
            existingPlace.hasVisited = hasVisited
            existingPlace.dateVisited = hasVisited ? dateVisited : Date.distantPast
            existingPlace.wouldReturn = wouldReturn
            existingPlace.priceRating = Int16(priceRating)
            existingPlace.qualityRating = Int16(qualityRating)
            existingPlace.atmosphereRating = Int16(atmosphereRating)
            existingPlace.funFactorRating = Int16(funFactorRating)
            existingPlace.sceneryRating = Int16(sceneryRating)
            existingPlace.overallRating = Int16(overallRating)
            existingPlace.pros = pros.isEmpty ? "" : pros
            existingPlace.cons = cons.isEmpty ? "" : cons
            existingPlace.category = selectedCategory
            existingPlace.photoData = photoData ?? Data()
        } else {
            // Create new place
            let newPlace = Place(
                name: name,
                location: location.isEmpty ? nil : location,
                address: address.isEmpty ? nil : address,
                priceRange: priceRange.isEmpty ? nil : priceRange,
                cuisineType: cuisineType.isEmpty ? nil : cuisineType,
                bestTimeToGo: bestTimeToGo.isEmpty ? nil : bestTimeToGo,
                whoToBring: whoToBring.isEmpty ? nil : whoToBring,
                entryFee: entryFee.isEmpty ? nil : entryFee,
                notes: notes.isEmpty ? nil : notes,
                dishRecommendations: dishRecommendations.isEmpty ? nil : dishRecommendations,
                photoData: photoData,
                dateVisited: hasVisited ? dateVisited : nil,
                wouldReturn: wouldReturn,
                hasVisited: hasVisited,
                priceRating: Int16(priceRating),
                qualityRating: Int16(qualityRating),
                atmosphereRating: Int16(atmosphereRating),
                funFactorRating: Int16(funFactorRating),
                sceneryRating: Int16(sceneryRating),
                overallRating: Int16(overallRating),
                pros: pros.isEmpty ? nil : pros,
                cons: cons.isEmpty ? nil : cons,
                category: selectedCategory
            )
            modelContext.insert(newPlace)
        }
    }
}

// MARK: - Rating Slider
struct RatingSlider: View {
    let title: String
    @Binding var rating: Double
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int(rating))/10")
                    .foregroundColor(.secondary)
            }
            .font(.subheadline)
            
            Slider(value: $rating, in: 1...10, step: 1)
                .tint(color)
        }
    }
}



// MARK: - Preview
struct PlacesMainView_Previews: PreviewProvider {
    static var previews: some View {
        PlacesMainView()
            .modelContainer(for: [PlaceCategory.self, Place.self])
    }
}
