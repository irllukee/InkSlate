//
//  SlateApp.swift
//  Slate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI
import SwiftData
import Foundation

// MARK: - NSAttributedString Value Transformer
class NSAttributedStringTransformer: ValueTransformer {
    override class func transformedValueClass() -> AnyClass {
        return NSData.self
    }
    
    override class func allowsReverseTransformation() -> Bool {
        return true
    }
    
    override func transformedValue(_ value: Any?) -> Any? {
        guard let attributedString = value as? NSAttributedString else { return nil }
        
        do {
            let data = try attributedString.data(from: NSRange(location: 0, length: attributedString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
            return data
        } catch {
            print("Failed to convert NSAttributedString to Data: \(error)")
            return nil
        }
    }
    
    override func reverseTransformedValue(_ value: Any?) -> Any? {
        guard let data = value as? Data else { return nil }
        
        do {
            let attributedString = try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
            return attributedString
        } catch {
            print("Failed to convert Data to NSAttributedString: \(error)")
            return NSAttributedString(string: "")
        }
    }
}

@main
struct SlateApp: App {
    var sharedModelContainer: ModelContainer = {
        // Register the NSAttributedString transformer
        ValueTransformer.setValueTransformer(NSAttributedStringTransformer(), forName: NSValueTransformerName("NSAttributedStringTransformer"))
        
        let schema = Schema([
            Item.self,
            MindMap.self,
            MindMapNode.self,
            Note.self,
            Folder.self,
            JournalBook.self,
            JournalEntry.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
