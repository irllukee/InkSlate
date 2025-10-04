//
//  InkSlateApp.swift
//  InkSlate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI
import SwiftData
import Foundation

@main
struct InkSlateApp: App {
    
    init() {
        // Register the NSAttributedString value transformer
        ValueTransformer.setValueTransformer(
            NSAttributedStringTransformer(),
            forName: NSValueTransformerName("NSAttributedStringTransformer")
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(SharedStateManager.shared)
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
                    print("💾 Context saved successfully")
                }
            } catch {
                print("⚠️ Failed to save context: \(error.localizedDescription)")
            }
        }
    }
}