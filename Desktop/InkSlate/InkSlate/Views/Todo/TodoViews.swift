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
    @State private var selectedTabId: UUID?
    @State private var showingAddTask = false
    @State private var showingSettings = false
    @State private var showingAddTab = false
    
    var body: some View {
        VStack {
            Text("Todo Lists")
                .font(.title)
                .padding()
            
            if tabs.isEmpty {
                Text("No todo lists yet")
                    .foregroundColor(.secondary)
            } else {
                List(tabs) { tab in
                    Text(tab.name)
                        .foregroundColor(tab.color)
                }
            }
            
            Button("Add Task") {
                showingAddTask = true
            }
            .padding()
        }
        .sheet(isPresented: $showingAddTask) {
            AddTodoTaskView(selectedTabId: selectedTabId, availableTabs: tabs)
        }
    }
}

// MARK: - Add Task View

struct AddTodoTaskView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let initialSelectedTabId: UUID?
    let availableTabs: [TodoTab]
    @State private var title = ""
    @State private var description = ""
    @State private var selectedTabId: UUID?
    
    init(selectedTabId: UUID?, availableTabs: [TodoTab]) {
        self.initialSelectedTabId = selectedTabId
        self.availableTabs = availableTabs
        self._selectedTabId = State(initialValue: selectedTabId)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Task title", text: $title)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                TextField("Description", text: $description)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Button("Add Task") {
                    addTask()
                }
                .disabled(title.isEmpty)
                .padding()
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func addTask() {
        let newTask = TodoTask(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        if let tab = availableTabs.first {
            newTask.tab = tab
        }
        
        modelContext.insert(newTask)
        try? modelContext.save()
        dismiss()
    }
}
