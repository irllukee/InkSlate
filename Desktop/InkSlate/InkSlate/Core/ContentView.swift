//
//  ContentView.swift
//  Slate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI
import SwiftData

// MARK: - Main Content View
struct ContentView: View {
    @State private var isMenuOpen = false
    @State private var isHovering = false
    @State private var selectedView: MenuViewType = .items
    @EnvironmentObject var sharedStateManager: SharedStateManager

    var body: some View {
        ZStack {
            // Main app content
            NavigationStack {
                MainContentView(selectedView: selectedView)
                    .toolbar(content: {
                        ToolbarItem(placement: .navigationBarLeading) {
                            HamburgerMenuButton(
                                isMenuOpen: $isMenuOpen,
                                isHovering: $isHovering
                            )
                        }
                    })
            }
            .overlay(
                MenuOverlay(isMenuOpen: $isMenuOpen)
            )
            .overlay(
                SideMenu(
                    isMenuOpen: $isMenuOpen,
                    selectedView: $selectedView
                )
            )
            .overlay(
                CloudKitSyncIndicator()
                    .environmentObject(sharedStateManager)
            )
            .opacity(sharedStateManager.showSplashScreen ? 0 : 1)
            .animation(.easeInOut(duration: 0.3), value: sharedStateManager.showSplashScreen)
            
            // Splash screen
            if sharedStateManager.showSplashScreen {
                SplashScreenView {
                    sharedStateManager.hideSplashScreen()
                }
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Main Content Container
struct MainContentView: View {
    let selectedView: MenuViewType
    
    var body: some View {
        Group {
            switch selectedView {
            case .items:
                ItemsListView()
            case .notes:
                NotesListView()
            case .mindMaps:
                MindMapListView()
            case .journal:
                BookshelfView()
            case .todo:
                TodoMainView()
            case .places:
                PlacesMainView()
            case .watchlist:
                WatchlistMainView()
            case .quotes:
                ModernQuotesMainView()
            case .recipes:
                ModernRecipeMainView()
            case .settings:
                SettingsView()
            case .profile:
                ProfileMainView()
            }
        }
    }
}

// MARK: - Menu Overlay
struct MenuOverlay: View {
    @Binding var isMenuOpen: Bool
    
    var body: some View {
        Group {
            if isMenuOpen {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isMenuOpen = false
                        }
                    }
            }
        }
    }
}

// MARK: - CloudKit Sync Indicator
struct CloudKitSyncIndicator: View {
    @EnvironmentObject private var sharedStateManager: SharedStateManager
    
    var body: some View {
        VStack {
            if sharedStateManager.cloudKitSyncStatus.isActive {
                HStack(spacing: 8) {
                    if sharedStateManager.cloudKitSyncStatus == .syncing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "icloud.fill")
                            .foregroundColor(.white)
                    }
                    
                    Text(sharedStateManager.cloudKitSyncStatus.message)
                        .font(.caption)
                        .foregroundColor(.white)
                    
                    if sharedStateManager.cloudKitSyncStatus == .syncing && sharedStateManager.syncProgress > 0 {
                        Text("\(Int(sharedStateManager.syncProgress * 100))%")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.blue)
                        .shadow(radius: 4)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            Spacer()
        }
        .padding(.top, 60) // Account for safe area
        .animation(.easeInOut(duration: 0.3), value: sharedStateManager.cloudKitSyncStatus.isActive)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
