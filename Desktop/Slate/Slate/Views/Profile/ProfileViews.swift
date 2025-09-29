//
//  ProfileViews.swift
//  Slate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI

// MARK: - Profile Feature Views
struct ProfileView: View {
    var body: some View {
        VStack(spacing: 20) {
            // Profile Picture
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            VStack(spacing: 8) {
                Text("User Profile")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("user@example.com")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            List {
                Section("Account") {
                    HStack {
                        Image(systemName: "person")
                        Text("Edit Profile")
                    }
                    HStack {
                        Image(systemName: "key")
                        Text("Change Password")
                    }
                }
                
                Section("Data") {
                    HStack {
                        Image(systemName: "icloud")
                        Text("Sync Data")
                    }
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Cache")
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .navigationTitle("Profile")
    }
}
