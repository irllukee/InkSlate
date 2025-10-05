//
//  TodoViews_Simple.swift
//  Slate
//
//  Created by UI Overhaul on 9/29/25.
//

import SwiftUI
import SwiftData

// MARK: - Simplified Todo View

struct TodoMainView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sharedState: SharedStateManager
    
    @Query(sort: \TodoTab.createdDate, order: .forward) private var tabs: [TodoTab]
    @State private var selectedTab: TodoTab?
    @State private var showingAddTask = false
    @State private var showingAddTab = false
    @State private var showingEditTab = false
    @State private var editingTab: TodoTab?
    
    // Computed property for current tab's tasks
    private var currentTasks: [TodoTask] {
        guard let selectedTab = selectedTab,
              let tasks = selectedTab.tasks else { return [] }
        return tasks.sorted { !$0.isCompleted && $1.isCompleted }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                if !tabs.isEmpty {
                    TabSelectorView(
                        tabs: tabs,
                        selectedTab: $selectedTab,
                        onAddTab: { showingAddTab = true },
                        onEditTab: { tab in
                            editingTab = tab
                            showingEditTab = true
                        },
                        onDeleteTab: { tab in
                            deleteTab(tab)
                        }
                    )
                }
                
                // Content Area
                if tabs.isEmpty {
                    // Empty state
                    VStack(spacing: DesignSystem.Spacing.xl) {
                        Image(systemName: "list.bullet.rectangle")
                            .font(.system(size: 48))
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                        
                        Text("No todo lists yet")
                            .font(DesignSystem.Typography.title2)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Create your first todo list to get started")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DesignSystem.Spacing.xl)
                        
                        Button("Create List") {
                            showingAddTab = true
                        }
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignSystem.Spacing.xl)
                        .padding(.vertical, DesignSystem.Spacing.md)
                        .background(DesignSystem.Colors.accent)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let selectedTab = selectedTab {
                    // Tasks for selected tab
                    ScrollView {
                        LazyVStack(spacing: DesignSystem.Spacing.md) {
                            if currentTasks.isEmpty {
                                VStack(spacing: DesignSystem.Spacing.lg) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.system(size: 32))
                                        .foregroundColor(DesignSystem.Colors.textTertiary)
                                    
                                    Text("No tasks in '\(selectedTab.name)'")
                                        .font(DesignSystem.Typography.title3)
                                        .foregroundColor(DesignSystem.Colors.textPrimary)
                                    
                                    Text("Tap 'Add Task' to create your first task")
                                        .font(DesignSystem.Typography.body)
                                        .foregroundColor(DesignSystem.Colors.textSecondary)
                                }
                                .padding(.top, 60)
                            } else {
                                ForEach(currentTasks) { task in
                                    TodoTaskRow(task: task)
                                }
                            }
                        }
                        .padding(DesignSystem.Spacing.lg)
                    }
                }
            }
            .navigationTitle(selectedTab?.name ?? "Todo Lists")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if !tabs.isEmpty {
                            Button("Add List") {
                                showingAddTab = true
                            }
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                        }
                        
                        Button("Add Task") {
                            showingAddTask = true
                        }
                        .foregroundColor(DesignSystem.Colors.accent)
                        .disabled(tabs.isEmpty)
                    }
                }
            }
        }
        .onAppear {
            // Auto-select first tab if none selected
            if selectedTab == nil && !tabs.isEmpty {
                selectedTab = tabs.first
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddTodoTaskView(selectedTab: selectedTab, availableTabs: tabs)
        }
        .sheet(isPresented: $showingAddTab) {
            AddTodoTabView()
        }
        .sheet(isPresented: $showingEditTab) {
            if let tab = editingTab {
                EditTodoTabView(tab: tab)
            }
        }
    }
    
    private func deleteTab(_ tab: TodoTab) {
        do {
            modelContext.delete(tab)
            try modelContext.save()
            
            // If the deleted tab was selected, select another tab
            if selectedTab === tab {
                selectedTab = tabs.first { $0 !== tab }
            }
        } catch {
            // Handle delete error silently
        }
    }
}

