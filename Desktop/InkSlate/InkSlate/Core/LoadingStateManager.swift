//
//  LoadingStateManager.swift
//  Slate
//
//  Created by UI Overhaul on 9/29/25.
//

import SwiftUI
import SwiftData
import Combine

// MARK: - Loading State Manager
class LoadingStateManager: ObservableObject {
    @Published var isLoading = false
    @Published var loadingMessage = ""
    
    func startLoading(message: String = "Loading...") {
        DispatchQueue.main.async { [weak self] in
            self?.loadingMessage = message
            self?.isLoading = true
        }
    }
    
    func stopLoading() {
        DispatchQueue.main.async { [weak self] in
            self?.isLoading = false
            self?.loadingMessage = ""
        }
    }
}

// MARK: - Auto Save Manager
class AutoSaveManager: ObservableObject {
    private var saveTimer: Timer?
    private let debounceInterval: TimeInterval = 1.0 // Increased to 1 second for better performance
    private var pendingSave = false
    private var lastSaveTime = Date()
    private var modelContext: ModelContext?
    
    @Published var isSaving = false
    @Published var lastSaveStatus = "Ready"
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func scheduleSave() {
        pendingSave = true
        saveTimer?.invalidate()
        saveTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            self?.performSave()
        }
    }
    
    private func performSave() {
        guard pendingSave else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isSaving = true
            self.lastSaveStatus = "Saving..."
        }
        
        // Actually save to SwiftData
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            // Perform the actual save
            do {
                try self.modelContext?.save()
                self.pendingSave = false
                self.lastSaveTime = Date()
                self.isSaving = false
                self.lastSaveStatus = "Saved at \(DateFormatter.timeFormatter.string(from: self.lastSaveTime))"
            } catch {
                print("Failed to save: \(error)")
                self.isSaving = false
                self.lastSaveStatus = "Save failed"
            }
        }
    }
    
    func forceSave() {
        saveTimer?.invalidate()
        performSave()
    }
    
    deinit {
        saveTimer?.invalidate()
        saveTimer = nil
    }
}

// MARK: - Date Formatter Extension
extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Model Context Extensions
extension ModelContext {
    func saveWithDebounce(using autoSaveManager: AutoSaveManager) {
        autoSaveManager.setModelContext(self)
        autoSaveManager.scheduleSave()
        try? self.save()
    }
    
    func forceSave() {
        try? self.save()
    }
}

// MARK: - Loading Overlay View Modifier
struct LoadingOverlayModifier: ViewModifier {
    @ObservedObject var loadingManager: LoadingStateManager
    
    func body(content: Content) -> some View {
        ZStack {
            content
            
            if loadingManager.isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                
                VStack(spacing: DesignSystem.Spacing.md) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .progressViewStyle(CircularProgressViewStyle(tint: DesignSystem.Colors.accent))
                    
                    if !loadingManager.loadingMessage.isEmpty {
                        Text(loadingManager.loadingMessage)
                            .font(DesignSystem.Typography.body)
                            .foregroundColor(DesignSystem.Colors.textPrimary)
                    }
                }
                .padding(DesignSystem.Spacing.xl)
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                        .fill(DesignSystem.Colors.surface)
                        .shadow(color: DesignSystem.Shadows.medium, radius: 8, x: 0, y: 4)
                )
            }
        }
    }
}

extension View {
    func loadingOverlay(loadingManager: LoadingStateManager) -> some View {
        modifier(LoadingOverlayModifier(loadingManager: loadingManager))
    }
}
