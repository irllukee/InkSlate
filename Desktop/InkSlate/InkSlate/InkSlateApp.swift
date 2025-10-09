//
//  InkSlateApp.swift
//  InkSlate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI
import SwiftData
import Foundation
import UIKit

@main
struct InkSlateApp: App {
    // Timer for periodic cleanup of soft-deleted items
    @State private var cleanupTimer: Timer?
    
    init() {
        // No longer need NSAttributedStringTransformer since we store Data directly
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(SharedStateManager.shared)
                .onAppear {
                    // Run cleanup on app launch
                    performCleanup()
                    
                    // Schedule cleanup to run every 24 hours
                    schedulePeriodicCleanup()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    saveContext()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    saveContext()
                }
        }
        // Provide the preconfigured CloudKit-backed container to the app
        .modelContainer(sharedModelContainer)
    }
    
    // MARK: - Helper Methods
    
    /// Saves the model context when app backgrounds or terminates
    private func saveContext() {
        Task { @MainActor in
            do {
                if sharedModelContainer.mainContext.hasChanges {
                    try sharedModelContainer.mainContext.save()
                }
            } catch {
                // Handle save error silently
            }
        }
    }
    
    /// Performs cleanup of soft-deleted items older than 30 days
    private func performCleanup() {
        Task { @MainActor in
            let context = sharedModelContainer.mainContext
            
            print("🧹 InkSlate: Starting automatic cleanup of soft-deleted items...")
            
            // Cleanup expired notes
            NotesManager.shared.cleanupExpiredNotes(with: context)
            
            // Cleanup expired budget items
            BudgetManager.shared.cleanupExpiredItems(with: context)
            
            print("✅ InkSlate: Cleanup completed at \(Date())")
        }
    }
    
    /// Schedules periodic cleanup to run every 24 hours
    private func schedulePeriodicCleanup() {
        // Run cleanup every 24 hours (86400 seconds)
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
            print("⏰ InkSlate: Running scheduled 24-hour cleanup...")
            Task { @MainActor in
                let context = sharedModelContainer.mainContext
                print("🧹 InkSlate: Starting scheduled cleanup of soft-deleted items...")
                NotesManager.shared.cleanupExpiredNotes(with: context)
                BudgetManager.shared.cleanupExpiredItems(with: context)
                print("✅ InkSlate: Scheduled cleanup completed at \(Date())")
            }
        }
        
        print("⏱️ InkSlate: Scheduled automatic cleanup to run every 24 hours")
    }
}