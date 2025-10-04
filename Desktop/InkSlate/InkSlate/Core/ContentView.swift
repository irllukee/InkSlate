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
            NavigationSplitView {
                MainContentView(selectedView: selectedView)
                    .toolbar(content: {
                        ToolbarItem(placement: .navigationBarLeading) {
                            HamburgerMenuButton(
                                isMenuOpen: $isMenuOpen,
                                isHovering: $isHovering
                            )
                        }
                    })
            } detail: {
                Text("Select a feature")
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

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
