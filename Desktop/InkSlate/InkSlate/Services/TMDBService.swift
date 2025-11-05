//
//  TMDBService.swift
//  InkSlate
//
//  Created by Lucas Waldron on 1/2/25.
//

import Foundation
import SwiftUI

// MARK: - TMDb API Models
struct TMDBResponse: Codable {
    let results: [TMDBItem]
    let totalPages: Int
    let totalResults: Int
    
    enum CodingKeys: String, CodingKey {
        case results
        case totalPages = "total_pages"
        case totalResults = "total_results"
    }
}

struct TMDBItem: Codable, Identifiable {
    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let posterPath: String?
    let backdropPath: String?
    let voteAverage: Double?
    let voteCount: Int?
    let releaseDate: String?
    let firstAirDate: String?
    let mediaType: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case name
        case overview
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case mediaType = "media_type"
    }
    
    // Computed properties for easier access
    var displayTitle: String {
        return title ?? name ?? "Unknown"
    }
    
    var displayDate: String? {
        return releaseDate ?? firstAirDate
    }
    
    var isMovie: Bool {
        return mediaType == "movie" || (mediaType == nil && title != nil)
    }
    
    var isTVShow: Bool {
        return mediaType == "tv" || (mediaType == nil && name != nil)
    }
    
    var mediaTypeDisplay: String {
        if isMovie { return "Movie" }
        if isTVShow { return "TV Show" }
        return "Unknown"
    }
    
    var posterURL: URL? {
        guard let posterPath = posterPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w500\(posterPath)")
    }
    
    var backdropURL: URL? {
        guard let backdropPath = backdropPath else { return nil }
        return URL(string: "https://image.tmdb.org/t/p/w1280\(backdropPath)")
    }
    
    var rating: Double {
        return voteAverage ?? 0.0
    }
    
    var ratingCount: Int {
        return voteCount ?? 0
    }
}

// MARK: - TMDb Service
class TMDBService: ObservableObject {
    static let shared = TMDBService()
    
    // Note: TMDB API keys are public keys intended for client-side use
    // They are rate-limited per API key and safe to include in client apps
    // For production, consider moving to a configuration file if you need to rotate keys
    private let apiKey = "c2ed76e24aa7e68be5549011ee9d3947"
    private let baseURL = "https://api.themoviedb.org/3"
    private let imageBaseURL = "https://image.tmdb.org/t/p"
    
    // Date formatter for TMDb API dates
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
    
    // Display date formatter
    private let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale.current
        return formatter
    }()
    
    private init() {}
    
    // MARK: - Search Methods
    
    func searchMulti(query: String) async throws -> [TMDBItem] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "\(baseURL)/search/multi?api_key=\(apiKey)&query=\(encodedQuery)"
        
        guard let url = URL(string: urlString) else {
            throw TMDBError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TMDBError.invalidResponse
        }
        
        let tmdbResponse = try JSONDecoder().decode(TMDBResponse.self, from: data)
        
        // Return all results without filtering
        return tmdbResponse.results
    }
    
    // MARK: - Date Parsing
    
    func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString, !dateString.isEmpty else { return nil }
        return dateFormatter.date(from: dateString)
    }
    
    func formatDisplayDate(_ dateString: String?) -> String? {
        guard let date = parseDate(dateString) else { return nil }
        return displayDateFormatter.string(from: date)
    }
}

// MARK: - TMDb Errors
enum TMDBError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case noData
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .noData:
            return "No data received"
        case .decodingError:
            return "Failed to decode response"
        }
    }
}
