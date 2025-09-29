//
//  MindMapViews.swift
//  Slate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI
import SwiftData

// MARK: - Mind Map Views
struct MindMapListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var mindMaps: [MindMap]
    @State private var showingAlert = false
    @State private var editingMindMap: MindMap?
    @State private var newMindMapName = ""
    
    var body: some View {
        List {
            ForEach(mindMaps) { mindMap in
                NavigationLink(destination: MindMapDetailView(mindMap: mindMap)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(mindMap.name)
                            .font(.headline)
                        Text("\(mindMap.rootNode.children.count) topics")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button("Delete") {
                        modelContext.delete(mindMap)
                    }
                    .tint(.red)
                    
                    Button("Rename") {
                        editingMindMap = mindMap
                        newMindMapName = mindMap.name
                        showingAlert = true
                    }
                    .tint(.blue)
                }
            }
        }
        .navigationTitle("Mind Maps")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: createNewMindMap) {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("Rename Mind Map", isPresented: $showingAlert) {
            TextField("Name", text: $newMindMapName)
            Button("Cancel") { }
            Button("Save") {
                if let mindMap = editingMindMap {
                    mindMap.name = newMindMapName
                    try? modelContext.save()
                }
            }
        }
    }
    
    private func createNewMindMap() {
        let newMindMap = MindMap(name: "Untitled Mind Map")
        modelContext.insert(newMindMap)
        try? modelContext.save()
    }
}

struct MindMapDetailView: View {
    var mindMap: MindMap
    @Environment(\.modelContext) private var modelContext
    @State private var currentNode: MindMapNode
    @State private var navigationStack: [MindMapNode] = []
    @State private var selectedNodeForAction: MindMapNode?
    @State private var showingEditSheet = false
    @State private var showingViewSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var nodeToDelete: MindMapNode?
    @Environment(\.presentationMode) var presentationMode
    
    init(mindMap: MindMap) {
        self.mindMap = mindMap
        self._currentNode = State(initialValue: mindMap.rootNode)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                    .onTapGesture {
                        selectedNodeForAction = nil
                    }
                
                // Center Node
                NodeBubbleView(
                    node: currentNode,
                    isCenter: true,
                    onTap: {},
                    onLongPress: {
                        selectedNodeForAction = currentNode
                    }
                )
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                
                // Child Nodes
                ForEach(Array(currentNode.children.enumerated()), id: \.element.id) { index, child in
                    let angle = Double(index) * (2 * .pi / Double(currentNode.children.count))
                    let radius: CGFloat = 120
                    let x = geometry.size.width / 2 + cos(angle) * radius
                    let y = geometry.size.height / 2 + sin(angle) * radius
                    
                    NodeBubbleView(
                        node: child,
                        isCenter: false,
                        onTap: {
                            navigateToNode(child)
                        },
                        onLongPress: {
                            selectedNodeForAction = child
                        }
                    )
                    .position(x: x, y: y)
                }
                
                // Action Bubbles
                if let selectedNode = selectedNodeForAction {
                    let nodePosition = getNodePosition(for: selectedNode, in: geometry)
                    
                    HStack(spacing: 15) {
                        ActionBubbleView(title: "View", color: .green) {
                            showingViewSheet = true
                        }
                        
                        ActionBubbleView(title: "Edit", color: .blue) {
                            // Ensure the selected node is set before showing the sheet
                            DispatchQueue.main.async {
                                showingEditSheet = true
                            }
                        }
                        
                        if selectedNode.id != currentNode.id {
                            ActionBubbleView(title: "Delete", color: .red) {
                                if selectedNode.children.isEmpty {
                                    deleteNode(selectedNode)
                                    selectedNodeForAction = nil
                                } else {
                                    nodeToDelete = selectedNode
                                    showingDeleteConfirmation = true
                                }
                            }
                        }
                    }
                    .position(x: nodePosition.x, y: nodePosition.y - 80)
                }
                
                // Add Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: addNewNode) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(Color.black)
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(navigationStack.isEmpty ? false : true)
        .toolbar {
            if !navigationStack.isEmpty {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: navigateBack) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            if let selectedNode = selectedNodeForAction {
                EditNodeView(node: selectedNode) {
                    selectedNodeForAction = nil
                }
            } else {
                Text("No node selected")
                    .padding()
            }
        }
        .sheet(isPresented: $showingViewSheet) {
            if let selectedNode = selectedNodeForAction {
                ViewNodeView(node: selectedNode)
            } else {
                Text("No node selected")
                    .padding()
            }
        }
        .alert("Delete Node", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                selectedNodeForAction = nil
            }
            Button("Delete", role: .destructive) {
                if let node = nodeToDelete {
                    deleteNode(node)
                }
                selectedNodeForAction = nil
            }
        } message: {
            if let node = nodeToDelete {
                Text("This node has \(node.children.count) child node(s). Are you sure you want to delete it and all its children?")
            }
        }
    }
    
    private func getNodePosition(for node: MindMapNode, in geometry: GeometryProxy) -> CGPoint {
        if node.id == currentNode.id {
            return CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        
        if let index = currentNode.children.firstIndex(where: { $0.id == node.id }) {
            let angle = Double(index) * (2 * .pi / Double(currentNode.children.count))
            let radius: CGFloat = 120
            let x = geometry.size.width / 2 + cos(angle) * radius
            let y = geometry.size.height / 2 + sin(angle) * radius
            return CGPoint(x: x, y: y)
        }
        
        return CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
    }
    
    private func navigateToNode(_ node: MindMapNode) {
        guard node.getDepth() < 10 else { return }
        navigationStack.append(currentNode)
        currentNode = node
        selectedNodeForAction = nil
    }
    
    private func navigateBack() {
        guard let previousNode = navigationStack.popLast() else { return }
        currentNode = previousNode
        selectedNodeForAction = nil
    }
    
    private func addNewNode() {
        guard currentNode.children.count < 10 else { return }
        let newNode = MindMapNode(title: "New Topic", parent: currentNode)
        currentNode.addChild(newNode)
        try? modelContext.save()
    }
    
    private func deleteNode(_ node: MindMapNode) {
        currentNode.removeChild(node)
        try? modelContext.save()
    }
}

struct NodeBubbleView: View {
    var node: MindMapNode
    let isCenter: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    var body: some View {
        Text(node.title)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: 60, height: 60)
            .background(Color.black)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.gray, lineWidth: isCenter ? 2 : 1)
            )
            .onTapGesture {
                onTap()
            }
            .onLongPressGesture(minimumDuration: 0.5) {
                onLongPress()
            }
    }
}

struct ActionBubbleView: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(color)
                .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct EditNodeView: View {
    var node: MindMapNode
    @State private var title: String
    @State private var notes: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let onDismiss: () -> Void
    
    init(node: MindMapNode, onDismiss: @escaping () -> Void) {
        self.node = node
        self.onDismiss = onDismiss
        self._title = State(initialValue: node.title)
        self._notes = State(initialValue: node.notes)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Title")) {
                    TextField("Enter title", text: $title)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 150)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
            }
            .navigationTitle("Edit Node")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        node.title = title.isEmpty ? "Untitled" : title
                        node.notes = notes
                        try? modelContext.save()
                        onDismiss()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - View Node View
struct ViewNodeView: View {
    var node: MindMapNode
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                // Title Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(node.title.isEmpty ? "Untitled" : node.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                // Notes Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Notes")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    ScrollView {
                        Text(node.notes.isEmpty ? "No notes added yet" : node.notes)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    .frame(minHeight: 150)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("View Node")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
