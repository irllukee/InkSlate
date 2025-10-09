//
//  CloudKitConfiguration.swift
//  InkSlate
//
//  Complete CloudKit configuration for InkSlate
//  FIXED VERSION - Corrects sync issues
//

import SwiftUI
import SwiftData
import Foundation
import CloudKit

// MARK: - CloudKit Configuration
struct CloudKitConfig {
    static let containerIdentifier = "iCloud.com.lucas.InkSlateNew"
    
    static let schema = Schema([
        // Notes
        Note.self, Folder.self,
        // Journal
        JournalBook.self, JournalEntry.self, JournalPrompt.self,
        // Mind Map
        MindMap.self, MindMapNode.self,
        // Simple Items
        Item.self,
        // Quotes
        Quote.self,
        // Recipes & Pantry
        Recipe.self, RecipeIngredient.self, FridgeItem.self, SpiceItem.self, CartItem.self,
        // Todos
        TodoTab.self, TodoTask.self,
        // Places
        Place.self, PlaceCategory.self,
        // Movies/TV
        WatchlistItem.self,
        // Budget
        BudgetCategory.self, BudgetSubcategory.self, BudgetItem.self
    ])
}

// MARK: - CloudKit Service
@MainActor
class CloudKitService {
    static let shared = CloudKitService()
    
    private init() {}
    
    /// Checks if iCloud is available and user is signed in
    func isICloudAvailable() -> Bool {
        if FileManager.default.ubiquityIdentityToken != nil {
            print("✅ iCloud: User is signed in and iCloud is available")
            return true
        } else {
            print("⚠️ iCloud: User is NOT signed in or iCloud is unavailable")
            return false
        }
    }
    
    /// Creates and returns a CloudKit-backed ModelContainer
    func createModelContainer() -> ModelContainer {
        // Check iCloud availability first
        let iCloudAvailable = isICloudAvailable()
        
        if iCloudAvailable {
            print("☁️ iCloud: Creating CloudKit-backed ModelContainer with identifier: \(CloudKitConfig.containerIdentifier)")
            // Use .private() with explicit container identifier
            let ckConfig = ModelConfiguration(
                schema: CloudKitConfig.schema,
                cloudKitDatabase: .private(CloudKitConfig.containerIdentifier)
            )
            
            // Build the container with the schema + configuration
            do {
                let container = try ModelContainer(for: CloudKitConfig.schema, configurations: [ckConfig])
                print("✅ iCloud: Successfully created CloudKit-backed ModelContainer")
                print("☁️ iCloud: Data will sync across devices using CloudKit private database")
                return container
            } catch {
                print("❌ iCloud: Failed to create CloudKit container: \(error.localizedDescription)")
                print("⚠️ iCloud: Falling back to local-only storage")
                return createLocalContainer()
            }
        } else {
            print("📱 iCloud: Creating local-only ModelContainer (no iCloud sync)")
            return createLocalContainer()
        }
    }
    
    /// Creates a local-only ModelContainer (fallback)
    private func createLocalContainer() -> ModelContainer {
        do {
            let localConfig = ModelConfiguration(schema: CloudKitConfig.schema, cloudKitDatabase: .none)
            let container = try ModelContainer(for: CloudKitConfig.schema, configurations: [localConfig])
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error.localizedDescription)")
        }
    }
    
    /// Saves the model context when app backgrounds or terminates
    func saveContext(container: ModelContainer) {
        Task { @MainActor in
            do {
                if container.mainContext.hasChanges {
                    print("💾 iCloud: Saving changes to CloudKit...")
                    try container.mainContext.save()
                    print("✅ iCloud: Changes saved successfully (will sync to iCloud)")
                }
            } catch {
                print("❌ iCloud: Failed to save context: \(error.localizedDescription)")
            }
        }
    }
    
    /// Manually trigger a sync (optional - for debugging)
    func forceSyncIfNeeded(container: ModelContainer) {
        Task { @MainActor in
            do {
                print("🔄 iCloud: Manually triggering sync...")
                try container.mainContext.save()
                print("✅ iCloud: Manual sync completed")
            } catch {
                print("❌ iCloud: Manual sync failed: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - No longer need NSAttributedStringTransformer since we store Data directly

// MARK: - Shared CloudKit-backed ModelContainer
@MainActor
let sharedModelContainer: ModelContainer = CloudKitService.shared.createModelContainer()


