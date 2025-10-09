//
//  MindMapModels.swift
//  InkSlate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI
import SwiftData

// MARK: - Data Models
@Model
class MindMapNode {
    var title: String = "New Node"
    var notes: String = ""
    @Relationship(deleteRule: .cascade) var children: [MindMapNode]? = []
    @Relationship(inverse: \MindMapNode.children) var parent: MindMapNode?
    @Relationship(deleteRule: .nullify) var mindMap: MindMap?
    
    init(title: String = "New Node", notes: String = "", parent: MindMapNode? = nil) {
        self.title = title
        self.notes = notes
        self.parent = parent
        self.children = []
    }
    
    func addChild(_ child: MindMapNode) {
        guard (children?.count ?? 0) < 10 else { return }
        child.parent = self
        children?.append(child)
    }
    
    func removeChild(_ child: MindMapNode) {
        children?.removeAll { $0 === child }
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
    var name: String = "New Mind Map"
    @Relationship(deleteRule: .cascade, inverse: \MindMapNode.mindMap) var rootNode: MindMapNode?
    
    init(name: String = "New Mind Map") {
        self.name = name.isEmpty ? "New Mind Map" : name
        let root = MindMapNode(title: "Main Node")
        self.rootNode = root
        root.mindMap = self
    }
    
    // Safe accessor for name to handle potential nil values
    var safeName: String {
        return name.isEmpty ? "Untitled Mind Map" : name
    }
}
