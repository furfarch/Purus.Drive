//
//  PurusDriveApp.swift
//  Purus Drive
//
//  Created by Chris Furfari on 27.12.2025.
//

/*
 App Display Name:
 Set in target -> Info (or Info.plist) as CFBundleDisplayName to:
 "Purus Drive"
*/

import SwiftUI
import SwiftData
import CloudKit
import Combine

#if DEBUG
let ENABLE_SYNC_OVERLAY = true
#else
let ENABLE_SYNC_OVERLAY = false
#endif

private struct StorageInitErrorView: View {
    let message: String

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Storage Error")
                    .font(.title2)
                    .bold()

                Text("The app couldn't start its database.")
                    .foregroundStyle(.secondary)

                Text(message)
                    .font(.footnote)
                    .textSelection(.enabled)
                    .foregroundStyle(.secondary)

                Text("You can usually fix this by using Settings → Reset Local Database, or by deleting the app from the simulator/device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
        }
    }
}

@main
struct PurusDriveApp: App {
    private static let storageLocationKey = "storageLocation"
    private static let cloudContainerId = "iCloud.com.purus.driver"
    private static let localStoreFileName = "default.store"
    private static let migrationNeededKey = "needsStorageMigration"
    private static let lastStorageModeKey = "lastStorageMode"

    private let container: ModelContainer?
    private let initErrorMessage: String?
    private let cloudSyncService = CloudKitSyncService.shared

    @Environment(\.scenePhase) private var scenePhase
    
    @StateObject private var migrationProgress = MigrationProgress()

    init() {
        // Check if local store exists
        let localStoreURL = URL.applicationSupportDirectory.appending(path: Self.localStoreFileName)
        let localStoreExists = FileManager.default.fileExists(atPath: localStoreURL.path)

        // Fresh install detection: If no local store exists, always reset to local storage
        // This handles iOS-on-Mac where UserDefaults persist after app deletion
        if !localStoreExists {
            UserDefaults.standard.removeObject(forKey: Self.storageLocationKey)
        }

        let schema = Schema([
            Vehicle.self,
            Trailer.self,
            DriveLog.self,
            Checklist.self,
            ChecklistItem.self,
        ])

        // Resolve storage preference: default to Local on true fresh install, otherwise respect saved preference
        let savedRaw = UserDefaults.standard.string(forKey: Self.storageLocationKey)
        let finalStorageRaw: String
        if !localStoreExists {
            // True fresh install (no local store) — default to Local and clear any stale preference
            UserDefaults.standard.set(StorageLocation.local.rawValue, forKey: Self.storageLocationKey)
            finalStorageRaw = StorageLocation.local.rawValue
        } else if let savedRaw {
            finalStorageRaw = savedRaw
        } else {
            finalStorageRaw = StorageLocation.local.rawValue
        }
        let wantsICloud = (finalStorageRaw == StorageLocation.icloud.rawValue)

        // Set diagnostics for in-app display
        CloudKitDiagnostics.storageMode = wantsICloud ? "iCloud" : "Local"
        if UserDefaults.standard.string(forKey: Self.lastStorageModeKey) == nil {
            UserDefaults.standard.set(finalStorageRaw, forKey: Self.lastStorageModeKey)
        }

        // Always use local storage - CloudKit sync is handled manually
        let localConfig = ModelConfiguration(
            schema: schema,
            url: localStoreURL,
            cloudKitDatabase: .none
        )

        do {
            let c = try ModelContainer(for: schema, configurations: [localConfig])
            self.container = c
            self.initErrorMessage = nil
            CloudKitDiagnostics.containerCreationResult = "Success"
            CloudKitDiagnostics.containerError = nil

            // Set up the sync service with the model context
            cloudSyncService.setModelContext(c.mainContext)
        } catch {
            // Fallback to in-memory
            let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            if let c = try? ModelContainer(for: schema, configurations: [inMemoryConfig]) {
                self.container = c
                self.initErrorMessage = "Local storage failed, using in-memory storage."
                cloudSyncService.setModelContext(c.mainContext)
            } else {
                self.container = nil
                self.initErrorMessage = "Could not open any storage. Error: \(error.localizedDescription)"
            }
            CloudKitDiagnostics.containerCreationResult = "Failed"
            CloudKitDiagnostics.containerError = error.localizedDescription
        }

        if let container {
            ChecklistOwnershipMigration.runIfNeeded(using: container)
        }
    }

