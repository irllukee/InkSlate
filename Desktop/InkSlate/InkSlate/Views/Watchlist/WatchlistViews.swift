import SwiftUI
import SwiftData

// MARK: - AsyncImage View
struct AsyncImageLoader: View {
    let url: URL?
    let placeholder: Image
    
    @StateObject private var imageLoader: ImageLoader
    
    init(url: URL?, placeholder: Image = Image(systemName: "photo")) {
        self.url = url
        self.placeholder = placeholder
        self._imageLoader = StateObject(wrappedValue: ImageLoader(url: url))
    }
    
    var body: some View {
        Group {
            if let image = imageLoader.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
                    .foregroundColor(.gray)
            }
        }
        .onAppear {
            imageLoader.load()
        }
        .onDisappear {
            imageLoader.cancel()
        }
    }
}

// MARK: - Main Watchlist View
struct WatchlistMainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WatchlistItem.addedDate, order: .reverse)
    private var watchlistItems: [WatchlistItem]
    
    @State private var searchText = ""
    @State private var selectedMediaType: MediaType = .movies
    @State private var showingWatchlist = false
    @State private var showingFavorites = false
    
    
    enum MediaType: String, CaseIterable {
        case movies = "Movies"
        case tv = "TV Shows"
        
        var apiValue: String {
            switch self {
            case .movies: return "movie"
            case .tv: return "tv"
            }
        }
    }
    
    private var filteredWatchlist: [WatchlistItem] {
        var items = watchlistItems
        
        // Apply media type filter first (more efficient)
        items = items.filter { $0.mediaType == selectedMediaType.apiValue }
        
        // Apply search filter with optimized string comparison
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            items = items.filter { item in
                item.title.lowercased().contains(searchLower) ||
                item.originalTitle.lowercased().contains(searchLower)
            }
        }
        
        return items
    }
    
    private var favoriteItems: [WatchlistItem] {
        watchlistItems.filter { $0.isFavorite }
    }
    
    private var recentItems: [WatchlistItem] {
        Array(watchlistItems.prefix(6))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Favorites Section
                if !favoriteItems.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Your Favorites")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button("View All") {
                                showingFavorites = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(favoriteItems.prefix(10), id: \.id) { item in
                                    FavoriteCard(item: item)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Recent Additions Section
                if !recentItems.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Recently Added")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button("View All") {
                                showingWatchlist = true
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(recentItems, id: \.id) { item in
                                    RecentCard(item: item)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // Search Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Discover")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                    }
                    
                    SearchView(
                        searchText: $searchText,
                        selectedMediaType: $selectedMediaType,
                        watchlistItems: watchlistItems
                    )
                }
                
                // Empty State
                if watchlistItems.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "tv")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Start Building Your Collection")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text("Search for movies and TV shows to add them to your watchlist")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                }
            }
            .padding()
        }
        .navigationTitle("Movies & TV")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if !favoriteItems.isEmpty {
                        Button {
                            showingFavorites = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                Text("\(favoriteItems.count)")
                            }
                        }
                    }
                    
                    if !watchlistItems.isEmpty {
                        Button {
                            showingWatchlist = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "list.bullet")
                                Text("\(watchlistItems.count)")
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingWatchlist) {
            NavigationView {
                WatchlistView(
                    items: filteredWatchlist,
                    searchText: $searchText,
                    selectedMediaType: $selectedMediaType
                )
                .navigationTitle("My Watchlist")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingWatchlist = false
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingFavorites) {
            NavigationView {
                FavoritesView(
                    items: watchlistItems.filter { $0.isFavorite },
                    searchText: $searchText
                )
                .navigationTitle("Favorites")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingFavorites = false
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Search View
struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Binding var searchText: String
    @Binding var selectedMediaType: WatchlistMainView.MediaType
    let watchlistItems: [WatchlistItem]
    
    @StateObject private var tmdbService = TMDBService.shared
    @StateObject private var searchDebouncer = SearchDebouncer(delay: 0.3)
    @State private var searchResults: [TMDBItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedItem: TMDBItem?
    @State private var showingDetail = false
    @State private var currentPage = 1
    @State private var hasMorePages = false
    @State private var searchTask: Task<Void, Never>?
    
    private var watchlistIds: Set<Int> {
        Set(watchlistItems.map { $0.tmdbId })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Media type filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(WatchlistMainView.MediaType.allCases, id: \.self) { type in
                        Button {
                            selectedMediaType = type
                            // Live search will automatically trigger when searchText changes
                            if !searchText.isEmpty {
                                performSearch()
                            }
                        } label: {
                            Text(type.rawValue)
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedMediaType == type ? Color.accentColor : Color.gray.opacity(0.2))
                                .foregroundColor(selectedMediaType == type ? .white : .primary)
                                .cornerRadius(20)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            
            Divider()
            
            // Search results
            if isLoading {
                Spacer()
                ProgressView("Searching...")
                Spacer()
            } else if let error = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Search Error")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else if searchResults.isEmpty && !searchText.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No Results")
                        .font(.headline)
                    Text("Try searching for a different movie or TV show")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else if searchResults.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("Start Searching")
                        .font(.headline)
                    Text("Type in the search bar to find movies and TV shows")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(searchResults, id: \.id) { item in
                            SearchResultCard(
                                item: item,
                                isInWatchlist: watchlistIds.contains(item.id),
                                onTap: {
                                    selectedItem = item
                                    showingDetail = true
                                },
                                onToggleWatchlist: {
                                    toggleWatchlist(for: item)
                                }
                            )
                        }
                        
                        // Load more button
                        if hasMorePages && !isLoading {
                            Button("Load More") {
                                loadMoreResults()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .gridCellColumns(2)
                        }
                        
                        if isLoading && !searchResults.isEmpty {
                            ProgressView()
                                .gridCellColumns(2)
                        }
                    }
                    .padding()
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search movies and TV shows")
        .onChange(of: searchText) { _, newValue in
            searchDebouncer.searchText = newValue
        }
        .onChange(of: searchDebouncer.debouncedText) { _, newValue in
            // Cancel previous search task
            searchTask?.cancel()
            
            if newValue.isEmpty {
                searchResults = []
                errorMessage = nil
                currentPage = 1
                hasMorePages = false
            } else if newValue.count >= 2 {
                // Perform search immediately since debouncing is handled
                searchTask = Task {
                    if !Task.isCancelled {
                        await MainActor.run {
                            performSearch()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let item = selectedItem {
                SearchDetailView(item: item, isInWatchlist: watchlistIds.contains(item.id))
            }
        }
    }
    
    private func performSearch() {
        guard !searchText.isEmpty else {
            searchResults = []
            return
        }
        
        currentPage = 1
        searchResults = []
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response: TMDBResponse
                
                switch selectedMediaType {
                case .movies:
                    response = try await tmdbService.searchMovies(query: searchText, page: currentPage)
                case .tv:
                    response = try await tmdbService.searchTVShows(query: searchText, page: currentPage)
                }
                
                await MainActor.run {
                    searchResults = response.results
                    hasMorePages = response.totalPages > currentPage
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("Search error: \(error)")
                    if error is DecodingError {
                        errorMessage = "Unable to decode search results. Please try again."
                    } else if let urlError = error as? URLError {
                        switch urlError.code {
                        case .notConnectedToInternet:
                            errorMessage = "No internet connection. Please check your network."
                        case .timedOut:
                            errorMessage = "Search timed out. Please try again."
                        default:
                            errorMessage = "Network error. Please try again."
                        }
                    } else {
                        errorMessage = "Search failed. Please try again."
                    }
                    isLoading = false
                }
            }
        }
    }
    
    private func loadMoreResults() {
        guard !isLoading && hasMorePages else { return }
        
        currentPage += 1
        isLoading = true
        
        Task {
            do {
                let response: TMDBResponse
                
                switch selectedMediaType {
                case .movies:
                    response = try await tmdbService.searchMovies(query: searchText, page: currentPage)
                case .tv:
                    response = try await tmdbService.searchTVShows(query: searchText, page: currentPage)
                }
                
                await MainActor.run {
                    searchResults.append(contentsOf: response.results)
                    hasMorePages = response.totalPages > currentPage
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
    
    private func toggleWatchlist(for item: TMDBItem) {
        // Perform the operation asynchronously to prevent UI hangs
        Task { @MainActor in
            if watchlistIds.contains(item.id) {
                // Remove from watchlist
                if let existingItem = watchlistItems.first(where: { $0.tmdbId == item.id }) {
                    modelContext.delete(existingItem)
                }
            } else {
                // Add to watchlist
                let genreNames = tmdbService.getGenreNames(for: item.genreIds ?? [], mediaType: item.actualMediaType)
                
                let watchlistItem = WatchlistItem(
                    tmdbId: item.id,
                    title: item.displayTitle,
                    originalTitle: item.originalTitle ?? item.originalName ?? item.displayTitle,
                    overview: item.overview,
                    mediaType: item.actualMediaType,
                    posterPath: item.posterPath,
                    backdropPath: item.backdropPath,
                    releaseDate: item.releaseDate,
                    firstAirDate: item.firstAirDate,
                    voteAverage: item.voteAverage,
                    voteCount: item.voteCount,
                    runtime: item.runtime,
                    numberOfSeasons: item.numberOfSeasons,
                    numberOfEpisodes: item.numberOfEpisodes,
                    genres: genreNames
                )
                modelContext.insert(watchlistItem)
            }
        }
    }
}

// MARK: - Search Result Card
struct SearchResultCard: View {
    let item: TMDBItem
    let isInWatchlist: Bool
    let onTap: () -> Void
    let onToggleWatchlist: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Poster image
            AsyncImageLoader(
                url: TMDBService.shared.getPosterURL(path: item.posterPath),
                placeholder: Image(systemName: item.actualMediaType == "movie" ? "film" : "tv")
            )
            .aspectRatio(2/3, contentMode: .fit)
            .frame(height: 200)
            .clipped()
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            .onTapGesture {
                onTap()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                
                if let year = item.releaseDate?.prefix(4) ?? item.firstAirDate?.prefix(4) {
                    Text(String(year))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(String(format: "%.1f", item.voteAverage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        onToggleWatchlist()
                    } label: {
                        Image(systemName: isInWatchlist ? "checkmark.circle.fill" : "plus.circle")
                            .foregroundColor(isInWatchlist ? .green : .blue)
                    }
                }
            }
        }
    }
}

// MARK: - Search Detail View
struct SearchDetailView: View {
    let item: TMDBItem
    let isInWatchlist: Bool
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var watchlistItems: [WatchlistItem]
    
    private var watchlistIds: Set<Int> {
        Set(watchlistItems.map { $0.tmdbId })
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Backdrop image
                    AsyncImageLoader(
                        url: TMDBService.shared.getBackdropURL(path: item.backdropPath),
                        placeholder: Image(systemName: item.actualMediaType == "movie" ? "film" : "tv")
                    )
                    .frame(height: 250)
                    .clipped()
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.displayTitle)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                            Text(String(format: "%.1f", item.voteAverage))
                            Text("•")
                            Text("\(item.voteCount) votes")
                                .foregroundColor(.secondary)
                        }
                        
                        if let year = item.releaseDate?.prefix(4) ?? item.firstAirDate?.prefix(4) {
                            Text(String(year))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let runtime = item.runtime {
                            let hours = runtime / 60
                            let minutes = runtime % 60
                            if hours > 0 {
                                Text("\(hours)h \(minutes)m")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("\(minutes)m")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if !item.overview.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Overview")
                                .font(.headline)
                            Text(item.overview)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
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
                        toggleWatchlist()
                    } label: {
                        Image(systemName: isInWatchlist ? "checkmark.circle.fill" : "plus.circle")
                            .foregroundColor(isInWatchlist ? .green : .blue)
                    }
                }
            }
        }
    }
    
    private func toggleWatchlist() {
        if watchlistIds.contains(item.id) {
            // Remove from watchlist
            if let existingItem = watchlistItems.first(where: { $0.tmdbId == item.id }) {
                modelContext.delete(existingItem)
            }
        } else {
            // Add to watchlist
            let genreNames = TMDBService.shared.getGenreNames(for: item.genreIds ?? [], mediaType: item.actualMediaType)
            
            let watchlistItem = WatchlistItem(
                tmdbId: item.id,
                title: item.displayTitle,
                originalTitle: item.originalTitle ?? item.originalName ?? item.displayTitle,
                overview: item.overview,
                mediaType: item.actualMediaType,
                posterPath: item.posterPath,
                backdropPath: item.backdropPath,
                releaseDate: item.releaseDate,
                firstAirDate: item.firstAirDate,
                voteAverage: item.voteAverage,
                voteCount: item.voteCount,
                runtime: item.runtime,
                numberOfSeasons: item.numberOfSeasons,
                numberOfEpisodes: item.numberOfEpisodes,
                genres: genreNames
            )
            modelContext.insert(watchlistItem)
        }
    }
}

// MARK: - Watchlist View
struct WatchlistView: View {
    let items: [WatchlistItem]
    @Binding var searchText: String
    @Binding var selectedMediaType: WatchlistMainView.MediaType
    
    var body: some View {
        VStack(spacing: 0) {
            if items.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("Your Watchlist is Empty")
                        .font(.headline)
                    Text("Search for movies and TV shows to add them to your watchlist")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                // Item count header
                HStack {
                    Text("\(items.count) items")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(items, id: \.id) { item in
                            WatchlistItemCard(item: item)
                        }
                    }
                    .padding()
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search your watchlist")
    }
}

// MARK: - Watchlist Item Card
struct WatchlistItemCard: View {
    let item: WatchlistItem
    @Environment(\.modelContext) private var modelContext
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                // Poster image
                AsyncImageLoader(
                    url: TMDBService.shared.getPosterURL(path: item.posterPath),
                    placeholder: Image(systemName: item.mediaType == "movie" ? "film" : "tv")
                )
                .aspectRatio(2/3, contentMode: .fit)
                .frame(height: 200)
                .clipped()
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                // Watched badge
                if item.isWatched {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                        Spacer()
                    }
                    .padding(8)
                }
                
                // Personal rating
                if item.personalRating > 0 {
                    VStack {
                        HStack {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", item.personalRating))
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                        Spacer()
                    }
                    .padding(8)
                }
            }
            .onTapGesture {
                showingDetail = true
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.headline)
                    .lineLimit(2)
                
                if !item.releaseYear.isEmpty {
                    Text(item.releaseYear)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Text(String(format: "%.1f", item.voteAverage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button {
                            toggleFavoriteStatus()
                        } label: {
                            Image(systemName: item.isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(item.isFavorite ? .red : .gray)
                        }
                        
                        Button {
                            toggleWatchedStatus()
                        } label: {
                            Image(systemName: item.isWatched ? "eye.fill" : "eye")
                                .foregroundColor(item.isWatched ? .green : .gray)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingDetail) {
            WatchlistDetailView(item: item)
        }
    }
    
    private func toggleWatchedStatus() {
        item.isWatched.toggle()
        if item.isWatched {
            item.watchedDate = Date()
        } else {
            item.watchedDate = Date.distantPast
            item.personalRating = 0.0
        }
    }
    
    private func toggleFavoriteStatus() {
        item.isFavorite.toggle()
    }
}

// MARK: - Watchlist Detail View
struct WatchlistDetailView: View {
    let item: WatchlistItem
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var personalRating: Double = 0
    @State private var notes: String = ""
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Backdrop image
                    AsyncImageLoader(
                        url: TMDBService.shared.getBackdropURL(path: item.backdropPath),
                        placeholder: Image(systemName: item.mediaType == "movie" ? "film" : "tv")
                    )
                    .frame(height: 250)
                    .clipped()
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.displayTitle)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                            Text(String(format: "%.1f", item.voteAverage))
                            Text("•")
                            Text("\(item.voteCount) votes")
                                .foregroundColor(.secondary)
                        }
                        
                        if !item.releaseYear.isEmpty {
                            Text(item.releaseYear)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if !item.runtimeText.isEmpty {
                            Text(item.runtimeText)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if !item.overview.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Overview")
                                .font(.headline)
                            Text(item.overview)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Watch status
                    Section {
                        Toggle("Mark as Watched", isOn: .constant(item.isWatched))
                            .disabled(true)
                        
                        if item.isWatched, item.watchedDate != Date.distantPast {
                            HStack {
                                Image(systemName: "calendar")
                                Text("Watched: \(item.watchedDate, style: .date)")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
                        }
                    } header: {
                        Text("Watch Status")
                            .font(.headline)
                    }
                    
                    // Personal rating
                    if item.isWatched {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Your Rating")
                                    Spacer()
                                    Text(personalRating > 0 ? String(format: "%.1f", personalRating) : "Not rated")
                                        .foregroundColor(.secondary)
                                }
                                
                                Slider(value: $personalRating, in: 0...10, step: 0.5)
                                    .tint(.yellow)
                                
                                HStack {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: personalRating >= Double(star * 2) ? "star.fill" : "star")
                                            .foregroundColor(.yellow)
                                            .onTapGesture {
                                                personalRating = Double(star * 2)
                                            }
                                    }
                                }
                            }
                        } header: {
                            Text("Personal Rating")
                                .font(.headline)
                        }
                    }
                    
                    // Notes
                    Section {
                        ModernTaskTextField(
                            text: $notes,
                            placeholder: "Add your thoughts and review...",
                            isFocused: .constant(false),
                            isMultiline: true
                        )
                        .frame(minHeight: 100)
                    } header: {
                        Text("Notes & Review")
                            .font(.headline)
                    }
                }
                .padding()
            }
            .navigationTitle("Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        saveChanges()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Remove", role: .destructive) {
                        showingDeleteAlert = true
                    }
                }
            }
            .alert("Remove from Watchlist", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    modelContext.delete(item)
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to remove this item from your watchlist?")
            }
            .onAppear {
                personalRating = item.personalRating
                notes = item.notes
            }
        }
    }
    
    private func saveChanges() {
        item.personalRating = personalRating > 0 ? personalRating : 0.0
        item.notes = notes.isEmpty ? "" : notes
    }
}



