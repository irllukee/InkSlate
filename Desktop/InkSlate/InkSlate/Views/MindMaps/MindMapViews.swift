//
//  MindMapViews.swift
//  InkSlate
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
        
        if let children = currentNode.children,
           let index = children.firstIndex(where: { $0.id == node.id }) {
            let position = calculateOrbitalPosition(
                index: index,
                totalNodes: children.count,
                centerX: geometry.size.width / 2,
                centerY: geometry.size.height / 2
            )
            return position
        }
        
        return CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
    }
    
    private func calculateOrbitalPosition(index: Int, totalNodes: Int, centerX: CGFloat, centerY: CGFloat) -> CGPoint {
        // Define orbital rings with different radii (2 rings instead of 3)
        let orbitalRings: [CGFloat] = [120, 210]
        
        // Dynamically distribute nodes across rings based on total count
        let (ring, nodeIndexInRing, nodesInThisRing) = distributeNodesAcrossRings(
            index: index,
            totalNodes: totalNodes,
            ringCount: orbitalRings.count
        )
        
        // Ensure ring is within bounds
        let safeRing = min(ring, orbitalRings.count - 1)
        let radius = orbitalRings[safeRing]
        
        // Calculate angle for this node
        let startAngle = -Double.pi / 2  // Start at top
        let angleStep = 2 * Double.pi / Double(max(nodesInThisRing, 1))
        let angle = startAngle + Double(nodeIndexInRing) * angleStep
        
        let x = centerX + cos(angle) * radius
        let y = centerY + sin(angle) * radius
        
        return CGPoint(x: x, y: y)
    }
    
    private func distributeNodesAcrossRings(index: Int, totalNodes: Int, ringCount: Int) -> (ring: Int, indexInRing: Int, nodesInRing: Int) {
        // Ring capacities (ideal max nodes per ring) - 2 rings with 8 and 12 nodes
        let ringCapacities = [8, 12]
        
        // For small numbers of nodes, keep them all on the innermost ring
        if totalNodes <= ringCapacities[0] {
            return (0, index, totalNodes)
        }
        
        // Calculate which ring this node belongs to based on filling rings sequentially
        var nodesAccountedFor = 0
        var currentRing = 0
        
        // Fill rings in order until we find where this node belongs
        for (ringIndex, capacity) in ringCapacities.enumerated() {
            let nodesInThisRing: Int
            
            if totalNodes <= nodesAccountedFor + capacity {
                // This ring is partially filled or is the last ring needed
                nodesInThisRing = totalNodes - nodesAccountedFor
            } else {
                // This ring is completely filled
                nodesInThisRing = capacity
            }
            
            // Check if the current node index falls within this ring
            if index < nodesAccountedFor + nodesInThisRing {
                currentRing = ringIndex
                let indexInRing = index - nodesAccountedFor
                return (currentRing, indexInRing, nodesInThisRing)
            }
            
            nodesAccountedFor += capacity
            
            // Stop if we've accounted for all nodes
            if nodesAccountedFor >= totalNodes {
                break
            }
        }
        
        // Fallback: place on the outermost ring if something went wrong
        let lastRing = min(1, ringCount - 1)
        return (lastRing, index - 8, max(1, totalNodes - 8))
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
                
                // Scaled content (rings, nodes, action bubbles)
                ZStack {
                    orbitalRingsView(geometry: geometry)
                    centerNodeView(geometry: geometry)
                    childNodesView(geometry: geometry)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentNode.children?.count ?? 0)
                    actionBubblesView(geometry: geometry)
                }
                .scaleEffect(calculateZoomScale())
                .animation(.easeInOut(duration: 0.3), value: currentNode.children?.count ?? 0)
                
                // Add button stays fixed (not affected by zoom)
                addButtonView
            }
        }
    }
    
    private func calculateZoomScale() -> CGFloat {
        let childCount = currentNode.children?.count ?? 0
        
        if childCount <= 8 {
            // Only ring 1 visible
            return 1.0
        } else {
            // Both rings visible (up to 20 nodes)
            return 0.75
        }
    }
    
    private var backgroundView: some View {
        Color(.systemBackground)
            .ignoresSafeArea()
            .onTapGesture {
                selectedNodeForAction = nil
            }
    }
    
    private func orbitalRingsView(geometry: GeometryProxy) -> some View {
        let centerX = geometry.size.width / 2
        let centerY = geometry.size.height / 2
        let orbitalRings: [CGFloat] = [120, 210]
        
        // Only show rings that have nodes
        let childCount = currentNode.children?.count ?? 0
        let ringCapacities = [8, 12]
        var visibleRings: [Int] = []
        var nodeCount = 0
        
        for (index, capacity) in ringCapacities.enumerated() {
            if childCount > nodeCount {
                visibleRings.append(index)
                nodeCount += capacity
            }
        }
        
        return ZStack {
            ForEach(visibleRings, id: \.self) { index in
                Circle()
                    .stroke(
                        Color.blue.opacity(0.3),
                        style: StrokeStyle(lineWidth: 2, dash: [8, 4])
                    )
                    .frame(width: orbitalRings[index] * 2, height: orbitalRings[index] * 2)
                    .position(x: centerX, y: centerY)
            }
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
            let position = calculateOrbitalPosition(
                index: index,
                totalNodes: currentNode.children?.count ?? 0,
                centerX: geometry.size.width / 2,
                centerY: geometry.size.height / 2
            )
            
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
            .position(x: position.x, y: position.y)
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
        guard (currentNode.children?.count ?? 0) < 20 else { return }
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
    
    // Dynamic bubble sizes based on position
    private var bubbleSize: CGFloat {
        return isCenter ? 80 : 60
    }
    
    private var fontSize: CGFloat {
        let titleLength = node.title.count
        let baseFontSize: CGFloat = isCenter ? 18 : 16
        
        if titleLength > 8 {
            return max(8, baseFontSize - CGFloat(titleLength - 8) * 0.4)
        }
        return baseFontSize
    }
    
    var body: some View {
        Text(node.title)
            .font(.system(size: fontSize, weight: isCenter ? .semibold : .medium))
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(width: bubbleSize, height: bubbleSize)
            .background(
                ZStack {
                    Circle()
                        .fill(Color.black)
                    
                    if isCenter {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.white.opacity(0.2), Color.clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: bubbleSize / 2
                                )
                            )
                    }
                }
            )
            .overlay(
                Circle()
                    .stroke(
                        isCenter ? Color.blue.opacity(0.6) : Color.gray.opacity(0.5),
                        lineWidth: isCenter ? 2 : 1
                    )
            )
            .shadow(
                color: isCenter ? Color.blue.opacity(0.3) : Color.black.opacity(0.2),
                radius: isCenter ? 8 : 4,
                x: 0,
                y: 2
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

struct ViewNodeView: View {
    var node: MindMapNode
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
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

struct BreadcrumbNavigationView: View {
    let mindMap: MindMap
    let navigationStack: [MindMapNode]
    let currentNode: MindMapNode
    let onNavigateToNode: (Int) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                BreadcrumbItemView(
                    title: mindMap.name,
                    isActive: currentNode.id == mindMap.rootNode?.id,
                    isLast: false
                ) {
                    onNavigateToNode(-1)
                }
                
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