    var body: some Scene {
        WindowGroup {
            if let container {
                ContentView()
                    .modelContainer(container)
                    .modifier(SyncOverlayModifier(enabled: ENABLE_SYNC_OVERLAY, migrationProgress: migrationProgress))
                    .task {
                        await handleStorageModeTransitionIfNeeded()
                        await syncIfCloudEnabled()
                    }
                    .onChange(of: scenePhase) { oldPhase, newPhase in
                        if newPhase == .active {
                            Task {
                                await handleStorageModeTransitionIfNeeded()
                                await syncIfCloudEnabled()
                            }
                        }
                    }
            } else {
                StorageInitErrorView(message: initErrorMessage ?? "Unknown error")
            }
        }
    }

    @MainActor
    private func handleStorageModeTransitionIfNeeded() async {
        let current = UserDefaults.standard.string(forKey: Self.storageLocationKey) ?? StorageLocation.local.rawValue
        let last = UserDefaults.standard.string(forKey: Self.lastStorageModeKey) ?? StorageLocation.local.rawValue

        guard current != last else { return }
        UserDefaults.standard.set(current, forKey: Self.lastStorageModeKey)

        if current == StorageLocation.icloud.rawValue {
            migrationProgress.start(title: "Migrating to iCloud…", message: "Uploading local data")
            await cloudSyncService.pushAllToCloud()
            migrationProgress.update(message: "Syncing with iCloud")
            await cloudSyncService.performFullSync()
            migrationProgress.succeed(message: "Now syncing across devices")
        } else {
            migrationProgress.start(title: "Migrating to Local…", message: "Fetching from iCloud")
            await cloudSyncService.fetchAllFromCloud()
            migrationProgress.update(message: "Removing data from iCloud")
            await cloudSyncService.deleteAllFromCloud()
            migrationProgress.succeed(message: "iCloud cleared; local only")
        }
    }

    @MainActor
    private func syncIfCloudEnabled() async {
        let storageRaw = UserDefaults.standard.string(forKey: Self.storageLocationKey) ?? StorageLocation.local.rawValue
        let wantsICloud = (storageRaw == StorageLocation.icloud.rawValue)
        guard wantsICloud else { return }

        migrationProgress.start(title: "Syncing with iCloud…", message: "Starting")
        var report = SyncReport(startedAt: Date(), finishedAt: nil, mode: "iCloud")
        SyncReportStore.shared.lastReport = report

        let migrationFlagKey = "didInitialCloudMigration"
        if UserDefaults.standard.bool(forKey: migrationFlagKey) == false {
            migrationProgress.update(message: "Uploading local data (first-time)")
            await cloudSyncService.pushAllToCloud()
            UserDefaults.standard.set(true, forKey: migrationFlagKey)
        }

        migrationProgress.update(message: "Running full sync")
        await cloudSyncService.performFullSync()

        report.finishedAt = Date()
        SyncReportStore.shared.lastReport = report
        migrationProgress.succeed(message: "Sync complete")
    }
}

private struct SyncOverlayModifier: ViewModifier {
    let enabled: Bool
    @ObservedObject var migrationProgress: MigrationProgress
    func body(content: Content) -> some View {
        if enabled {
            content
                .environmentObject(migrationProgress)
                .overlay(alignment: .top) {
                    MigrationOverlayView()
                        .environmentObject(migrationProgress)
                        .padding(.top, 8)
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncFetchedCountNotification"))) { output in
                    if let info = (output.userInfo as? [String: Any]), let type = info["type"] as? String, let count = info["count"] as? Int {
                        if let last = SyncReportStore.shared.lastReport {
                            var updated = last
                            updated.fetched[type, default: 0] += count
                            SyncReportStore.shared.lastReport = updated
                            migrationProgress.update(message: "Fetched \(count) \(type)")
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncPushedCountNotification"))) { output in
                    if let info = (output.userInfo as? [String: Any]), let type = info["type"] as? String, let count = info["count"] as? Int {
                        if let last = SyncReportStore.shared.lastReport {
                            var updated = last
                            updated.pushed[type, default: 0] += count
                            SyncReportStore.shared.lastReport = updated
                            migrationProgress.update(message: "Uploaded \(count) \(type)")
                        }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncImportedCountNotification"))) { output in
                    if let info = (output.userInfo as? [String: Any]), let type = info["type"] as? String, let count = info["count"] as? Int {
                        migrationProgress.update(message: "Imported \(count) \(type)")
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncStartedNotification"))) { _ in
                    migrationProgress.start(title: "Syncing with iCloud…", message: "Starting")
                    SyncReportStore.shared.lastReport = SyncReport(startedAt: Date(), finishedAt: nil, mode: "iCloud")
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncCompletedNotification"))) { _ in
                    if var report = SyncReportStore.shared.lastReport {
                        report.finishedAt = Date()
                        SyncReportStore.shared.lastReport = report
                    }
                    migrationProgress.succeed(message: "Sync complete")
                }
        } else {
            content
        }
    }
}

