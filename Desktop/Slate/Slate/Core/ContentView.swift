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

    var body: some View {
        NavigationSplitView {
            MainContentView(selectedView: selectedView)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        HamburgerMenuButton(
                            isMenuOpen: $isMenuOpen,
                            isHovering: $isHovering
                        )
                    }
                }
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
                case .mindMaps:
                    MindMapListView()
                case .notes:
                    NotesListView()
                case .journal:
                    BookshelfView()
                case .settings:
                    SettingsView()
                case .profile:
                    ProfileView()
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
