//
//  SettingsViews.swift
//  Slate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI

// MARK: - Settings Feature Views
struct SettingsView: View {
    @State private var showingMenuReorder = false
    @State private var showingPrivacySettings = false
    @State private var showingAdvancedSettings = false
    @EnvironmentObject var shared: SharedStateManager
    
    var body: some View {
        List {
            Section("Menu Customization") {
                Button(action: {
                    showingMenuReorder = true
                }) {
                    HStack {
                        Image(systemName: "list.bullet.rectangle")
                            .foregroundColor(DesignSystem.Colors.accent)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                        Text("Reorder Menu Items")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .font(.caption)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                    }
                }
                .foregroundColor(.primary)
            }
            
            
            Section("Privacy & Security") {
                Button(action: {
                    showingPrivacySettings = true
                }) {
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(DesignSystem.Colors.accent)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                        Text("Privacy Settings")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .font(.caption)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                    }
                }
                .foregroundColor(.primary)
            }
            
            Section("Advanced") {
                Button(action: {
                    showingAdvancedSettings = true
                }) {
                    HStack {
                        Image(systemName: "gearshape.2")
                            .foregroundColor(DesignSystem.Colors.accent)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                        Text("Advanced Settings")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                            .font(.caption)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                    }
                }
                .foregroundColor(.primary)
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showingMenuReorder) {
            MenuReorderView()
        }
        .sheet(isPresented: $showingPrivacySettings) {
            PrivacySettingsView()
        }
        .sheet(isPresented: $showingAdvancedSettings) {
            AdvancedSettingsView()
        }
        
    }
}

// MARK: - Menu Reorder View
struct MenuReorderView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var menuItems: [MenuViewType] = MenuViewType.allCases
    @State private var hiddenItems: Set<MenuViewType> = []
    
    var body: some View {
        NavigationView {
            List {
                Section("Visible Menu Items") {
                    ForEach(menuItems.filter { !hiddenItems.contains($0) }, id: \.self) { item in
                        HStack {
                            Image(systemName: item.icon)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(item.rawValue)
                            Spacer()
                            Button(action: {
                                toggleVisibility(for: item)
                            }) {
                                Image(systemName: "eye.slash")
                                    .foregroundColor(.red)
                            }
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove(perform: moveVisibleItems)
                }
                
                if !hiddenItems.isEmpty {
                    Section("Hidden Menu Items") {
                        ForEach(Array(hiddenItems), id: \.self) { item in
                            HStack {
                                Image(systemName: item.icon)
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                Text(item.rawValue)
                                    .foregroundColor(.gray)
                                Spacer()
                                Button(action: {
                                    toggleVisibility(for: item)
                                }) {
                                    Image(systemName: "eye")
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Customize Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveMenuConfiguration()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            loadMenuConfiguration()
        }
    }
    
    private func moveVisibleItems(from source: IndexSet, to destination: Int) {
        let visibleItems = menuItems.filter { !hiddenItems.contains($0) }
        var newOrder = visibleItems
        newOrder.move(fromOffsets: source, toOffset: destination)
        
        // Update the main menuItems array with the new order
        var updatedMenuItems: [MenuViewType] = []
        for item in newOrder {
            if menuItems.contains(item) {
                updatedMenuItems.append(item)
            }
        }
        // Add hidden items at the end
        for item in menuItems {
            if hiddenItems.contains(item) && !updatedMenuItems.contains(item) {
                updatedMenuItems.append(item)
            }
        }
        menuItems = updatedMenuItems
    }
    
    private func toggleVisibility(for item: MenuViewType) {
        if hiddenItems.contains(item) {
            hiddenItems.remove(item)
        } else {
            hiddenItems.insert(item)
        }
    }
    
    private func loadMenuConfiguration() {
        // Load saved menu order
        if let savedOrder = UserDefaults.standard.array(forKey: "MenuOrder") as? [String] {
            let orderedItems = savedOrder.compactMap { MenuViewType(rawValue: $0) }
            if !orderedItems.isEmpty {
                menuItems = orderedItems
            }
        }
        
        // Load hidden items
        if let hiddenItemsData = UserDefaults.standard.array(forKey: "HiddenMenuItems") as? [String] {
            hiddenItems = Set(hiddenItemsData.compactMap { MenuViewType(rawValue: $0) })
        }
    }
    
    private func saveMenuConfiguration() {
        // Save menu order
        UserDefaults.standard.set(menuItems.map { $0.rawValue }, forKey: "MenuOrder")
        
        // Save hidden items
        UserDefaults.standard.set(Array(hiddenItems).map { $0.rawValue }, forKey: "HiddenMenuItems")
    }
}


// MARK: - Privacy Settings View
struct PrivacySettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var analyticsEnabled = false
    @State private var crashReportingEnabled = true
    @State private var dataCollectionEnabled = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Analytics & Privacy") {
                    Toggle("Analytics", isOn: $analyticsEnabled)
                    Toggle("Crash Reporting", isOn: $crashReportingEnabled)
                    Toggle("Data Collection", isOn: $dataCollectionEnabled)
                }
                
                Section("Data Control") {
                    Button("Clear All Data") {
                        clearAllData()
                    }
                    .foregroundColor(.red)
                    
                    Button("Reset Privacy Settings") {
                        resetPrivacySettings()
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Privacy Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func clearAllData() {
        // Implement data clearing logic
    }
    
    private func resetPrivacySettings() {
        analyticsEnabled = false
        crashReportingEnabled = true
        dataCollectionEnabled = false
    }
}


// MARK: - Advanced Settings View
struct AdvancedSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var debugMode = false
    @State private var verboseLogging = false
    @State private var cacheSize = "100 MB"
    
    var body: some View {
        NavigationView {
            Form {
                Section("Debug Options") {
                    Toggle("Debug Mode", isOn: $debugMode)
                    Toggle("Verbose Logging", isOn: $verboseLogging)
                }
                
                Section("Performance") {
                    HStack {
                        Text("Cache Size")
                        Spacer()
                        Text(cacheSize)
                            .foregroundColor(.secondary)
                    }
                    
                    Button("Clear Cache") {
                        clearCache()
                    }
                    .foregroundColor(.blue)
                }
                
                Section("Reset") {
                    Button("Reset App Settings") {
                        resetAppSettings()
                    }
                    .foregroundColor(.orange)
                    
                    Button("Factory Reset") {
                        factoryReset()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Advanced Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func clearCache() {
        // Implement cache clearing logic
    }
    
    private func resetAppSettings() {
        // Implement settings reset logic
    }
    
    private func factoryReset() {
        // Implement factory reset logic
    }
}

// MARK: - Share Sheet
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
