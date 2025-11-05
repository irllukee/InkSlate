//
//  PersistenceController.swift
//  InkSlate
//
//  Created by Lucas Waldron on 1/2/25.
//

import CoreData
import CloudKit
import Combine
import os.log
import UIKit

// MARK: - PersistenceController

final class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer
    private let logger = Logger(subsystem: "com.lucas.InkSlateNew", category: "CloudKit")
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var syncStatus: CloudKitStatus = .unknown
    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date? {
        didSet {
            if let date = lastSyncDate {
                UserDefaults.standard.set(date, forKey: "lastSyncDate")
            }
        }
    }

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "InkSlate")

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        } else {
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve a persistent store description.")
            }

            // Enable CloudKit syncing
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            // Configure CloudKit container
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.lucas.InkSlateNew"
            )

            logger.info("CloudKit configured: iCloud.com.lucas.InkSlateNew")
        }

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                self.logger.error("❌ Failed to load store: \(error.localizedDescription)")
                if error.domain == CKErrorDomain {
                    self.logger.error("CloudKit error details: \(error.userInfo)")
                }
                return
            }
            self.logger.info("✅ Persistent store loaded successfully")
        }

        // Context setup for optimal CloudKit sync
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        try? container.viewContext.setQueryGenerationFrom(.current)
        
        // Restore persisted last sync date
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date

        // Register for CloudKit push notifications
        UIApplication.shared.registerForRemoteNotifications()

        // Start monitoring
        setupCloudKitMonitoring()
        checkInitialCloudKitStatus()
    }

    // MARK: - CloudKit Monitoring

    private func setupCloudKitMonitoring() {
        NotificationCenter.default.publisher(for: NSPersistentCloudKitContainer.eventChangedNotification)
            .compactMap { $0.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event }
            .sink { [weak self] event in
                self?.handleCloudKitEvent(event)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange)
            .sink { [weak self] _ in
                self?.handleRemoteChange()
            }
            .store(in: &cancellables)
        
        // Respond immediately when the iCloud account status changes (e.g., user signs in/out)
        NotificationCenter.default.publisher(for: Notification.Name.CKAccountChanged)
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.logger.info("🔄 iCloud account status changed – rechecking CloudKit status")
                Task { @MainActor in
                    await self.checkCloudKitStatus()
                }
            }
            .store(in: &cancellables)
        
        // Periodic status check (every 5 minutes)
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.checkCloudKitStatus()
                }
            }
            .store(in: &cancellables)
    }

    private func handleCloudKitEvent(_ event: NSPersistentCloudKitContainer.Event) {
        let emoji: String
        switch event.type {
        case .setup:
            emoji = "⚙️"
            logger.info("\(emoji) CloudKit setup")
        case .import:
            emoji = "⬇️"
            logger.info("\(emoji) Importing from cloud")
            isSyncing = event.endDate == nil
        case .export:
            emoji = "⬆️"
            logger.info("\(emoji) Exporting to cloud")
            isSyncing = event.endDate == nil
        @unknown default:
            emoji = "❓"
            logger.warning("\(emoji) Unknown CloudKit event")
        }

        if let error = event.error {
            logger.error("❌ CloudKit \(String(describing: event.type)) error: \(error.localizedDescription)")
            if (error as NSError).domain == NSURLErrorDomain {
                logger.warning("🌐 Network error - sync will retry when online")
            }
        } else if event.endDate != nil {
            logger.info("✅ CloudKit \(String(describing: event.type)) completed")
            lastSyncDate = event.endDate
            isSyncing = false
        }
    }

    private func handleRemoteChange() {
        logger.info("☁️ Remote changes detected")
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .cloudKitDataRefreshed, object: nil)
        }
    }

    // MARK: - CloudKit Status

    private func checkInitialCloudKitStatus() {
        Task { await checkCloudKitStatus() }
    }

    @MainActor
    func checkCloudKitStatus() async {
        let container = CKContainer(identifier: "iCloud.com.lucas.InkSlateNew")
        do {
            let status = try await container.accountStatus()
            let newStatus = CloudKitStatus.from(accountStatus: status)
            if self.syncStatus != newStatus {
                logger.info("📊 CloudKit status changed: \(newStatus.description)")
                self.syncStatus = newStatus
            }
        } catch {
            logger.error("❌ Failed to check status: \(error.localizedDescription)")
            self.syncStatus = .error
        }
    }

    // MARK: - Core Data Operations

    func save() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        
        do {
            try context.save()
            logger.info("💾 Context saved")
        } catch {
            logger.error("❌ Save failed: \(error.localizedDescription)")
        }
    }

    func backgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }

    // MARK: - Preview

    static var preview: PersistenceController = {
        PersistenceController(inMemory: true)
    }()
}

// MARK: - CloudKitStatus

enum CloudKitStatus: Equatable {
    case available
    case noAccount
    case temporarilyUnavailable
    case restricted
    case couldNotDetermine
    case unknown
    case error

    var description: String {
        switch self {
        case .available: return "✅ Syncing with iCloud"
        case .noAccount: return "⚠️ No iCloud account"
        case .temporarilyUnavailable: return "⏸️ iCloud temporarily unavailable"
        case .restricted: return "🚫 iCloud account restricted"
        case .couldNotDetermine: return "❓ Cannot determine iCloud status"
        case .unknown: return "🔍 Checking iCloud status..."
        case .error: return "❌ iCloud error"
        }
    }

    var isAvailable: Bool { self == .available }
    
    var systemImage: String {
        switch self {
        case .available: return "icloud.fill"
        case .noAccount: return "icloud.slash"
        case .temporarilyUnavailable: return "icloud.and.arrow.down"
        case .restricted: return "exclamationmark.icloud"
        case .couldNotDetermine, .unknown: return "icloud"
        case .error: return "xmark.icloud"
        }
    }

    static func from(accountStatus: CKAccountStatus) -> CloudKitStatus {
        switch accountStatus {
        case .available: return .available
        case .noAccount: return .noAccount
        case .temporarilyUnavailable: return .temporarilyUnavailable
        case .restricted: return .restricted
        case .couldNotDetermine: return .couldNotDetermine
        @unknown default: return .unknown
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let cloudKitDataRefreshed = Notification.Name("cloudKitDataRefreshed")
}
