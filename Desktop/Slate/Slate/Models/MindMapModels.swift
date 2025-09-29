//
//  MindMapModels.swift
//  Slate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI
import SwiftData

// MARK: - Data Models
@Model
class MindMapNode {
    var id = UUID()
    var title: String
    var notes: String
    var children: [MindMapNode]
    var parent: MindMapNode?
    
    init(title: String, notes: String = "", parent: MindMapNode? = nil) {
        self.title = title
        self.notes = notes
        self.parent = parent
        self.children = []
    }
    
    func addChild(_ child: MindMapNode) {
        guard children.count < 10 else { return }
        child.parent = self
        children.append(child)
    }
    
    func removeChild(_ child: MindMapNode) {
        children.removeAll { $0.id == child.id }
    }
    
    func getDepth() -> Int {
        var depth = 0
        var current = self.parent
        while current != nil {
            depth += 1
            current = current?.parent
        }
        return depth
    }
}

@Model
class MindMap {
    var id = UUID()
    var name: String
    var rootNode: MindMapNode
    
    init(name: String) {
        self.name = name
        self.rootNode = MindMapNode(title: "Main Node")
    }
}

// MARK: - Store (No longer needed with SwiftData)
// The MindMapStore is now replaced by SwiftData's @Query and ModelContext
// Views will use @Query to fetch MindMaps and ModelContext to save changes