// MARK: - Tab Selector View
struct TabSelectorView: View {
    let tabs: [TodoTab]
    @Binding var selectedTab: TodoTab?
    let onAddTab: () -> Void
    let onEditTab: (TodoTab) -> Void
    let onDeleteTab: (TodoTab) -> Void
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(tabs) { tab in
                    TabButtonView(
                        tab: tab,
                        isSelected: selectedTab === tab,
                        onTap: { selectedTab = tab },
                        onEdit: { onEditTab(tab) },
                        onDelete: { onDeleteTab(tab) }
                    )
                }
                
                // Add new tab button
                Button(action: onAddTab) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                        Text("New List")
                            .font(DesignSystem.Typography.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.backgroundSecondary)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .stroke(DesignSystem.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.background)
    }
}

// MARK: - Tab Button View
struct TabButtonView: View {
    let tab: TodoTab
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Circle()
                    .fill(tab.color)
                    .frame(width: 8, height: 8)
                
                Text(tab.name)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
                
                Text("\(tab.tasks?.count ?? 0)")
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, DesignSystem.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.xs)
                            .fill(isSelected ? Color.white.opacity(0.2) : DesignSystem.Colors.backgroundTertiary)
                    )
            }
            .foregroundColor(isSelected ? .white : DesignSystem.Colors.textPrimary)
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                    .fill(isSelected ? tab.color : DesignSystem.Colors.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .stroke(isSelected ? tab.color.opacity(0.3) : DesignSystem.Colors.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button("Edit Name") {
                onEdit()
            }
            
            Button("Delete List", role: .destructive) {
                onDelete()
            }
            .disabled(tab.tasks?.isEmpty == false) // Only allow deletion of empty lists
        }
    }
}

// MARK: - Todo Task Row
struct TodoTaskRow: View {
    let task: TodoTask
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Button {
                toggleTaskCompletion()
            } label: {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(task.isCompleted ? DesignSystem.Colors.success : DesignSystem.Colors.textTertiary)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(task.title)
                    .font(DesignSystem.Typography.body)
                    .fontWeight(.medium)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? DesignSystem.Colors.textSecondary : DesignSystem.Colors.textPrimary)
                
                if !task.taskDescription.isEmpty {
                    Text(task.taskDescription)
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .lineLimit(3)
                }
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(DesignSystem.CornerRadius.sm)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                .stroke(DesignSystem.Colors.border, lineWidth: 0.5)
        )
    }
    
    private func toggleTaskCompletion() {
        task.isCompleted.toggle()
        task.completedDate = task.isCompleted ? Date() : Date.distantPast
        try? modelContext.save()
    }
}

// MARK: - Add Task View

