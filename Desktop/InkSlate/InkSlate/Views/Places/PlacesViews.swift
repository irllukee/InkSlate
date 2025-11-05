import SwiftUI
import CoreData
import UIKit

// MARK: - Date Formatter
private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    return formatter
}()

// MARK: - Main Places View
struct PlacesMainView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PlaceCategory.name, ascending: true)]
    ) private var allCategories: FetchedResults<PlaceCategory>
    
    @State private var selectedTab: PlaceType = .restaurant
    
    enum PlaceType: String, CaseIterable {
        case restaurant = "Restaurants"
        case activity = "Activities"
        case place = "Places"
    }
    
    private var categories: [PlaceCategory] {
        Array(allCategories).filter { category in
            // Since PlaceCategory doesn't have a 'type' property, we'll filter by name or use all categories
            // You may want to add a 'type' attribute to PlaceCategory in the Core Data model
            return true // For now, show all categories
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header right below navigation bar
            HStack {
                Text("Places")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Spacer()
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.md)

            // Segmented control
            HStack {
                Picker("Type", selection: $selectedTab) {
                    ForEach(PlaceType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding(.horizontal, DesignSystem.Spacing.sm)
            .padding(.bottom, DesignSystem.Spacing.sm)

            // Content
            PlacesCategoryView(
                type: selectedTab.rawValue.lowercased(),
                categories: categories
            )
        }
    }
}

// MARK: - Places Category View
struct PlacesCategoryView: View {
    let type: String
    let categories: [PlaceCategory]
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Place.name, ascending: true)],
        animation: .default)
    private var allPlaces: FetchedResults<Place>
    
    @State private var showingNewCategory = false
    
    private var places: [Place] {
        Array(allPlaces)
    }
    
    var body: some View {
        List {
            Section("Categories") {
                ForEach(categories) { category in
                    NavigationLink(destination: PlacesListView(
                        category: category,
                        type: type
                    )) {
                        HStack {
                            Image(systemName: iconForType(type))
                                .foregroundColor(.black)
                            Text(category.name ?? "Unnamed Category")
                            Spacer()
                            Text("\(places.filter { $0.category?.id == category.id }.count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteCategories)
                
                Button {
                    showingNewCategory = true
                } label: {
                    Label("New Category", systemImage: "plus.circle.fill")
                        .foregroundColor(.black)
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
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
    
    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            let category = categories[index]
            let placesInCategory = places.filter { $0.category?.id == category.id }
            for place in placesInCategory {
                place.category = nil
            }
            viewContext.delete(category)
        }
    }
}

// MARK: - New Category View
struct NewCategoryView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    
    let type: String
    @State private var categoryName = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Category Name", text: $categoryName)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark)
            .accentColor(.black)
            .navigationBarBackButtonHidden(false)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.black)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let category = PlaceCategory(context: viewContext)
                        category.name = categoryName
                        category.id = UUID()
                        category.createdDate = Date()
                        category.modifiedDate = Date()
                        viewContext.insert(category)
                        dismiss()
                    }
                    .disabled(categoryName.isEmpty)
                    .foregroundColor(.black)
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
    
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Place.name, ascending: true)],
        animation: .default)
    private var allPlaces: FetchedResults<Place>
    
    @State private var showingNewPlace = false
    @State private var selectedPlace: Place?
    
    private var places: [Place] {
        var filtered: [Place]
        
        if wishlistOnly {
            filtered = Array(allPlaces).filter { !$0.isVisited }
        } else if favoritesOnly {
            filtered = Array(allPlaces).filter { $0.isVisited && $0.rating >= 8 }
        } else if let category = category {
            filtered = Array(allPlaces).filter { $0.category?.id == category.id }
        } else {
            filtered = []
        }
        
        return filtered.sorted { first, second in
            if first.isVisited != second.isVisited {
                return !first.isVisited
            }
            return first.rating > second.rating
        }
    }
    
    private var title: String {
        if wishlistOnly { return "Wishlist" }
        if favoritesOnly { return "Top Rated" }
        return category?.name ?? "Places"
    }
    
    var body: some View {
        List {
            ForEach(places) { place in
                Button {
                    selectedPlace = place
                } label: {
                    PlaceRowView(place: place)
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewContext.delete(places[index])
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark)
        .accentColor(.black)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            Button {
                showingNewPlace = true
            } label: {
                Image(systemName: "plus")
                    .foregroundColor(.black)
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
            if let photoData = place.photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .overlay(Image(systemName: "photo").foregroundColor(.gray))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(place.name ?? "Unnamed Place")
                        .font(.headline)
                    if !place.isVisited {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.black)
                    }
                }
                
                if !(place.address?.isEmpty ?? true) {
                    Text(place.address ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                HStack(spacing: 8) {
                    if place.isVisited {
                        Label("\(place.rating)/10", systemImage: "star.fill")
                            .font(.caption)
                            .foregroundColor(.black)
                    }
                    
                    if !(place.notes?.isEmpty ?? true) {
                        Text(place.notes ?? "")
                            .font(.caption)
                            .foregroundColor(.gray)
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
                VStack(spacing: 24) {
                    // Photo Section
                    if let photoData = place.photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(16)
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                    
                    // Basic Info Card
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(place.name ?? "Unnamed Place")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            if !(place.address?.isEmpty ?? true) {
                                HStack(spacing: 8) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundColor(.black)
                                        .font(.subheadline)
                                    Text(place.address ?? "")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if !(place.address?.isEmpty ?? true) {
                                HStack(spacing: 8) {
                                    Image(systemName: "location")
                                        .foregroundColor(.black)
                                        .font(.subheadline)
                                    Text(place.address ?? "")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        // Quick Info Tags
                        HStack(spacing: 12) {
                            if !(place.notes?.isEmpty ?? true) {
                                HStack(spacing: 4) {
                                    Image(systemName: "note.text")
                                        .foregroundColor(.black)
                                        .font(.caption)
                                    Text(place.notes ?? "")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                            
                            if !(place.cuisineType?.isEmpty ?? true) {
                                HStack(spacing: 4) {
                                    Image(systemName: "fork.knife")
                                        .foregroundColor(.black)
                                        .font(.caption)
                                    Text(place.cuisineType ?? "")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(16)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    
                    // Additional Details Card
                    if !(place.bestTimeToGo?.isEmpty ?? true) || !(place.whoToBring?.isEmpty ?? true) || !(place.entryFee?.isEmpty ?? true) || !(place.dishRecommendations?.isEmpty ?? true) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Details")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(spacing: 12) {
                                if !(place.bestTimeToGo?.isEmpty ?? true) {
                                    DetailRow(icon: "clock", iconColor: .black, title: "Best Time", value: place.bestTimeToGo ?? "")
                                }
                                
                                if !(place.whoToBring?.isEmpty ?? true) {
                                    DetailRow(icon: "person.2", iconColor: .black, title: "Who to Bring", value: place.whoToBring ?? "")
                                }
                                
                                if !(place.entryFee?.isEmpty ?? true) {
                                    DetailRow(icon: "ticket", iconColor: .black, title: "Entry Fee", value: place.entryFee ?? "")
                                }
                                
                                if !(place.dishRecommendations?.isEmpty ?? true) {
                                    DetailRow(icon: "star.circle", iconColor: .black, title: "Recommended", value: place.dishRecommendations ?? "")
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    
                    // Ratings Card
                    if place.isVisited {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Your Experience")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            VStack(spacing: 12) {
                                RatingRow(title: "Overall", rating: place.overallRating, color: .black)
                                RatingRow(title: "Price", rating: place.priceRating, color: .gray)
                                RatingRow(title: "Quality", rating: place.qualityRating, color: .black)
                                RatingRow(title: "Atmosphere", rating: place.atmosphereRating, color: .gray)
                                
                                // Show additional ratings for non-restaurant places
                                if place.category?.name?.lowercased().contains("restaurant") != true {
                                    RatingRow(title: "Fun Factor", rating: place.funFactorRating, color: .black)
                                    RatingRow(title: "Scenery", rating: place.sceneryRating, color: .gray)
                                }
                            }
                            
                            Divider()
                            
                            VStack(spacing: 8) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.black)
                                        .font(.subheadline)
                                    Text("Visited: \(place.visitedDate ?? Date(), formatter: dateFormatter)")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack {
                                    Image(systemName: place.wouldReturn ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(place.wouldReturn ? .black : .gray)
                                        .font(.subheadline)
                                    Text(place.wouldReturn ? "Would return" : "Would not return")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(16)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                    
                    // Notes Card - Moved to bottom
                    if !(place.notes?.isEmpty ?? true), let notes = place.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Notes")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text(notes)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(nil)
                        }
                        .padding(16)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark)
            .accentColor(.black)
            .navigationBarBackButtonHidden(false)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(.black)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditSheet = true
                    }
                    .foregroundColor(.black)
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                PlaceEditorView(category: place.category, place: place, type: "restaurants")
            }
        }
    }
}

// MARK: - Detail Row
struct DetailRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.subheadline)
                .frame(width: 20, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                
                Text(value)
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
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
                .font(.subheadline)
                .fontWeight(.medium)
            
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
                .fontWeight(.medium)
        }
    }
}

// MARK: - Place Editor View (DETAILED)
struct PlaceEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \PlaceCategory.name, ascending: true)],
        animation: .default)
    private var allCategories: FetchedResults<PlaceCategory>
    
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
    @State private var notes = ""
    @State private var dishRecommendations = ""
    @State private var hasVisited = false
    @State private var wouldReturn = true
    @State private var ratingText = "5"
    @State private var priceRatingText = "5"
    @State private var qualityRatingText = "5"
    @State private var atmosphereRatingText = "5"
    @State private var funFactorRatingText = "5"
    @State private var sceneryRatingText = "5"
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var selectedCategory: PlaceCategory?
    @State private var dateVisited = Date()
    
    private var categories: [PlaceCategory] {
        Array(allCategories) // Show all categories since PlaceCategory doesn't have a 'type' property
    }
    
    init(category: PlaceCategory?, place: Place?, type: String) {
        self.category = category
        self.place = place
        self.type = type
        
        _selectedCategory = State(initialValue: place?.category ?? category)
        _name = State(initialValue: place?.name ?? "")
        _address = State(initialValue: place?.address ?? "")
        _notes = State(initialValue: place?.notes ?? "")
        _hasVisited = State(initialValue: place?.isVisited ?? false)
        _ratingText = State(initialValue: String(place?.rating ?? 5))
        _dateVisited = State(initialValue: place?.visitedDate ?? Date())
        
        // Initialize with existing place data or defaults
        _location = State(initialValue: place?.city ?? "")
        _priceRange = State(initialValue: place?.priceRange ?? "")
        _cuisineType = State(initialValue: place?.cuisineType ?? "")
        _bestTimeToGo = State(initialValue: place?.bestTimeToGo ?? "")
        _whoToBring = State(initialValue: place?.whoToBring ?? "")
        _entryFee = State(initialValue: place?.entryFee ?? "")
        _dishRecommendations = State(initialValue: place?.dishRecommendations ?? "")
        _wouldReturn = State(initialValue: place?.wouldReturn ?? true)
        _priceRatingText = State(initialValue: String(place?.priceRating ?? 5))
        _qualityRatingText = State(initialValue: String(place?.qualityRating ?? 5))
        _atmosphereRatingText = State(initialValue: String(place?.atmosphereRating ?? 5))
        _funFactorRatingText = State(initialValue: String(place?.funFactorRating ?? 5))
        _sceneryRatingText = State(initialValue: String(place?.sceneryRating ?? 5))
        
        // Initialize photo data
        _selectedImage = State(initialValue: place?.photoData != nil ? UIImage(data: place!.photoData!) : nil)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Info") {
                    TextField("Name", text: $name)
                    TextField("Location/City", text: $location)
                    TextField("Address", text: $address)
                    
                    Picker("Category", selection: $selectedCategory) {
                        Text("Select Category").tag(nil as PlaceCategory?)
                        ForEach(categories) { cat in
                            Text(cat.name ?? "Unnamed Category").tag(cat as PlaceCategory?)
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
                        TextField("Cuisine Type", text: $cuisineType)
                        TextField("Dish Recommendations", text: $dishRecommendations)
                    }
                    
                    TextField("Best Time to Go", text: $bestTimeToGo)
                    TextField("Who to Bring", text: $whoToBring)
                    
                    if type != "restaurants" {
                        TextField("Entry Fee", text: $entryFee)
                    }
                }
                
                Section("Photo") {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(8)
                    }
                    
                    Button {
                        showingImagePicker = true
                    } label: {
                        Label(selectedImage == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                            .foregroundColor(.black)
                    }
                }
                
                Section("Visit Status") {
                    Toggle("I've Been Here", isOn: $hasVisited)
                    
                    if hasVisited {
                        DatePicker("Date Visited", selection: $dateVisited, displayedComponents: .date)
                        Toggle("Would Return", isOn: $wouldReturn)
                    }
                }
                
                if hasVisited {
                    Section("Ratings (1-10)") {
                        HStack {
                            Text("Overall")
                            Spacer()
                            TextField("5", text: $ratingText)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Price")
                            Spacer()
                            TextField("5", text: $priceRatingText)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Quality")
                            Spacer()
                            TextField("5", text: $qualityRatingText)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        HStack {
                            Text("Atmosphere")
                            Spacer()
                            TextField("5", text: $atmosphereRatingText)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                .multilineTextAlignment(.trailing)
                        }
                        
                        if type != "restaurants" {
                            HStack {
                                Text("Fun Factor")
                                Spacer()
                                TextField("5", text: $funFactorRatingText)
                                    .keyboardType(.numberPad)
                                    .frame(width: 60)
                                    .multilineTextAlignment(.trailing)
                            }
                            
                            HStack {
                                Text("Scenery")
                                Spacer()
                                TextField("5", text: $sceneryRatingText)
                                    .keyboardType(.numberPad)
                                    .frame(width: 60)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(height: 100)
                }
            }
            .navigationTitle(place == nil ? "New Place" : "Edit Place")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark)
            .accentColor(.black)
            .navigationBarBackButtonHidden(false)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.black)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePlace()
                        dismiss()
                    }
                    .disabled(name.isEmpty || selectedCategory == nil)
                    .foregroundColor(.black)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
        }
    }
    
    private func savePlace() {
        let rating = Int16(ratingText) ?? 5
        let priceRating = Int16(priceRatingText) ?? 5
        let qualityRating = Int16(qualityRatingText) ?? 5
        let atmosphereRating = Int16(atmosphereRatingText) ?? 5
        let funFactorRating = Int16(funFactorRatingText) ?? 5
        let sceneryRating = Int16(sceneryRatingText) ?? 5
        
        if let existingPlace = place {
            existingPlace.name = name
            existingPlace.address = address
            existingPlace.city = location
            existingPlace.notes = notes
            existingPlace.isVisited = hasVisited
            existingPlace.rating = rating
            existingPlace.visitedDate = hasVisited ? dateVisited : nil
            existingPlace.category = selectedCategory
            existingPlace.priceRange = priceRange
            existingPlace.cuisineType = cuisineType
            existingPlace.bestTimeToGo = bestTimeToGo
            existingPlace.whoToBring = whoToBring
            existingPlace.entryFee = entryFee
            existingPlace.dishRecommendations = dishRecommendations
            existingPlace.wouldReturn = wouldReturn
            existingPlace.overallRating = rating
            existingPlace.priceRating = priceRating
            existingPlace.qualityRating = qualityRating
            existingPlace.atmosphereRating = atmosphereRating
            existingPlace.funFactorRating = funFactorRating
            existingPlace.sceneryRating = sceneryRating
            if let image = selectedImage {
                existingPlace.photoData = image.jpegData(compressionQuality: 0.8)
            }
            existingPlace.modifiedDate = Date()
        } else {
            let newPlace = Place(context: viewContext)
            newPlace.id = UUID()
            newPlace.name = name
            newPlace.address = address
            newPlace.city = location
            newPlace.notes = notes
            newPlace.isVisited = hasVisited
            newPlace.rating = rating
            newPlace.visitedDate = hasVisited ? dateVisited : nil
            newPlace.category = selectedCategory
            newPlace.priceRange = priceRange
            newPlace.cuisineType = cuisineType
            newPlace.bestTimeToGo = bestTimeToGo
            newPlace.whoToBring = whoToBring
            newPlace.entryFee = entryFee
            newPlace.dishRecommendations = dishRecommendations
            newPlace.wouldReturn = wouldReturn
            newPlace.overallRating = rating
            newPlace.priceRating = priceRating
            newPlace.qualityRating = qualityRating
            newPlace.atmosphereRating = atmosphereRating
            newPlace.funFactorRating = funFactorRating
            newPlace.sceneryRating = sceneryRating
            if let image = selectedImage {
                newPlace.photoData = image.jpegData(compressionQuality: 0.8)
            }
            newPlace.createdDate = Date()
            newPlace.modifiedDate = Date()
            viewContext.insert(newPlace)
        }
        
        try? viewContext.save()
    }
}


// MARK: - Image Picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}