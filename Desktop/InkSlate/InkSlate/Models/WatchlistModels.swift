import Foundation
import SwiftData

// MARK: - Watchlist Item Model
@Model
class WatchlistItem {
    var tmdbId: Int = 0
    var title: String = ""
    var originalTitle: String = ""
    var overview: String = ""
    var mediaType: String = "" // "movie" or "tv"
    var posterPath: String = ""
    var backdropPath: String = ""
    var releaseDate: String = "" // For movies
    var firstAirDate: String = "" // For TV shows
    var voteAverage: Double = 0.0
    var voteCount: Int = 0
    var runtime: Int = 0 // For movies
    var numberOfSeasons: Int = 0 // For TV shows
    var numberOfEpisodes: Int = 0 // For TV shows
    var genres: String = "" // Comma-separated genre names
    var isWatched: Bool = false
    var isFavorite: Bool = false
    var personalRating: Double = 0.0 // 0-10 scale
    var notes: String = ""
    var addedDate: Date = Date()
    var watchedDate: Date = Date.distantPast
    
    init(
        tmdbId: Int,
        title: String,
        originalTitle: String,
        overview: String,
        mediaType: String,
        posterPath: String? = nil,
        backdropPath: String? = nil,
        releaseDate: String? = nil,
        firstAirDate: String? = nil,
        voteAverage: Double = 0.0,
        voteCount: Int = 0,
        runtime: Int? = nil,
        numberOfSeasons: Int? = nil,
        numberOfEpisodes: Int? = nil,
        genres: String = "",
        isWatched: Bool = false,
        isFavorite: Bool = false,
        personalRating: Double? = nil,
        notes: String? = nil,
        addedDate: Date = Date(),
        watchedDate: Date? = nil
    ) {
        self.tmdbId = tmdbId
        self.title = title
        self.originalTitle = originalTitle
        self.overview = overview
        self.mediaType = mediaType
        self.posterPath = posterPath ?? ""
        self.backdropPath = backdropPath ?? ""
        self.releaseDate = releaseDate ?? ""
        self.firstAirDate = firstAirDate ?? ""
        self.voteAverage = voteAverage
        self.voteCount = voteCount
        self.runtime = runtime ?? 0
        self.numberOfSeasons = numberOfSeasons ?? 0
        self.numberOfEpisodes = numberOfEpisodes ?? 0
        self.genres = genres
        self.isWatched = isWatched
        self.isFavorite = isFavorite
        self.personalRating = personalRating ?? 0.0
        self.notes = notes ?? ""
        self.addedDate = addedDate
        self.watchedDate = watchedDate ?? Date.distantPast
    }
    
    // Computed properties for display
    var displayTitle: String {
        return title.isEmpty ? originalTitle : title
    }
    
    var releaseYear: String {
        let date = releaseDate.isEmpty ? firstAirDate : releaseDate
        return date.isEmpty ? "" : String(date.prefix(4))
    }
    
    var runtimeText: String {
        if mediaType == "movie" && runtime > 0 {
            let hours = runtime / 60
            let minutes = runtime % 60
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        } else if mediaType == "tv" {
            var text = ""
            if numberOfSeasons > 0 {
                text += "\(numberOfSeasons) season\(numberOfSeasons == 1 ? "" : "s")"
            }
            if numberOfEpisodes > 0 {
                if !text.isEmpty {
                    text += " • "
                }
                text += "\(numberOfEpisodes) episode\(numberOfEpisodes == 1 ? "" : "s")"
            }
            return text
        }
        return ""
    }
    
    var genreList: [String] {
        return genres.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }
}

// MARK: - TMDB API Response Models
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

struct TMDBItem: Codable {
    let id: Int
    let title: String?
    let name: String? // For TV shows
    let originalTitle: String?
    let originalName: String? // For TV shows
    let overview: String
    let mediaType: String?
    let posterPath: String?
    let backdropPath: String?
    let releaseDate: String?
    let firstAirDate: String?
    let voteAverage: Double
    let voteCount: Int
    let runtime: Int?
    let numberOfSeasons: Int?
    let numberOfEpisodes: Int?
    let genreIds: [Int]?
    
    enum CodingKeys: String, CodingKey {
        case id, title, name, overview
        case originalTitle = "original_title"
        case originalName = "original_name"
        case mediaType = "media_type"
        case posterPath = "poster_path"
        case backdropPath = "backdrop_path"
        case releaseDate = "release_date"
        case firstAirDate = "first_air_date"
        case voteAverage = "vote_average"
        case voteCount = "vote_count"
        case runtime
        case numberOfSeasons = "number_of_seasons"
        case numberOfEpisodes = "number_of_episodes"
        case genreIds = "genre_ids"
    }
    
    var displayTitle: String {
        return title ?? name ?? originalTitle ?? originalName ?? "Unknown"
    }
    
    var actualMediaType: String {
        return mediaType ?? "movie"
    }
}

struct TMDBGenre: Codable {
    let id: Int
    let name: String
}

struct TMDBGenresResponse: Codable {
    let genres: [TMDBGenre]
}
