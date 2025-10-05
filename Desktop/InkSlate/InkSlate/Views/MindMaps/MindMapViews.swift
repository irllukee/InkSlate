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
                        Text("\(mindMap.rootNode?.children?.count ?? 0) topics")
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
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                        .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
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
    let mindMap: MindMap
    @Environment(\.modelContext) private var modelContext
    @State private var currentNode: MindMapNode
    @State private var navigationStack: [MindMapNode] = []
    @State private var selectedNodeForAction: MindMapNode?
    @State private var showingEditSheet = false
    @State private var showingViewSheet = false
    @State private var showingDeleteConfirmation = false
    @State private var nodeToDelete: MindMapNode?
    @State private var showingBreadcrumbs = true
    @Environment(\.dismiss) private var dismiss
    
    init(mindMap: MindMap) {
        self.mindMap = mindMap
        self._currentNode = State(initialValue: mindMap.rootNode ?? MindMapNode(title: "Main Node"))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            breadcrumbView
            mindMapContentView
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(navigationStack.isEmpty ? false : true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if !navigationStack.isEmpty {
                    Button(action: navigateBack) {
                        HStack {
                            Image(systemName: "chevron.left")
                                .foregroundColor(DesignSystem.Colors.textPrimary)
                                .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                            Text("Back")
                        }
                    }
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    if !navigationStack.isEmpty {
                        Button(action: { showingBreadcrumbs.toggle() }) {
                            Image(systemName: showingBreadcrumbs ? "list.bullet" : "list.bullet")
                                .foregroundColor(showingBreadcrumbs ? .blue : .gray)
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
                Text("This node has \(node.children?.count ?? 0) child node(s). Are you sure you want to delete it and all its children?")
            }
        }
    }
    
    private func getNodePosition(for node: MindMapNode, in geometry: GeometryProxy) -> CGPoint {
        if node.id == currentNode.id {
            return CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        
        if let index = currentNode.children?.firstIndex(where: { $0.id == node.id }) {
            let angle = Double(index) * (2 * .pi / Double(currentNode.children?.count ?? 0))
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
    
    private func navigateToNodeAtIndex(_ index: Int) {
        if index == -1 {
            navigationStack.removeAll()
            currentNode = mindMap.rootNode ?? MindMapNode(title: "Main Node")
            selectedNodeForAction = nil
        } else if index < navigationStack.count {
            let targetNode = navigationStack[index]
            navigationStack = Array(navigationStack.prefix(index))
            currentNode = targetNode
            selectedNodeForAction = nil
        }
    }
    
    private var breadcrumbView: some View {
        Group {
            if showingBreadcrumbs && (!navigationStack.isEmpty || currentNode.id != mindMap.rootNode?.id) {
                BreadcrumbNavigationView(
                    mindMap: mindMap,
                    navigationStack: navigationStack,
                    currentNode: currentNode,
                    onNavigateToNode: navigateToNodeAtIndex
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
    
    private var mindMapContentView: some View {
        GeometryReader { geometry in
            ZStack {
                backgroundView
                centerNodeView(geometry: geometry)
                childNodesView(geometry: geometry)
                actionBubblesView(geometry: geometry)
                addButtonView
            }
        }
    }
    
    private var backgroundView: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
            .onTapGesture {
                selectedNodeForAction = nil
            }
    }
    
    private func centerNodeView(geometry: GeometryProxy) -> some View {
        NodeBubbleView(
            node: currentNode,
            isCenter: true,
            onTap: {},
            onLongPress: {
                selectedNodeForAction = currentNode
            }
        )
        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
    }
    
    private func childNodesView(geometry: GeometryProxy) -> some View {
        ForEach(Array((currentNode.children ?? []).enumerated()), id: \.element.id) { index, child in
            let childrenCount = currentNode.children?.count ?? 0
            let angle = Double(index) * (2 * .pi / Double(childrenCount))
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
    }
    
    private func actionBubblesView(geometry: GeometryProxy) -> some View {
        Group {
            if let selectedNode = selectedNodeForAction {
                let nodePosition = getNodePosition(for: selectedNode, in: geometry)
                
                HStack(spacing: 15) {
                    ActionBubbleView(title: "View", color: .green) {
                        showingViewSheet = true
                    }
                    
                    ActionBubbleView(title: "Edit", color: .blue) {
                        DispatchQueue.main.async {
                            showingEditSheet = true
                        }
                    }
                    
                    if selectedNode.id != currentNode.id {
                        ActionBubbleView(title: "Delete", color: .red) {
                            if (selectedNode.children?.isEmpty ?? true) {
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
        }
    }
    
    private var addButtonView: some View {
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
                        .shadow(color: DesignSystem.Shadows.medium, radius: 4, x: 0, y: 2)
                }
                .padding(.trailing, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    private func addNewNode() {
        guard (currentNode.children?.count ?? 0) < 10 else { return }
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
    
    // Calculate dynamic sizing based on text length
    private var bubbleSize: CGFloat {
        let titleLength = node.title.count
        let baseSize: CGFloat = 60
        let minSize: CGFloat = 50
        let maxSize: CGFloat = 120
        
        // Adjust size based on text length
        let sizeMultiplier = max(1.0, Double(titleLength) / 8.0)
        let calculatedSize = baseSize * sizeMultiplier
        
        return max(minSize, min(maxSize, calculatedSize))
    }
    
    private var fontSize: CGFloat {
        let titleLength = node.title.count
        let baseFontSize: CGFloat = 14
        
        // Reduce font size for longer text
        if titleLength > 12 {
            return max(10, baseFontSize - CGFloat(titleLength - 12) * 0.3)
        }
        return baseFontSize
    }
    
    var body: some View {
        Text(node.title)
            .font(.system(size: fontSize, weight: .medium))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: bubbleSize, height: bubbleSize)
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
            VStack(spacing: DesignSystem.Spacing.xl) {
                // Title section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Node Title")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    ModernTaskTextField(
                        text: $title,
                        placeholder: "Enter node title",
                        isFocused: .constant(false),
                        isMultiline: false
                    )
                }
                
                // Notes section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Notes")
                        .font(DesignSystem.Typography.callout)
                        .fontWeight(.medium)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    ModernTaskTextField(
                        text: $notes,
                        placeholder: "Add notes for this node...",
                        isFocused: .constant(false),
                        isMultiline: true
                    )
                    .frame(minHeight: 150)
                }
                
                Spacer()
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.background)
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

// MARK: - Breadcrumb Navigation View
struct BreadcrumbNavigationView: View {
    let mindMap: MindMap
    let navigationStack: [MindMapNode]
    let currentNode: MindMapNode
    let onNavigateToNode: (Int) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Root node (mind map name)
                BreadcrumbItemView(
                    title: mindMap.name,
                    isActive: currentNode.id == mindMap.rootNode?.id,
                    isLast: false
                ) {
                    // Navigate to root of this mind map
                    onNavigateToNode(-1)
                }
                
                // Navigation stack nodes (only from current mind map)
                ForEach(Array(navigationStack.enumerated()), id: \.offset) { index, node in
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                        
                        BreadcrumbItemView(
                            title: node.title,
                            isActive: false,
                            isLast: false
                        ) {
                            onNavigateToNode(index)
                        }
                    }
                }
                
                // Current node (only if not at root)
                if currentNode.id != mindMap.rootNode?.id {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                        
                        BreadcrumbItemView(
                            title: currentNode.title,
                            isActive: true,
                            isLast: true
                        ) {
                            // Current node is not clickable
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundColor(Color(.separator)),
            alignment: .bottom
        )
    }
}

struct BreadcrumbItemView: View {
    let title: String
    let isActive: Bool
    let isLast: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 14, weight: isActive ? .semibold : .medium))
                .foregroundColor(isActive ? .primary : .secondary)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isActive ? Color(.systemGray5) : Color.clear)
                )
        }
        .disabled(isLast)
        .buttonStyle(PlainButtonStyle())
    }
}
