//
//  ItemsViews.swift
//  Slate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI
import SwiftData

// MARK: - Modern Homescreen Views
struct ItemsListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var currentTime = Date()
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with time/date and profile
            ModernHomeHeader(currentTime: currentTime)
            
            // Main content area
            ModernHomeMainView()
        }
        .background(DesignSystem.Colors.background)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Modern Home Header
struct ModernHomeHeader: View {
    let currentTime: Date
    @State private var showingProfile = false
    @State private var profileName = "User"
    @State private var profileEmail = "user@example.com"
    @EnvironmentObject var shared: SharedStateManager
    
    var body: some View {
        HStack {
            Spacer()
            
            // Modern Profile Section
            Button(action: {
                showingProfile = true
            }) {
                HStack(spacing: 8) {
                    // Profile Avatar
                    ZStack {
                        Circle()
                            .fill(DesignSystem.Colors.accent)
                            .frame(width: 40, height: 40)
                        Text(String(profileName.prefix(1)).uppercased())
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textInverse)
                    }
                    
                    // Profile Info
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(profileName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                        
                        Text("Welcome back")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(DesignSystem.Colors.textSecondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(DesignSystem.Colors.surface)
                                .shadow(color: DesignSystem.Shadows.medium, radius: 4, x: 0, y: 2)
                        )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .onAppear {
            loadProfile()
        }
        .sheet(isPresented: $showingProfile) {
            ProfileMainView()
        }
    }
    
    private func loadProfile() {
        // Use default profile info for local-only app
        profileName = "InkSlate User"
        profileEmail = "local@inkslate.app"
    }
}

// MARK: - Modern Home Main View
struct ModernHomeMainView: View {
    @State private var currentTime = Date()
    @State private var timer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Bottom time and date with modern animations
            ModernBottomTimeDisplay(currentTime: currentTime)
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            currentTime = Date()
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Modern Activity Snapshot
struct ModernActivitySnapshot: View {
    @State private var currentValue = 66
    @State private var maxValue = 96
    @State private var minValue = 4
    @State private var avgValue = 46
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Activity Snapshot")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                
                Spacer()
                
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(currentValue)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("Updated: \(Date().formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Mini chart
                VStack(spacing: 4) {
                    HStack(spacing: 2) {
                        ForEach(0..<8) { index in
                            Rectangle()
                                .fill(index % 3 == 0 ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 3, height: CGFloat.random(in: 8...20))
                        }
                    }
                    
                    HStack(spacing: 8) {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                        
                        Image(systemName: "figure.walk")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                    }
                }
            }
            
            HStack(spacing: DesignSystem.Spacing.lg) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(maxValue) Max")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(minValue) Min")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(avgValue) Avg")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(DesignSystem.Colors.surface)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Modern Bottom Time Display
struct ModernBottomTimeDisplay: View {
    let currentTime: Date
    @State private var isVisible = false
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Bottom time
            Text(timeFormatter.string(from: currentTime))
                .font(.system(size: 22, weight: .medium))
                .foregroundColor(.black)
            
            // Bottom date
            Text(dateFormatter.string(from: currentTime))
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.bottom, DesignSystem.Spacing.xl)
    }
}

// MARK: - Modern Stat Card
struct ModernStatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(color)
                            .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 24, weight: .semibold, design: .default))
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                
                Text(subtitle)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(color)
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .minimalistCard(.outlined)
    }
}

// MARK: - Modern Trends Section
struct ModernTrendsSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var quotes: [Quote]
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Trends")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                
                Spacer()
                
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                        .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
            }
            
            HStack(spacing: DesignSystem.Spacing.md) {
                // Quotes productivity
                ModernTrendCard(
                    title: "Quotes Saved",
                    value: "\(quotes.count)",
                    subtitle: "Total quotes saved",
                    color: .blue
                )
            }
        }
    }
}

// MARK: - Modern Trend Card
struct ModernTrendCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.black)
            
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.lg)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct ActivityItem {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let date: Date
}

// MARK: - Modern Activity Item
struct ModernActivityItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(DesignSystem.Typography.body)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
                
                Text(subtitle)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }
            
            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .minimalistCard(.outlined)
    }
}

// MARK: - Modern Quick Actions Section
struct ModernQuickActionsSection: View {
    @State private var showingAddNote = false
    @State private var showingAddTask = false
    @State private var showingAddQuote = false
    @State private var showingAddRecipe = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Quick Actions")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.md) {
                ModernQuickActionCard(
                    title: "New Note",
                    icon: "note.text",
                    color: .green,
                    action: { showingAddNote = true }
                )
                
                ModernQuickActionCard(
                    title: "Add Task",
                    icon: "plus.circle",
                    color: .blue,
                    action: { showingAddTask = true }
                )
                
                ModernQuickActionCard(
                    title: "Save Quote",
                    icon: "quote.bubble",
                    color: .orange,
                    action: { showingAddQuote = true }
                )
                
                ModernQuickActionCard(
                    title: "New Recipe",
                    icon: "fork.knife",
                    color: .purple,
                    action: { showingAddRecipe = true }
                )
            }
        }
        .sheet(isPresented: $showingAddNote) {
            // Add note sheet - you can create a simple add note view
            Text("Add Note Sheet")
        }
        .sheet(isPresented: $showingAddTask) {
            // Add task sheet - you can create a simple add task view
            Text("Add Task Sheet")
        }
        .sheet(isPresented: $showingAddQuote) {
            // Add quote sheet - you can create a simple add quote view
            Text("Add Quote Sheet")
        }
        .sheet(isPresented: $showingAddRecipe) {
            // Add recipe sheet - you can create a simple add recipe view
            Text("Add Recipe Sheet")
        }
    }
}

// MARK: - Modern Quick Action Card
struct ModernQuickActionCard: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                            Image(systemName: icon)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(color)
                                .shadow(color: DesignSystem.Shadows.small, radius: 1, x: 0, y: 1)
                }
                
                Text(title)
                    .font(DesignSystem.Typography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(DesignSystem.Colors.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.lg)
            .minimalistCard(.outlined)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Modern Weather Widget
struct ModernWeatherWidget: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Weather")
                .font(DesignSystem.Typography.title2)
                .fontWeight(.semibold)
                .foregroundColor(DesignSystem.Colors.textPrimary)
            
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("22°")
                        .font(.system(size: 36, weight: .light, design: .default))
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                    
                    Text("Sunny")
                        .font(DesignSystem.Typography.body)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundColor(.orange)
            }
            .padding(DesignSystem.Spacing.lg)
            .minimalistCard(.outlined)
        }
    }
}
