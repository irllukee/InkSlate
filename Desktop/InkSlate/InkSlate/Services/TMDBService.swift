import Foundation
import UIKit
import SwiftUI

// MARK: - TMDB Service
class TMDBService: ObservableObject {
    static let shared = TMDBService()
    
    private let apiKey = "c2ed76e24aa7e68be5549011ee9d3947"
    private let baseURL = "https://api.themoviedb.org/3"
    private let imageBaseURL = "https://image.tmdb.org/t/p"
    
    private init() {}
    
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
    
    // MARK: - Popular Content Methods
    func getPopularMovies(page: Int = 1) async throws -> TMDBResponse {
        let url = URL(string: "\(baseURL)/movie/popular")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "page", value: String(page))
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(TMDBResponse.self, from: data)
    }
    
    func getPopularTVShows(page: Int = 1) async throws -> TMDBResponse {
        let url = URL(string: "\(baseURL)/tv/popular")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "page", value: String(page))
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(TMDBResponse.self, from: data)
    }
    
    func getTopRatedMovies(page: Int = 1) async throws -> TMDBResponse {
        let url = URL(string: "\(baseURL)/movie/top_rated")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "page", value: String(page))
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(TMDBResponse.self, from: data)
    }
    
    func getTopRatedTVShows(page: Int = 1) async throws -> TMDBResponse {
        let url = URL(string: "\(baseURL)/tv/top_rated")!
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "page", value: String(page))
        ]
        
        let (data, _) = try await URLSession.shared.data(from: components.url!)
        return try JSONDecoder().decode(TMDBResponse.self, from: data)
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

// MARK: - Image Loading Helper
class ImageLoader: ObservableObject {
    @Published var image: UIImage?
    @Published var isLoading = false
    
    private let url: URL?
    private var dataTask: URLSessionDataTask?
    
    init(url: URL?) {
        self.url = url
    }
    
    func load() {
        guard let url = url else { return }
        
        // Cancel any existing task
        dataTask?.cancel()
        
        isLoading = true
        
        dataTask = URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.isLoading = false
                
                if let data = data, let image = UIImage(data: data) {
                    self.image = image
                }
            }
        }
        dataTask?.resume()
    }
    
    func cancel() {
        dataTask?.cancel()
        dataTask = nil
        isLoading = false
    }
    
    deinit {
        dataTask?.cancel()
        dataTask = nil
    }
}



