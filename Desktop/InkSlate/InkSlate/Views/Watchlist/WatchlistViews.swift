import SwiftUI
import SwiftData

// MARK: - Image Loader with NSCache
class ImageLoader: ObservableObject {
    private static let cache = NSCache<NSURL, UIImage>()
    
    @Published var image: UIImage?
    private var task: URLSessionDataTask?
    private let url: URL?
    
    init(url: URL?) {
        self.url = url
    }
    
    func load() {
        guard let url = url else { return }
        
        if let cached = ImageLoader.cache.object(forKey: url as NSURL) {
            self.image = cached
            return
        }
        
        task = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self,
                  let data = data,
                  let uiImage = UIImage(data: data) else {
                return
            }
            
            ImageLoader.cache.setObject(uiImage, forKey: url as NSURL)
            
            DispatchQueue.main.async {
                self.image = uiImage
            }
        }
        task?.resume()
    }
    
    func cancel() {
        task?.cancel()
        task = nil
    }
}

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
    @State private var showingWatchlist = false
    @State private var showingFavorites = false
    @StateObject private var searchDebouncer = SearchDebouncer(delay: 0.5)
    @FocusState private var isSearchFocused: Bool
    
    // Search states
    @StateObject private var tmdbService = TMDBService.shared
    @State private var searchResults: [TMDBItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedItem: TMDBItem?
    @State private var showingDetail = false
    @State private var currentPage = 1
    @State private var hasMorePages = false
    @State private var searchTask: Task<Void, Never>?
    
    private var filteredWatchlist: [WatchlistItem] {
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            return watchlistItems.filter { item in
                item.title.lowercased().contains(searchLower) ||
                item.originalTitle.lowercased().contains(searchLower)
            }
        }
        return watchlistItems
    }
    
    private var favoriteItems: [WatchlistItem] {
        watchlistItems.filter { $0.isFavorite }
    }
    
    private var recentItems: [WatchlistItem] {
        Array(watchlistItems.prefix(6))
    }
    
    private var watchlistIds: Set<Int> {
        Set(watchlistItems.map { $0.tmdbId })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                HStack {
                    Text("Movies & TV")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                }
                .padding(.horizontal)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search movies and TV shows", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .focused($isSearchFocused)
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                            errorMessage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if isSearchFocused {
                        Button {
                            isSearchFocused = false
                        } label: {
                            Image(systemName: "keyboard.chevron.compact.down")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                .onChange(of: searchText) { _, newValue in
                    searchDebouncer.searchText = newValue
                }
                .onChange(of: searchDebouncer.debouncedText) { _, newValue in
                    searchTask?.cancel()
                    
                    if newValue.isEmpty {
                        searchResults = []
                        errorMessage = nil
                        currentPage = 1
                        hasMorePages = false
                    } else if newValue.count >= 2 {
                        performSearch()
                    }
                }
            }
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            
            ScrollView {
                VStack(spacing: 24) {
                    // Show search results when searching
                    if !searchText.isEmpty && searchText.count >= 2 {
                        if isLoading && searchResults.isEmpty {
                            ProgressView("Searching...")
                                .padding(.top, 40)
                        } else if let error = errorMessage {
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
                                    .padding(.horizontal)
                            }
                            .padding(.top, 40)
                        } else if searchResults.isEmpty {
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
                                    .padding(.horizontal)
                            }
                            .padding(.top, 40)
                        } else {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ], spacing: 20) {
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
                                
                                if hasMorePages && !isLoading {
                                    Button {
                                        loadMoreResults()
                                    } label: {
                                        Text("Load More")
                                            .fontWeight(.medium)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(10)
                                    }
                                    .gridCellColumns(2)
                                }
                                
                                if isLoading && !searchResults.isEmpty {
                                    ProgressView()
                                        .gridCellColumns(2)
                                        .padding()
                                }
                            }
                            .padding()
                        }
                    } else {
                        // Show regular content when not searching
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
                                .padding(.horizontal)
                                
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
                                .padding(.horizontal)
                                
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
                        
                        // Popular Movies Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Popular Movies")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            PopularMoviesView(watchlistItems: watchlistItems)
                        }
                        
                        // Popular TV Shows Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Popular TV Shows")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            PopularTVShowsView(watchlistItems: watchlistItems)
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
                                    .padding(.horizontal)
                            }
                            .padding(.top, 40)
                        }
                    }
                }
                .padding(.vertical)
            }
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
                    searchText: $searchText
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
                    items: favoriteItems,
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
        .sheet(isPresented: $showingDetail) {
            if let item = selectedItem {
                SearchDetailView(
                    item: item,
                    isInWatchlist: watchlistIds.contains(item.id),
                    watchlistItems: watchlistItems
                )
            }
        }
    }
    
    // MARK: - Search Methods
    private func performSearch() {
        guard !searchText.isEmpty, searchText.count >= 2 else {
            searchResults = []
            return
        }
        
        searchTask?.cancel()
        
        currentPage = 1
        searchResults = []
        isLoading = true
        errorMessage = nil
        
        searchTask = Task {
            do {
                // Small delay to avoid rapid-fire API calls
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                try Task.checkCancellation()
                
                // Search both movies and TV shows
                let response = try await tmdbService.multiSearch(query: searchText, page: currentPage)
                
                try Task.checkCancellation()
                
                // Filter results to only include movies and TV shows (exclude people, etc.)
                let filteredResults = response.results.filter { 
                    $0.actualMediaType == "movie" || $0.actualMediaType == "tv" 
                }
                
                await MainActor.run {
                    searchResults = filteredResults
                    hasMorePages = response.totalPages > currentPage
                    errorMessage = nil // Clear any previous errors
                    isLoading = false
                }
            } catch is CancellationError {
                await MainActor.run {
                    isLoading = false
                    errorMessage = nil // Don't show error for cancelled searches
                }
            } catch {
                await MainActor.run {
                    print("🔍 Search Error: \(error.localizedDescription)")
                    if let urlError = error as? URLError {
                        switch urlError.code {
                        case .notConnectedToInternet:
                            errorMessage = "No internet connection"
                        case .timedOut:
                            errorMessage = "Request timed out"
                        case .cannotFindHost, .cannotConnectToHost:
                            errorMessage = "Cannot connect to server"
                        default:
                            errorMessage = "Network error: \(urlError.code.rawValue)"
                        }
                    } else if let decodingError = error as? DecodingError {
                        print("🔍 Decoding Error: \(decodingError)")
                        errorMessage = "Invalid response from server"
                    } else {
                        errorMessage = "Search error. Please try again."
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
                // Search both movies and TV shows
                let response = try await tmdbService.multiSearch(query: searchText, page: currentPage)
                
                // Filter results to only include movies and TV shows
                let filteredResults = response.results.filter { 
                    $0.actualMediaType == "movie" || $0.actualMediaType == "tv" 
                }
                
                await MainActor.run {
                    searchResults.append(contentsOf: filteredResults)
                    hasMorePages = response.totalPages > currentPage
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    print("🔍 Load More Error: \(error.localizedDescription)")
                    errorMessage = "Failed to load more results"
                    isLoading = false
                }
            }
        }
    }
    
    private func toggleWatchlist(for item: TMDBItem) {
        if watchlistIds.contains(item.id) {
            if let existingItem = watchlistItems.first(where: { $0.tmdbId == item.id }) {
                modelContext.delete(existingItem)
                try? modelContext.save()
            }
        } else {
            let genreNames = tmdbService.getGenreNames(for: item.genreIds ?? [], mediaType: item.actualMediaType)
            
            let watchlistItem = WatchlistItem(
                tmdbId: item.id,
                title: item.displayTitle,
                originalTitle: item.originalTitle ?? item.originalName ?? item.displayTitle,
                overview: item.safeOverview,
                mediaType: item.actualMediaType,
                posterPath: item.posterPath,
                backdropPath: item.backdropPath,
                releaseDate: item.releaseDate,
                firstAirDate: item.firstAirDate,
                voteAverage: item.safeVoteAverage,
                voteCount: item.safeVoteCount,
                runtime: item.runtime,
                numberOfSeasons: item.numberOfSeasons,
                numberOfEpisodes: item.numberOfEpisodes,
                genres: genreNames
            )
            modelContext.insert(watchlistItem)
            try? modelContext.save()
        }
    }
}

// MARK: - Search Result Card (Fixed sizing)
struct SearchResultCard: View {
    let item: TMDBItem
    let isInWatchlist: Bool
    let onTap: () -> Void
    let onToggleWatchlist: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                AsyncImageLoader(
                    url: TMDBService.shared.getPosterURL(path: item.posterPath),
                    placeholder: Image(systemName: item.actualMediaType == "movie" ? "film" : "tv")
                )
                .aspectRatio(2/3, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 240)
                .clipped()
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .onTapGesture {
                    onTap()
                }
                
                // Watchlist button overlay
                Button {
                    onToggleWatchlist()
                } label: {
                    Image(systemName: isInWatchlist ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.title3)
                        .foregroundColor(isInWatchlist ? .green : .blue)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding(8)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                if let year = item.releaseDate?.prefix(4) ?? item.firstAirDate?.prefix(4) {
                    Text(String(year))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(String(format: "%.1f", item.safeVoteAverage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Search Detail View (FIXED - Now fetches full details)
struct SearchDetailView: View {
    let item: TMDBItem
    let isInWatchlist: Bool
    let watchlistItems: [WatchlistItem]
    
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var tmdbService = TMDBService.shared
    
    @State private var detailedItem: TMDBItem?
    @State private var cast: [CastMember] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    private var watchlistIds: Set<Int> {
        Set(watchlistItems.map { $0.tmdbId })
    }
    
    private var isFavorite: Bool {
        watchlistItems.first(where: { $0.tmdbId == displayItem.id })?.isFavorite ?? false
    }
    
    private var displayItem: TMDBItem {
        detailedItem ?? item
    }
    
    var body: some View {
        ScrollView {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView("Loading details...")
                    Spacer()
                }
                .frame(minHeight: 400)
            } else if let error = errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text("Failed to Load Details")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                VStack(alignment: .leading, spacing: 20) {
                    AsyncImageLoader(
                        url: TMDBService.shared.getBackdropURL(path: displayItem.backdropPath),
                        placeholder: Image(systemName: displayItem.actualMediaType == "movie" ? "film" : "tv")
                    )
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(displayItem.displayTitle)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                            Text(String(format: "%.1f", displayItem.safeVoteAverage))
                                .fontWeight(.medium)
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("\(displayItem.safeVoteCount) votes")
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)
                        
                        HStack(spacing: 12) {
                            if let year = displayItem.releaseDate?.prefix(4) ?? displayItem.firstAirDate?.prefix(4) {
                                Text(String(year))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let runtime = displayItem.runtime, runtime > 0 {
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
                            
                            if let seasons = displayItem.numberOfSeasons, seasons > 0 {
                                Text("\(seasons) Season\(seasons > 1 ? "s" : "")")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let genres = displayItem.genres, !genres.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(genres, id: \.self) { genre in
                                        Text(genre)
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .cornerRadius(16)
                                    }
                                }
                            }
                        }
                    }
                    
                    if !displayItem.safeOverview.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Overview")
                                .font(.headline)
                            Text(displayItem.safeOverview)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    if !cast.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Cast")
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(cast.prefix(10), id: \.id) { member in
                                        VStack(spacing: 8) {
                                            AsyncImageLoader(
                                                url: TMDBService.shared.getPosterURL(path: member.profilePath),
                                                placeholder: Image(systemName: "person.circle.fill")
                                            )
                                            .aspectRatio(2/3, contentMode: .fill)
                                            .frame(width: 80, height: 120)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                            )
                                            
                                            Text(member.name)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                                .frame(width: 80)
                                            
                                            Text(member.character)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.center)
                                                .frame(width: 80)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    VStack(spacing: 12) {
                        Button {
                            toggleWatchlist()
                        } label: {
                            HStack {
                                Image(systemName: watchlistIds.contains(displayItem.id) ? "checkmark.circle.fill" : "plus.circle.fill")
                                Text(watchlistIds.contains(displayItem.id) ? "Remove from Watchlist" : "Add to Watchlist")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(watchlistIds.contains(displayItem.id) ? Color.red : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        
                        Button {
                            toggleFavorite()
                        } label: {
                            HStack {
                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                                Text(isFavorite ? "Remove from Favorites" : "Add to Favorites")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isFavorite ? Color.pink : Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                    }
                    .padding(.top, 8)
                }
                .padding()
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .onAppear {
            loadDetails()
        }
    }
    
    private func loadDetails() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let details = try await tmdbService.getDetails(id: item.id, mediaType: item.actualMediaType)
                let credits = try await tmdbService.getCredits(id: item.id, mediaType: item.actualMediaType)
                
                await MainActor.run {
                    detailedItem = details
                    cast = credits.cast
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Could not load details"
                    detailedItem = item
                    isLoading = false
                }
            }
        }
    }
    
    private func toggleWatchlist() {
        if watchlistIds.contains(displayItem.id) {
            if let existingItem = watchlistItems.first(where: { $0.tmdbId == displayItem.id }) {
                modelContext.delete(existingItem)
                try? modelContext.save()
                dismiss()
            }
        } else {
            let genreNames: String
            if let genres = displayItem.genres {
                genreNames = genres.joined(separator: ", ")
            } else {
                genreNames = TMDBService.shared.getGenreNames(for: displayItem.genreIds ?? [], mediaType: displayItem.actualMediaType)
            }
            
            let watchlistItem = WatchlistItem(
                tmdbId: displayItem.id,
                title: displayItem.displayTitle,
                originalTitle: displayItem.originalTitle ?? displayItem.originalName ?? displayItem.displayTitle,
                overview: displayItem.safeOverview,
                mediaType: displayItem.actualMediaType,
                posterPath: displayItem.posterPath,
                backdropPath: displayItem.backdropPath,
                releaseDate: displayItem.releaseDate,
                firstAirDate: displayItem.firstAirDate,
                voteAverage: displayItem.safeVoteAverage,
                voteCount: displayItem.safeVoteCount,
                runtime: displayItem.runtime,
                numberOfSeasons: displayItem.numberOfSeasons,
                numberOfEpisodes: displayItem.numberOfEpisodes,
                genres: genreNames
            )
            modelContext.insert(watchlistItem)
            try? modelContext.save()
        }
    }
    
    private func toggleFavorite() {
        if let existingItem = watchlistItems.first(where: { $0.tmdbId == displayItem.id }) {
            // Item is in watchlist, just toggle favorite
            existingItem.isFavorite.toggle()
            try? modelContext.save()
        } else {
            // Item not in watchlist, add it and mark as favorite
            let genreNames: String
            if let genres = displayItem.genres {
                genreNames = genres.joined(separator: ", ")
            } else {
                genreNames = TMDBService.shared.getGenreNames(for: displayItem.genreIds ?? [], mediaType: displayItem.actualMediaType)
            }
            
            let watchlistItem = WatchlistItem(
                tmdbId: displayItem.id,
                title: displayItem.displayTitle,
                originalTitle: displayItem.originalTitle ?? displayItem.originalName ?? displayItem.displayTitle,
                overview: displayItem.safeOverview,
                mediaType: displayItem.actualMediaType,
                posterPath: displayItem.posterPath,
                backdropPath: displayItem.backdropPath,
                releaseDate: displayItem.releaseDate,
                firstAirDate: displayItem.firstAirDate,
                voteAverage: displayItem.safeVoteAverage,
                voteCount: displayItem.safeVoteCount,
                runtime: displayItem.runtime,
                numberOfSeasons: displayItem.numberOfSeasons,
                numberOfEpisodes: displayItem.numberOfEpisodes,
                genres: genreNames,
                isFavorite: true
            )
            modelContext.insert(watchlistItem)
            try? modelContext.save()
        }
    }
}

// MARK: - Watchlist View
struct WatchlistView: View {
    let items: [WatchlistItem]
    @Binding var searchText: String
    
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
                    Text("Search for movies and TV shows to add them")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                Spacer()
            } else {
                HStack {
                    Text("\(items.count) item\(items.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                List {
                    ForEach(items, id: \.id) { item in
                        WatchlistListItem(item: item)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}

// MARK: - Watchlist List Item
struct WatchlistListItem: View {
    let item: WatchlistItem
    @Environment(\.modelContext) private var modelContext
    @State private var showingDetail = false
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImageLoader(
                url: TMDBService.shared.getPosterURL(path: item.posterPath),
                placeholder: Image(systemName: item.mediaType == "movie" ? "film" : "tv")
            )
            .aspectRatio(2/3, contentMode: .fill)
            .frame(width: 60, height: 90)
            .clipped()
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            VStack(alignment: .leading, spacing: 6) {
                Text(item.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                
                HStack {
                    if !item.releaseYear.isEmpty {
                        Text(item.releaseYear)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text(String(format: "%.1f", item.voteAverage))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 10) {
                    if item.isWatched {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text("Watched")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                    }
                    
                    if item.isFavorite {
                        HStack(spacing: 3) {
                            Image(systemName: "heart.fill")
                                .font(.caption2)
                                .foregroundColor(.red)
                            Text("Favorite")
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                    }
                    
                    if item.personalRating > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", item.personalRating))
                                .font(.caption2)
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    Spacer()
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            WatchlistDetailView(item: item)
        }
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
    @State private var isWatched: Bool = false
    @State private var isFavorite: Bool = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    AsyncImageLoader(
                        url: TMDBService.shared.getBackdropURL(path: item.backdropPath),
                        placeholder: Image(systemName: item.mediaType == "movie" ? "film" : "tv")
                    )
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.displayTitle)
                            .font(.title)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.orange)
                            Text(String(format: "%.1f", item.voteAverage))
                                .fontWeight(.medium)
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("\(item.voteCount) votes")
                                .foregroundColor(.secondary)
                        }
                        .font(.subheadline)
                        
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
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Status")
                            .font(.headline)
                        
                        Toggle("Mark as Watched", isOn: $isWatched)
                            .onChange(of: isWatched) { _, newValue in
                                item.isWatched = newValue
                                if newValue {
                                    item.watchedDate = Date()
                                } else {
                                    item.watchedDate = Date.distantPast
                                    item.personalRating = 0.0
                                    personalRating = 0.0
                                }
                                try? modelContext.save()
                            }
                        
                        Toggle("Favorite", isOn: $isFavorite)
                            .onChange(of: isFavorite) { _, newValue in
                                item.isFavorite = newValue
                                try? modelContext.save()
                            }
                        
                        if isWatched && item.watchedDate != Date.distantPast {
                            HStack {
                                Image(systemName: "calendar")
                                Text("Watched on \(item.watchedDate, style: .date)")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
                        }
                    }
                    
                    if isWatched {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Your Rating")
                                .font(.headline)
                            
                            HStack {
                                Text("Rating:")
                                Spacer()
                                Text(personalRating > 0 ? String(format: "%.1f", personalRating) : "Not rated")
                                    .foregroundColor(personalRating > 0 ? .primary : .secondary)
                            }
                            
                            Slider(value: $personalRating, in: 0...10, step: 0.5)
                                .tint(.yellow)
                                .onChange(of: personalRating) { _, newValue in
                                    item.personalRating = newValue
                                    try? modelContext.save()
                                }
                            
                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: personalRating >= Double(star * 2) ? "star.fill" : "star")
                                        .font(.title3)
                                        .foregroundColor(.yellow)
                                        .onTapGesture {
                                            personalRating = Double(star * 2)
                                            item.personalRating = personalRating
                                            try? modelContext.save()
                                        }
                                }
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes & Review")
                            .font(.headline)
                        
                        TextEditor(text: $notes)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                            .onChange(of: notes) { _, newValue in
                                item.notes = newValue
                                try? modelContext.save()
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
                    Button("Remove", role: .destructive) {
                        showingDeleteAlert = true
                    }
                }
            }
            .alert("Remove from Watchlist", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Remove", role: .destructive) {
                    modelContext.delete(item)
                    try? modelContext.save()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to remove this item from your watchlist?")
            }
            .onAppear {
                personalRating = item.personalRating
                notes = item.notes
                isWatched = item.isWatched
                isFavorite = item.isFavorite
            }
        }
    }
}

// MARK: - Favorite Card
struct FavoriteCard: View {
    let item: WatchlistItem
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                AsyncImageLoader(
                    url: TMDBService.shared.getPosterURL(path: item.posterPath),
                    placeholder: Image(systemName: item.mediaType == "movie" ? "film" : "tv")
                )
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 120, height: 180)
                .clipped()
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                
                Image(systemName: "heart.fill")
                    .font(.title3)
                    .foregroundColor(.red)
                    .padding(8)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .frame(width: 120, alignment: .leading)
                
                if !item.releaseYear.isEmpty {
                    Text(item.releaseYear)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(String(format: "%.1f", item.voteAverage))
                        .font(.caption)
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
            .aspectRatio(2/3, contentMode: .fill)
            .frame(width: 100, height: 150)
            .clipped()
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayTitle)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .frame(width: 100, alignment: .leading)
                
                if !item.releaseYear.isEmpty {
                    Text(item.releaseYear)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 4) {
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
                    Text(searchText.isEmpty ? "No Favorites Yet" : "No Results")
                        .font(.headline)
                    Text(searchText.isEmpty ? "Mark items as favorites to see them here" : "Try a different search term")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                Spacer()
            } else {
                HStack {
                    Text("\(filteredItems.count) favorite\(filteredItems.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                List {
                    ForEach(filteredItems, id: \.id) { item in
                        FavoritesListItem(item: item)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }
}

// MARK: - Favorites List Item
struct FavoritesListItem: View {
    let item: WatchlistItem
    @State private var showingDetail = false
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImageLoader(
                url: TMDBService.shared.getPosterURL(path: item.posterPath),
                placeholder: Image(systemName: item.mediaType == "movie" ? "film" : "tv")
            )
            .aspectRatio(2/3, contentMode: .fill)
            .frame(width: 60, height: 90)
            .clipped()
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
            
            VStack(alignment: .leading, spacing: 6) {
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
                    
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                
                if !item.overview.isEmpty {
                    Text(item.overview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            WatchlistDetailView(item: item)
        }
    }
}

// MARK: - Popular Movies View
struct PopularMoviesView: View {
    let watchlistItems: [WatchlistItem]
    @StateObject private var tmdbService = TMDBService.shared
    @State private var popularMovies: [TMDBItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var watchlistIds: Set<Int> {
        Set(watchlistItems.map { $0.tmdbId })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading...")
                    .frame(height: 200)
            } else if errorMessage != nil {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Failed to load")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(popularMovies.prefix(10), id: \.id) { movie in
                            PopularMovieCard(
                                movie: movie,
                                isInWatchlist: watchlistIds.contains(movie.id),
                                watchlistItems: watchlistItems
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            loadPopularMovies()
        }
    }
    
    private func loadPopularMovies() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await tmdbService.getPopularMovies()
                await MainActor.run {
                    popularMovies = response.results
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load"
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Popular TV Shows View
struct PopularTVShowsView: View {
    let watchlistItems: [WatchlistItem]
    @StateObject private var tmdbService = TMDBService.shared
    @State private var popularTVShows: [TMDBItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    private var watchlistIds: Set<Int> {
        Set(watchlistItems.map { $0.tmdbId })
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading {
                ProgressView("Loading...")
                    .frame(height: 200)
            } else if errorMessage != nil {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    Text("Failed to load")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(height: 200)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(popularTVShows.prefix(10), id: \.id) { tvShow in
                            PopularTVShowCard(
                                tvShow: tvShow,
                                isInWatchlist: watchlistIds.contains(tvShow.id),
                                watchlistItems: watchlistItems
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .onAppear {
            loadPopularTVShows()
        }
    }
    
    private func loadPopularTVShows() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let response = try await tmdbService.getPopularTVShows()
                await MainActor.run {
                    popularTVShows = response.results
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to load"
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Popular Movie Card (Fixed sizing)
struct PopularMovieCard: View {
    let movie: TMDBItem
    let isInWatchlist: Bool
    let watchlistItems: [WatchlistItem]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var tmdbService = TMDBService.shared
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                AsyncImageLoader(
                    url: TMDBService.shared.getPosterURL(path: movie.posterPath),
                    placeholder: Image(systemName: "film")
                )
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 120, height: 180)
                .clipped()
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                
                // Watchlist button overlay
                Button {
                    toggleWatchlist()
                } label: {
                    Image(systemName: isInWatchlist ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.caption)
                        .foregroundColor(isInWatchlist ? .green : .blue)
                        .padding(6)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding(6)
            }
            
            Text(movie.displayTitle)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .frame(width: 120, alignment: .leading)
        }
        .frame(width: 120)
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            SearchDetailView(
                item: movie,
                isInWatchlist: isInWatchlist,
                watchlistItems: watchlistItems
            )
        }
    }
    
    private func toggleWatchlist() {
        if isInWatchlist {
            if let existingItem = watchlistItems.first(where: { $0.tmdbId == movie.id }) {
                modelContext.delete(existingItem)
                try? modelContext.save()
            }
        } else {
            let genreNames = tmdbService.getGenreNames(for: movie.genreIds ?? [], mediaType: movie.actualMediaType)
            
            let watchlistItem = WatchlistItem(
                tmdbId: movie.id,
                title: movie.displayTitle,
                originalTitle: movie.originalTitle ?? movie.originalName ?? movie.displayTitle,
                overview: movie.safeOverview,
                mediaType: movie.actualMediaType,
                posterPath: movie.posterPath,
                backdropPath: movie.backdropPath,
                releaseDate: movie.releaseDate,
                firstAirDate: movie.firstAirDate,
                voteAverage: movie.safeVoteAverage,
                voteCount: movie.safeVoteCount,
                runtime: movie.runtime,
                numberOfSeasons: movie.numberOfSeasons,
                numberOfEpisodes: movie.numberOfEpisodes,
                genres: genreNames
            )
            modelContext.insert(watchlistItem)
            try? modelContext.save()
        }
    }
}

// MARK: - Popular TV Show Card (Fixed sizing)
struct PopularTVShowCard: View {
    let tvShow: TMDBItem
    let isInWatchlist: Bool
    let watchlistItems: [WatchlistItem]
    @Environment(\.modelContext) private var modelContext
    @StateObject private var tmdbService = TMDBService.shared
    @State private var showingDetail = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                AsyncImageLoader(
                    url: TMDBService.shared.getPosterURL(path: tvShow.posterPath),
                    placeholder: Image(systemName: "tv")
                )
                .aspectRatio(2/3, contentMode: .fill)
                .frame(width: 120, height: 180)
                .clipped()
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                
                // Watchlist button overlay
                Button {
                    toggleWatchlist()
                } label: {
                    Image(systemName: isInWatchlist ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.caption)
                        .foregroundColor(isInWatchlist ? .green : .blue)
                        .padding(6)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding(6)
            }
            
            Text(tvShow.displayTitle)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .frame(width: 120, alignment: .leading)
        }
        .frame(width: 120)
        .onTapGesture {
            showingDetail = true
        }
        .sheet(isPresented: $showingDetail) {
            SearchDetailView(
                item: tvShow,
                isInWatchlist: isInWatchlist,
                watchlistItems: watchlistItems
            )
        }
    }
    
    private func toggleWatchlist() {
        if isInWatchlist {
            if let existingItem = watchlistItems.first(where: { $0.tmdbId == tvShow.id }) {
                modelContext.delete(existingItem)
                try? modelContext.save()
            }
        } else {
            let genreNames = tmdbService.getGenreNames(for: tvShow.genreIds ?? [], mediaType: tvShow.actualMediaType)
            
            let watchlistItem = WatchlistItem(
                tmdbId: tvShow.id,
                title: tvShow.displayTitle,
                originalTitle: tvShow.originalTitle ?? tvShow.originalName ?? tvShow.displayTitle,
                overview: tvShow.safeOverview,
                mediaType: tvShow.actualMediaType,
                posterPath: tvShow.posterPath,
                backdropPath: tvShow.backdropPath,
                releaseDate: tvShow.releaseDate,
                firstAirDate: tvShow.firstAirDate,
                voteAverage: tvShow.safeVoteAverage,
                voteCount: tvShow.safeVoteCount,
                runtime: tvShow.runtime,
                numberOfSeasons: tvShow.numberOfSeasons,
                numberOfEpisodes: tvShow.numberOfEpisodes,
                genres: genreNames
            )
            modelContext.insert(watchlistItem)
            try? modelContext.save()
        }
    }
}

// MARK: - Preview
struct WatchlistMainView_Previews: PreviewProvider {
    static var previews: some View {
        WatchlistMainView()
            .modelContainer(for: [WatchlistItem.self])
    }
}

