//
//  ProfileViews.swift
//  InkSlate
//
//  Created by UI Overhaul on 9/29/25.
//

import SwiftUI

// MARK: - Profile Main View
struct ProfileMainView: View {
    @State private var showingAbout = false
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            // Profile Header
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Profile Image
                ZStack {
                    Circle()
                        .fill(DesignSystem.Colors.accent.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(DesignSystem.Colors.accent)
                }
                
                // Profile Info
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("InkSlate User")
                        .font(DesignSystem.Typography.title1)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("Local data storage")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }
            
            // Profile Actions
            VStack(spacing: DesignSystem.Spacing.md) {
                Button(action: { showingAbout = true }) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 16, weight: .medium))
                        Text("About")
                            .font(DesignSystem.Typography.body)
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                    .padding(DesignSystem.Spacing.lg)
                    .background(DesignSystem.Colors.surface)
                    .minimalistCard(.outlined)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.background)
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAbout) {
            AboutView()
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                // App Icon and Info
                VStack(spacing: DesignSystem.Spacing.lg) {
                    ZStack {
                        RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.lg)
                            .fill(DesignSystem.Colors.accent.opacity(0.1))
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "app.fill")
                            .font(.system(size: 40))
                            .foregroundColor(DesignSystem.Colors.accent)
                    }
                    
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Text("InkSlate")
                            .font(DesignSystem.Typography.title1)
                            .fontWeight(.bold)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Version 1.0.0")
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                
                // App Description
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("About InkSlate")
                        .font(DesignSystem.Typography.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("InkSlate is your personal productivity companion, designed to help you organize your thoughts, manage your tasks, and keep track of your life in a beautiful, minimalist interface. All data is stored locally on your device.")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                // Credits
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Made with ❤️")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                    
                    Text("© 2024 InkSlate. All rights reserved.")
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.background)
            .navigationTitle("About")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(DesignSystem.Colors.accent)
                }
            }
        }
    }
}