struct AddTodoTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let initialSelectedTab: TodoTab?
    let availableTabs: [TodoTab]
    @State private var title = ""
    @State private var description = ""
    @State private var selectedTab: TodoTab?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(selectedTab: TodoTab?, availableTabs: [TodoTab]) {
        self.initialSelectedTab = selectedTab
        self.availableTabs = availableTabs
        self._selectedTab = State(initialValue: selectedTab)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Text("Task Details")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Title")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                TextField("Enter task title", text: $title)
                                    .font(DesignSystem.Typography.body)
                                    .padding(DesignSystem.Spacing.md)
                                    .background(DesignSystem.Colors.surface)
                                    .cornerRadius(DesignSystem.CornerRadius.sm)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                            .stroke(DesignSystem.Colors.border, lineWidth: 0.5)
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Description")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundColor(DesignSystem.Colors.textSecondary)
                                
                                TextField("Add a description (optional)", text: $description, axis: .vertical)
                                    .font(DesignSystem.Typography.body)
                                    .lineLimit(3...6)
                                    .padding(DesignSystem.Spacing.md)
                                    .background(DesignSystem.Colors.surface)
                                    .cornerRadius(DesignSystem.CornerRadius.sm)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                            .stroke(DesignSystem.Colors.border, lineWidth: 0.5)
                                    )
                            }
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .background(DesignSystem.Colors.surface)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                            .stroke(DesignSystem.Colors.border, lineWidth: 0.5)
                    )
                    .shadow(color: DesignSystem.Shadows.small, radius: 2, x: 0, y: 1)
                    
                    Spacer()
                    
                    Button {
                        addTask()
                    } label: {
                        Text("Add Task")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textInverse)
                            .frame(maxWidth: .infinity)
                            .padding(DesignSystem.Spacing.lg)
                            .background(title.isEmpty ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.accent)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                    }
                    .disabled(title.isEmpty)
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.accent)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func addTask() {
        // Ensure we have a valid title
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        // Use the selected tab or fallback to first available tab
        let targetTab: TodoTab
        if let selectedTab = selectedTab {
            targetTab = selectedTab
        } else if let firstTab = availableTabs.first {
            targetTab = firstTab
        } else {
            // This shouldn't happen with the new UI, but keep as fallback
            targetTab = TodoTab(name: "My Tasks", color: .blue)
            modelContext.insert(targetTab)
        }
        
        // Create the new task
        let newTask = TodoTask(
            title: trimmedTitle,
            description: description.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        // Assign to the tab
        newTask.tab = targetTab
        
        // Save to context
        modelContext.insert(newTask)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save task: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Add Todo Tab View
struct AddTodoTabView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var tabName = ""
    @State private var selectedColor: Color = .blue
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private let availableColors: [Color] = [
        .blue, .green, .orange, .red, .purple, .pink, .cyan, .mint, .indigo, .brown
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("List Name")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        TextField("Enter list name", text: $tabName)
                            .font(DesignSystem.Typography.body)
                            .padding(DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.surface)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                    .stroke(DesignSystem.Colors.border, lineWidth: 0.5)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Color")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: DesignSystem.Spacing.md) {
                            ForEach(availableColors, id: \.self) { color in
                                Button {
                                    selectedColor = color
                                } label: {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 1)
                                        )
                                        .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        createTab()
                    } label: {
                        Text("Create List")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textInverse)
                            .frame(maxWidth: .infinity)
                            .padding(DesignSystem.Spacing.lg)
                            .background(tabName.isEmpty ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.accent)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                    }
                    .disabled(tabName.isEmpty)
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("New List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func createTab() {
        do {
            let newTab = TodoTab(name: tabName.trimmingCharacters(in: .whitespacesAndNewlines), color: selectedColor)
            modelContext.insert(newTab)
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to create list: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Edit Todo Tab View
struct EditTodoTabView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let tab: TodoTab
    @State private var tabName: String
    @State private var selectedColor: Color
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteConfirmation = false
    
    private let availableColors: [Color] = [
        .blue, .green, .orange, .red, .purple, .pink, .cyan, .mint, .indigo, .brown
    ]
    
    init(tab: TodoTab) {
        self.tab = tab
        self._tabName = State(initialValue: tab.name)
        self._selectedColor = State(initialValue: tab.color)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xl) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("List Name")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        TextField("Enter list name", text: $tabName)
                            .font(DesignSystem.Typography.body)
                            .padding(DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.surface)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                    .stroke(DesignSystem.Colors.border, lineWidth: 0.5)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Color")
                            .font(DesignSystem.Typography.callout)
                            .fontWeight(.medium)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: DesignSystem.Spacing.md) {
                            ForEach(availableColors, id: \.self) { color in
                                Button {
                                    selectedColor = color
                                } label: {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.white, lineWidth: selectedColor == color ? 3 : 1)
                                        )
                                        .scaleEffect(selectedColor == color ? 1.1 : 1.0)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Delete button
                    if tab.tasks?.isEmpty ?? true {
                        Button {
                            showingDeleteConfirmation = true
                        } label: {
                            Text("Delete List")
                                .font(DesignSystem.Typography.body)
                                .foregroundColor(.red)
                                .frame(maxWidth: .infinity)
                                .padding(DesignSystem.Spacing.md)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(DesignSystem.CornerRadius.sm)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.sm)
                                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                )
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        saveChanges()
                    } label: {
                        Text("Save Changes")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textInverse)
                            .frame(maxWidth: .infinity)
                            .padding(DesignSystem.Spacing.lg)
                            .background(tabName.isEmpty ? DesignSystem.Colors.textTertiary : DesignSystem.Colors.accent)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                    }
                    .disabled(tabName.isEmpty)
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .background(DesignSystem.Colors.background)
            .navigationTitle("Edit List")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Delete List", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteTab()
                }
            } message: {
                Text("Are you sure you want to delete '\(tab.name)'? This action cannot be undone.")
            }
        }
    }
    
    private func saveChanges() {
        do {
            tab.name = tabName.trimmingCharacters(in: .whitespacesAndNewlines)
            tab.color = selectedColor
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to save changes: \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func deleteTab() {
        do {
            modelContext.delete(tab)
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Failed to delete list: \(error.localizedDescription)"
            showingError = true
        }
    }
}
