//
//  NavigationComponents.swift
//  Slate
//
//  Created by Lucas Waldron on 9/29/25.
//

import SwiftUI

// MARK: - Navigation Types
enum MenuViewType: String, CaseIterable {
    case items = "Items"
    case mindMaps = "Mind Maps"
    case notes = "Notes"
    case journal = "Journal"
    case settings = "Settings"
    case profile = "Profile"
    
    var icon: String {
        switch self {
        case .items: return "list.bullet"
        case .mindMaps: return "brain.head.profile"
        case .notes: return "note.text"
        case .journal: return "book.closed"
        case .settings: return "gear"
        case .profile: return "person.fill"
        }
    }
}

// MARK: - Hamburger Menu Components
struct HamburgerMenuButton: View {
    @Binding var isMenuOpen: Bool
    @Binding var isHovering: Bool
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                isMenuOpen.toggle()
            }
        }) {
            VStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Rectangle()
                        .fill(Color.primary)
                        .frame(width: 18, height: 2)
                        .cornerRadius(1)
                        .scaleEffect(isMenuOpen ? (index == 0 ? 0.8 : index == 1 ? 1.2 : 0.8) : 1.0)
                        .rotationEffect(.degrees(isMenuOpen ? (index == 0 ? 45 : index == 1 ? 0 : -45) : 0))
                        .offset(x: isMenuOpen ? (index == 0 ? 6 : index == 1 ? 0 : -6) : 0)
                }
            }
            .frame(width: 20, height: 18)
        }
        .scaleEffect(isHovering ? 1.1 : 1.0)
        .opacity(isHovering ? 0.7 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Menu Item Component
struct MenuItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 20)
                .foregroundColor(isSelected ? .white : .primary)
            
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
            
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor : (isHovering ? Color.accentColor.opacity(0.1) : Color.clear))
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            action()
        }
    }
}

// MARK: - Side Menu Component
struct SideMenu: View {
    @Binding var isMenuOpen: Bool
    @Binding var selectedView: MenuViewType
    
    var body: some View {
        HStack {
            if isMenuOpen {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Navigation")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top, 20)
                    
                    // Menu items
                    VStack(alignment: .leading, spacing: 15) {
                        ForEach(MenuViewType.allCases, id: \.self) { viewType in
                            MenuItem(
                                title: viewType.rawValue,
                                icon: viewType.icon,
                                isSelected: selectedView == viewType
                            ) {
                                selectedView = viewType
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    isMenuOpen = false
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .frame(width: 250)
                .background(Color(.systemBackground))
                .shadow(radius: 10)
                .transition(.move(edge: .leading))
            }
            Spacer()
        }
    }
}
