//
//  SettingsViews.swift
//  Slate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI

// MARK: - Settings Feature Views
struct SettingsView: View {
    var body: some View {
        List {
            Section("General") {
                HStack {
                    Image(systemName: "bell")
                        .foregroundColor(.blue)
                    Text("Notifications")
                }
                HStack {
                    Image(systemName: "paintbrush")
                        .foregroundColor(.purple)
                    Text("Appearance")
                }
            }
            
            Section("About") {
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                    Text("About Slate")
                }
                HStack {
                    Image(systemName: "star")
                        .foregroundColor(.yellow)
                    Text("Rate App")
                }
            }
        }
        .navigationTitle("Settings")
    }
}
