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
        JournalBook.self, JournalEntry.self,
        // Mind Map
        MindMapNode.self,
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
        WatchlistItem.self
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
            return true
        } else {
            return false
        }
    }
    
    /// Creates and returns a CloudKit-backed ModelContainer
    func createModelContainer() -> ModelContainer {
        // Check iCloud availability first
        let iCloudAvailable = isICloudAvailable()
        
        if iCloudAvailable {
            // FIXED: Use .private() with explicit container identifier instead of .automatic
            let ckConfig = ModelConfiguration(
                schema: CloudKitConfig.schema,
                cloudKitDatabase: .private(CloudKitConfig.containerIdentifier)
            )
            
            // Build the container with the schema + configuration
            do {
                let container = try ModelContainer(for: CloudKitConfig.schema, configurations: [ckConfig])
                return container
            } catch {
                return createLocalContainer()
            }
        } else {
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
            // Last resort - this should rarely happen
            fatalError("❌ Could not create ModelContainer: \(error.localizedDescription)")
        }
    }
    
    /// Saves the model context when app backgrounds or terminates
    func saveContext(container: ModelContainer) {
        Task { @MainActor in
            do {
                if container.mainContext.hasChanges {
                    try container.mainContext.save()
                }
            } catch {
                // Handle save error silently
            }
        }
    }
    
    /// Manually trigger a sync (optional - for debugging)
    func forceSyncIfNeeded(container: ModelContainer) {
        Task { @MainActor in
            do {
                try container.mainContext.save()
            } catch {
                // Handle sync error silently
            }
        }
    }
}

// MARK: - NSAttributedString Value Transformer for CloudKit
class NSAttributedStringTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass { NSData.self }
    override class func allowsReverseTransformation() -> Bool { true }

    override func transformedValue(_ value: Any?) -> Any? {
        guard let attributedString = value as? NSAttributedString else { return nil }
        do {
            let data = try attributedString.data(
                from: NSRange(location: 0, length: attributedString.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
            
            // CloudKit limit check (1 MB = 1,048,576 bytes)
            if data.count > 1_000_000 {
                // Fallback to plain text
                return attributedString.string.data(using: .utf8)
            }
            
            return data
        } catch {
            return nil
        }
    }

    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        do {
            return try NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
        } catch {
            return NSAttributedString(string: "")
        }
    }
}

// MARK: - Shared CloudKit-backed ModelContainer
@MainActor
let sharedModelContainer: ModelContainer = CloudKitService.shared.createModelContainer()


