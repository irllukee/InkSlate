//
//  SharedStateManager.swift
//  InkSlate
//
//  Created by Performance Optimization on 9/30/25.
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Shared State Manager
class SharedStateManager: ObservableObject {
    static let shared = SharedStateManager()
    
    // Shared managers
    @Published var loadingManager = LoadingStateManager()
    @Published var autoSaveManager = AutoSaveManager()
    
    // Splash screen state
    @Published var showSplashScreen = true
    
    
    private init() {
        // No authentication or onboarding needed - app starts directly
    }
    
    func hideSplashScreen() {
        showSplashScreen = false
    }
    
    func resetToDefaults() {
        // Reset splash screen
        showSplashScreen = true
        
        // Reset loading state
        loadingManager.stopLoading()
        
        // Reset auto save state
        autoSaveManager.lastSaveStatus = "Ready"
        autoSaveManager.isSaving = false
    }
    
}

// MARK: - Environment Key for Shared State
private struct SharedStateManagerKey: EnvironmentKey {
    static let defaultValue = SharedStateManager.shared
}

extension EnvironmentValues {
    var sharedStateManager: SharedStateManager {
        get { self[SharedStateManagerKey.self] }
        set { self[SharedStateManagerKey.self] = newValue }
    }
}

