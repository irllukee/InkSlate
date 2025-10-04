import Foundation
import SwiftData
import UIKit

// MARK: - Place Category Model
@Model
class PlaceCategory {
    var name: String = "New Category"
    var type: String = "restaurants" // restaurants/activities/places
    var createdDate: Date = Date()
    @Relationship(deleteRule: .cascade)
    var places: [Place]?
    
    init(name: String, type: String, createdDate: Date = Date()) {
        self.name = name
        self.type = type
        self.createdDate = createdDate
        self.places = []
    }
}

// MARK: - Place Model
@Model
class Place {
    var name: String = ""
    var location: String = ""
    var address: String = ""
    var priceRange: String = "" // $-$$$$
    var cuisineType: String = "" // for restaurants
    var bestTimeToGo: String = ""
    var whoToBring: String = ""
    var entryFee: String = ""
    var notes: String = ""
    var dishRecommendations: String = ""
    var photoData: Data = Data()
    var dateVisited: Date = Date.distantPast
    var wouldReturn: Bool = true
    var hasVisited: Bool = false
    var priceRating: Int16 = 5
    var qualityRating: Int16 = 5
    var atmosphereRating: Int16 = 5
    var funFactorRating: Int16 = 5
    var sceneryRating: Int16 = 5
    var overallRating: Int16 = 5
    var pros: String = ""
    var cons: String = ""
    var createdDate: Date = Date()
    @Relationship(deleteRule: .nullify) var category: PlaceCategory?
    
    init(
        name: String,
        location: String? = nil,
        address: String? = nil,
        priceRange: String? = nil,
        cuisineType: String? = nil,
        bestTimeToGo: String? = nil,
        whoToBring: String? = nil,
        entryFee: String? = nil,
        notes: String? = nil,
        dishRecommendations: String? = nil,
        photoData: Data? = nil,
        dateVisited: Date? = nil,
        wouldReturn: Bool = true,
        hasVisited: Bool = false,
        priceRating: Int16 = 5,
        qualityRating: Int16 = 5,
        atmosphereRating: Int16 = 5,
        funFactorRating: Int16 = 5,
        sceneryRating: Int16 = 5,
        overallRating: Int16 = 5,
        pros: String? = nil,
        cons: String? = nil,
        createdDate: Date = Date(),
        category: PlaceCategory? = nil
    ) {
        self.name = name
        self.location = location ?? ""
        self.address = address ?? ""
        self.priceRange = priceRange ?? ""
        self.cuisineType = cuisineType ?? ""
        self.bestTimeToGo = bestTimeToGo ?? ""
        self.whoToBring = whoToBring ?? ""
        self.entryFee = entryFee ?? ""
        self.notes = notes ?? ""
        self.dishRecommendations = dishRecommendations ?? ""
        self.photoData = photoData ?? Data()
        self.dateVisited = dateVisited ?? Date.distantPast
        self.wouldReturn = wouldReturn
        self.hasVisited = hasVisited
        self.priceRating = priceRating
        self.qualityRating = qualityRating
        self.atmosphereRating = atmosphereRating
        self.funFactorRating = funFactorRating
        self.sceneryRating = sceneryRating
        self.overallRating = overallRating
        self.pros = pros ?? ""
        self.cons = cons ?? ""
        self.createdDate = createdDate
        self.category = category
    }
}
