//
//  ProfileService.swift
//  InkSlate
//
//  Created by AI Assistant on 12/19/24.
//

import SwiftUI
import Foundation

// MARK: - Profile Service
class ProfileService: ObservableObject {
    @Published var userName: String = "Alex"
    @Published var userIcon: String = "person.circle.fill"
    @Published var userEmail: String = "alex@inkslate.app"
    @Published var userImage: UIImage?
    
    private let userDefaults = UserDefaults.standard
    private let userNameKey = "profileUserName"
    private let userIconKey = "profileUserIcon"
    private let userEmailKey = "profileUserEmail"
    private let userImageKey = "profileUserImage"
    
    // Available icons for customization
    let availableIcons = [
        "person.circle.fill",
        "person.crop.circle.fill",
        "person.2.circle.fill",
        "person.3.circle.fill",
        "star.circle.fill",
        "heart.circle.fill",
        "flame.circle.fill",
        "leaf.circle.fill",
        "moon.circle.fill",
        "sun.max.circle.fill",
        "cloud.circle.fill",
        "bolt.circle.fill",
        "sparkles.circle.fill",
        "crown.circle.fill",
        "diamond.circle.fill"
    ]
    
    init() {
        loadProfile()
    }
    
    func loadProfile() {
        userName = userDefaults.string(forKey: userNameKey) ?? "User"
        userIcon = userDefaults.string(forKey: userIconKey) ?? "person.circle.fill"
        userEmail = userDefaults.string(forKey: userEmailKey) ?? "user@inkslate.app"
        
        // Load saved image if it exists
        if let imageData = userDefaults.data(forKey: userImageKey),
           let image = UIImage(data: imageData) {
            userImage = image
        }
    }
    
    func updateProfile(name: String, icon: String, email: String) {
        userName = name
        userIcon = icon
        userEmail = email
        
        userDefaults.set(name, forKey: userNameKey)
        userDefaults.set(icon, forKey: userIconKey)
        userDefaults.set(email, forKey: userEmailKey)
    }
    
    func updateProfileImage(_ image: UIImage) {
        userImage = image
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            userDefaults.set(imageData, forKey: userImageKey)
        }
    }
    
    func resetToDefaults() {
        updateProfile(
            name: "User",
            icon: "person.circle.fill",
            email: "user@inkslate.app"
        )
    }
}
