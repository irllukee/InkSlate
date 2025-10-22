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
import BackgroundTasks

@main
struct InkSlateApp: App {
    // ✅ OPTIMIZED: Removed Timer, using BGAppRefreshTask instead for better battery life
    
    init() {
        // No longer need NSAttributedStringTransformer since we store Data directly
        
        // ✅ OPTIMIZED: Register background task for cleanup
        registerBackgroundTasks()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(SharedStateManager.shared)
                .onAppear {
                    // Run cleanup on app launch
                    performCleanup()
                    
                    // ✅ OPTIMIZED: Schedule background task instead of timer
                    scheduleBackgroundCleanup()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    saveContext()
                    // Schedule cleanup when app backgrounds
                    scheduleBackgroundCleanup()
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
            
            // Cleanup expired budget items
            BudgetManager.shared.cleanupExpiredItems(with: context)
            
            print("✅ InkSlate: Cleanup completed at \(Date())")
        }
    }
    
    // ✅ OPTIMIZED: Use BGAppRefreshTask instead of Timer for better battery life
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.lucas.InkSlateNew.cleanup",
            using: nil
        ) { task in
            self.handleBackgroundCleanup(task: task as! BGAppRefreshTask)
        }
        
        print("✅ InkSlate: Registered background cleanup task")
    }
    
    private func scheduleBackgroundCleanup() {
        let request = BGAppRefreshTaskRequest(identifier: "com.lucas.InkSlateNew.cleanup")
        // Schedule for next day
        request.earliestBeginDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ InkSlate: Scheduled background cleanup for tomorrow")
        } catch {
            print("⚠️ InkSlate: Could not schedule background cleanup: \(error.localizedDescription)")
        }
    }
    
    private func handleBackgroundCleanup(task: BGAppRefreshTask) {
        // Set expiration handler
        task.expirationHandler = {
            print("⏱️ InkSlate: Background cleanup task expired")
        }
        
        Task { @MainActor in
            print("🧹 InkSlate: Running background cleanup...")
            let context = sharedModelContainer.mainContext
            
            BudgetManager.shared.cleanupExpiredItems(with: context)
            
            print("✅ InkSlate: Background cleanup completed")
            
            // Mark task as complete
            task.setTaskCompleted(success: true)
            
            // Schedule next cleanup
            scheduleBackgroundCleanup()
        }
    }
}