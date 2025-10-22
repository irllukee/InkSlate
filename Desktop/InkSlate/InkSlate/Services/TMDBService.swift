import Foundation
import UIKit
import SwiftUI

// MARK: - TMDB Service
class TMDBService: ObservableObject {
    static let shared = TMDBService()
    
    private let apiKey = "c2ed76e24aa7e68be5549011ee9d3947"
    private let baseURL = "https://api.themoviedb.org/3"
    private let imageBaseURL = "https://image.tmdb.org/t/p"
    
    // ✅ OPTIMIZED: Add response caching to reduce API calls
    private struct CachedResponse {
        let data: TMDBResponse
        let timestamp: Date
    }
    
    private var popularMoviesCache: CachedResponse?
    private var popularTVCache: CachedResponse?
    private var topRatedMoviesCache: CachedResponse?
    private var topRatedTVCache: CachedResponse?
    private let cacheValidityDuration: TimeInterval = 3600 // 1 hour
    
    private init() {}
    
    // Clear cache (can be called on app launch or settings)
    func clearCache() {
        popularMoviesCache = nil
        popularTVCache = nil
        topRatedMoviesCache = nil
        topRatedTVCache = nil
    }
    
    // MARK: - Search Methods
    func searchMovies(query: String, page: Int = 1) async throws -> TMDBResponse {
        let url = URL(string: "\(baseURL)/search/movie")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "include_adult", value: "false")
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(TMDBResponse.self, from: data)
    }
    
    func searchTVShows(query: String, page: Int = 1) async throws -> TMDBResponse {
        let url = URL(string: "\(baseURL)/search/tv")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "include_adult", value: "false")
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(TMDBResponse.self, from: data)
    }
    
    func multiSearch(query: String, page: Int = 1) async throws -> TMDBResponse {
        let url = URL(string: "\(baseURL)/search/multi")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "include_adult", value: "false")
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(TMDBResponse.self, from: data)
    }
    
    // MARK: - Popular Content Methods (with caching)
    func getPopularMovies(page: Int = 1) async throws -> TMDBResponse {
        // ✅ OPTIMIZED: Check cache first (only for page 1)
        if page == 1,
           let cache = popularMoviesCache,
           Date().timeIntervalSince(cache.timestamp) < cacheValidityDuration {
            print("📦 TMDBService: Using cached popular movies")
            return cache.data
        }
        
        print("🌐 TMDBService: Fetching popular movies from API")
        let url = URL(string: "\(baseURL)/movie/popular")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "page", value: String(page))
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(TMDBResponse.self, from: data)
        
        // ✅ Cache the response (only page 1)
        if page == 1 {
            popularMoviesCache = CachedResponse(data: response, timestamp: Date())
        }
        
        return response
    }
    
    func getPopularTVShows(page: Int = 1) async throws -> TMDBResponse {
        // ✅ OPTIMIZED: Check cache first (only for page 1)
        if page == 1,
           let cache = popularTVCache,
           Date().timeIntervalSince(cache.timestamp) < cacheValidityDuration {
            print("📦 TMDBService: Using cached popular TV shows")
            return cache.data
        }
        
        print("🌐 TMDBService: Fetching popular TV shows from API")
        let url = URL(string: "\(baseURL)/tv/popular")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "page", value: String(page))
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(TMDBResponse.self, from: data)
        
        // ✅ Cache the response (only page 1)
        if page == 1 {
            popularTVCache = CachedResponse(data: response, timestamp: Date())
        }
        
        return response
    }
    
    func getTopRatedMovies(page: Int = 1) async throws -> TMDBResponse {
        // ✅ OPTIMIZED: Check cache first (only for page 1)
        if page == 1,
           let cache = topRatedMoviesCache,
           Date().timeIntervalSince(cache.timestamp) < cacheValidityDuration {
            print("📦 TMDBService: Using cached top rated movies")
            return cache.data
        }
        
        print("🌐 TMDBService: Fetching top rated movies from API")
        let url = URL(string: "\(baseURL)/movie/top_rated")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "page", value: String(page))
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(TMDBResponse.self, from: data)
        
        // ✅ Cache the response (only page 1)
        if page == 1 {
            topRatedMoviesCache = CachedResponse(data: response, timestamp: Date())
        }
        
        return response
    }
    
    func getTopRatedTVShows(page: Int = 1) async throws -> TMDBResponse {
        // ✅ OPTIMIZED: Check cache first (only for page 1)
        if page == 1,
           let cache = topRatedTVCache,
           Date().timeIntervalSince(cache.timestamp) < cacheValidityDuration {
            print("📦 TMDBService: Using cached top rated TV shows")
            return cache.data
        }
        
        print("🌐 TMDBService: Fetching top rated TV shows from API")
        let url = URL(string: "\(baseURL)/tv/top_rated")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "page", value: String(page))
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(TMDBResponse.self, from: data)
        
        // ✅ Cache the response (only page 1)
        if page == 1 {
            topRatedTVCache = CachedResponse(data: response, timestamp: Date())
        }
        
        return response
    }
    
    
    // MARK: - Genre Lists
    func getMovieGenres() async throws -> TMDBGenresResponse {
        let url = URL(string: "\(baseURL)/genre/movie/list")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(TMDBGenresResponse.self, from: data)
    }
    
    func getTVGenres() async throws -> TMDBGenresResponse {
        let url = URL(string: "\(baseURL)/genre/tv/list")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(TMDBGenresResponse.self, from: data)
    }
    
    // MARK: - Image URLs
    func getPosterURL(path: String?, size: String = "w500") -> URL? {
        guard let path = path else { return nil }
        return URL(string: "\(imageBaseURL)/\(size)\(path)")
    }
    
    func getBackdropURL(path: String?, size: String = "w1280") -> URL? {
        guard let path = path else { return nil }
        return URL(string: "\(imageBaseURL)/\(size)\(path)")
    }
    
    // MARK: - Details & Credits
    func getDetails(id: Int, mediaType: String) async throws -> TMDBItem {
        let endpoint = mediaType == "movie" ? "movie" : "tv"
        let url = URL(string: "\(baseURL)/\(endpoint)/\(id)")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        
        // Decode the detailed response
        let detailedItem = try JSONDecoder().decode(DetailedTMDBItem.self, from: data)
        
        // Convert to TMDBItem with genre names
        return TMDBItem(
            id: detailedItem.id,
            title: detailedItem.title,
            name: detailedItem.name,
            originalTitle: detailedItem.originalTitle,
            originalName: detailedItem.originalName,
            overview: detailedItem.overview ?? "",
            mediaType: mediaType,
            posterPath: detailedItem.posterPath,
            backdropPath: detailedItem.backdropPath,
            releaseDate: detailedItem.releaseDate,
            firstAirDate: detailedItem.firstAirDate,
            voteAverage: detailedItem.voteAverage ?? 0.0,
            voteCount: detailedItem.voteCount ?? 0,
            runtime: detailedItem.runtime,
            numberOfSeasons: detailedItem.numberOfSeasons,
            numberOfEpisodes: detailedItem.numberOfEpisodes,
            genreIds: nil,
            genres: detailedItem.genres?.map { $0.name }
        )
    }
    
    func getCredits(id: Int, mediaType: String) async throws -> CreditsResponse {
        let endpoint = mediaType == "movie" ? "movie" : "tv"
        let url = URL(string: "\(baseURL)/\(endpoint)/\(id)/credits")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(CreditsResponse.self, from: data)
    }
    
    // MARK: - Genre Mapping
    private var movieGenres: [Int: String] = [:]
    private var tvGenres: [Int: String] = [:]
    
    func getGenreNames(for genreIds: [Int], mediaType: String) -> String {
        let genreMap = mediaType == "movie" ? movieGenres : tvGenres
        let names = genreIds.compactMap { genreMap[$0] }
        return names.joined(separator: ", ")
    }
    
    func loadGenres() async {
        do {
            let movieGenresResponse = try await getMovieGenres()
            movieGenres = Dictionary(uniqueKeysWithValues: movieGenresResponse.genres.map { ($0.id, $0.name) })
            
            let tvGenresResponse = try await getTVGenres()
            tvGenres = Dictionary(uniqueKeysWithValues: tvGenresResponse.genres.map { ($0.id, $0.name) })
        } catch {
            // Handle genre loading error silently
        }
    }
}

// MARK: - Detailed Response Model
private struct DetailedTMDBItem: Codable {
    let id: Int
    let title: String?
    let name: String?
    let originalTitle: String?
    let originalName: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double?
    let voteCount: Int?
    let runtime: Int?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let genres: [TMDBGenre]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, name, overview, genres, runtime
        case originalTitle = "original_title"
        case originalName = "original_name"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
    }
}

// ✅ OPTIMIZED: ImageLoader moved to WatchlistViews.swift with NSCache implementation