// MARK: - Favorite Card
struct FavoriteCard: View {
    let item: WatchlistItem
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                AsyncImageLoader(
                    url: TMDBService.shared.getPosterURL(path: item.posterPath),
                    placeholder: Image(systemName: item.mediaType == "movie" ? "film" : "tv")
                )
                .aspectRatio(2/3, contentMode: .fit)
                .frame(width: 120, height: 180)
                .clipped()
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                // Favorite badge
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "heart.fill")
                            .font(.title3)
                            .foregroundColor(.red)
                            .background(Color.white)
                            .clipShape(Circle())
                            .padding(8)
                    }
                    Spacer()
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if !item.releaseYear.isEmpty {
                    Text(item.releaseYear)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(String(format: "%.1f", item.voteAverage))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 120)
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            WatchlistDetailView(item: item)
        }
    }
}

// MARK: - Recent Card
struct RecentCard: View {
    let item: WatchlistItem
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AsyncImageLoader(
                url: TMDBService.shared.getPosterURL(path: item.posterPath),
                placeholder: Image(systemName: item.mediaType == "movie" ? "film" : "tv")
            )
            .aspectRatio(2/3, contentMode: .fit)
            .frame(width: 100, height: 150)
            .clipped()
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if !item.releaseYear.isEmpty {
                    Text(item.releaseYear)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(String(format: "%.1f", item.voteAverage))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: 100)
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            WatchlistDetailView(item: item)
        }
    }
}

// MARK: - Favorites View
struct FavoritesView: View {
    let items: [WatchlistItem]
    @Binding var searchText: String
    
    private var filteredItems: [WatchlistItem] {
        if searchText.isEmpty {
            return items
        } else {
            let searchLower = searchText.lowercased()
            return items.filter { item in
                item.title.lowercased().contains(searchLower) ||
                item.originalTitle.lowercased().contains(searchLower)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if filteredItems.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "heart")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text("No Favorites Yet")
                        .font(.headline)
                    Text("Star items in your watchlist to add them to favorites")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                // Item count header
                HStack {
                    Text("\(filteredItems.count) favorites")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(filteredItems, id: \.id) { item in
                            WatchlistItemCard(item: item)
                        }
                    }
                    .padding()
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search favorites")
    }
}

// MARK: - Preview

struct WatchlistMainView_Previews: PreviewProvider {
    static var previews: some View {
        WatchlistMainView()
            .modelContainer(for: [WatchlistItem.self])
    }
}
