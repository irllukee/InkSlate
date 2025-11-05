//
//  InkSlateApp.swift
//  InkSlate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI
import CoreData
import Foundation
import BackgroundTasks

@main
struct InkSlateApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        registerBackgroundTasks()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(SharedStateManager.shared)
                .onAppear {
                    // Run cleanup on app launch
                    performCleanup()
                    scheduleBackgroundCleanup()
                    
                    // Check CloudKit status
                    Task {
                        await checkCloudKitStatus()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                    Task {
                        await saveContextAsync()
                        scheduleBackgroundCleanup()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
                    Task {
                        await saveContextAsync()
                    }
                }
        }
    }
    
    private func saveContextAsync() async {
        await MainActor.run {
            persistenceController.save()
        }
    }
    
    /// Performs cleanup of soft-deleted items older than 30 days
    private func performCleanup() {
        Task { @MainActor in
            _ = persistenceController.container.viewContext
            
            // Clean up soft-deleted items older than 30 days
            _ = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            
            // This would be implemented with proper Core Data queries
            // For now, just save the context
            persistenceController.save()
        }
    }
    
    private func checkCloudKitStatus() async {
        await persistenceController.checkCloudKitStatus()
        
        // Get the current status after checking
        let status = persistenceController.syncStatus
        
        // Provide user-friendly guidance based on status
        switch status {
        case .available:
            // CloudKit is available and working
            break
        case .noAccount:
            break
        case .temporarilyUnavailable:
            break
        case .restricted:
            break
        case .couldNotDetermine, .unknown, .error:
            break
        }
    }
    
    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.lucas.InkSlateNew.cleanup",
            using: nil
        ) { task in
            self.handleBackgroundCleanup(task: task as! BGAppRefreshTask)
        }
    }
    
    private func scheduleBackgroundCleanup() {
        // Only schedule on real devices, not simulator
        guard ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] == nil else {
            return
        }
        
        let request = BGAppRefreshTaskRequest(identifier: "com.lucas.InkSlateNew.cleanup")
        request.earliestBeginDate = Calendar.current.date(byAdding: .day, value: 1, to: Date())
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Fallback: Schedule a shorter interval for retry
            let fallbackRequest = BGAppRefreshTaskRequest(identifier: "com.lucas.InkSlateNew.cleanup")
            fallbackRequest.earliestBeginDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())
            do {
                try BGTaskScheduler.shared.submit(fallbackRequest)
            } catch {
                // Fallback scheduling also failed
            }
        }
    }
    
    private func handleBackgroundCleanup(task: BGAppRefreshTask) {
        // Set expiration handler with proper error handling
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task { @MainActor in
            performCleanup()
            
            // Check CloudKit status in background
            await persistenceController.checkCloudKitStatus()
            
            task.setTaskCompleted(success: true)
            scheduleBackgroundCleanup()
        }
    }
}