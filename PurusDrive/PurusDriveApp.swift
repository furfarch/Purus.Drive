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
            // reset together with the mode: a stale "icloud" here would start "Migrating to Local" after a reinstall/reset
            UserDefaults.standard.set(StorageLocation.local.rawValue, forKey: Self.lastStorageModeKey)
            UserDefaults.standard.removeObject(forKey: CloudKitSyncService.lastSyncKey)
        }

        let schema = Schema([
            Vehicle.self,
            Trailer.self,
            DriveLog.self,
            Checklist.self,
            ChecklistItem.self,
            WorkBlock.self,
            DeletedRecord.self,
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
            // no in-memory fallback: edits would be lost silently and an empty store could sync; show the error instead
            self.container = nil
            self.initErrorMessage = "Could not open the local database. Error: \(error.localizedDescription)"
            CloudKitDiagnostics.containerCreationResult = "Failed"
            CloudKitDiagnostics.containerError = error.localizedDescription
        }
    }

    @ObservedObject private var lock = AppLock.shared

    var body: some Scene {
        WindowGroup {
            if let container {
                ContentView()
                    .modelContainer(container)
                    .modifier(SyncOverlayModifier(enabled: ENABLE_SYNC_OVERLAY, migrationProgress: migrationProgress))
                    // optional Face ID lock: covers the first frame here, later locks use the lock window
                    .overlay { if lock.locked { LockedView().environmentObject(lock) } }
                    .onAppear {
                        if let ws = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first { lock.attach(ws) }
                    }
                    .task {
                        await handleStorageModeTransitionIfNeeded()
                        await syncIfCloudEnabled()
                    }
                    .onChange(of: scenePhase) { oldPhase, newPhase in
                        if newPhase == .background { lock.lock() }
                        if newPhase == .active { lock.appBecameActive() }
                        if newPhase == .active {
                            Task {
                                await handleStorageModeTransitionIfNeeded()
                                await syncIfCloudEnabled()
                            }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RequestFullSyncNotification"))) { _ in
                        guard Self.isICloudMode else { return }
                        migrationProgress.start(title: "Syncing with iCloud…", message: "Starting")
                        Task { @MainActor in
                            await CloudKitSyncService.shared.performFullSync()
                            migrationProgress.succeed(message: "Sync complete")
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

        // to iCloud: the full sync that always follows this call uploads the local data
        guard current != StorageLocation.icloud.rawValue else { return }
        // to Local: take the latest iCloud copy; iCloud data is never deleted (other devices still use it)
        migrationProgress.start(title: "Migrating to Local…", message: "Fetching from iCloud")
        await cloudSyncService.fetchAllFromCloud()
        migrationProgress.succeed(message: "Local only")
    }

    private static var isICloudMode: Bool {
        UserDefaults.standard.string(forKey: storageLocationKey) == StorageLocation.icloud.rawValue
    }

    @MainActor
    private func syncIfCloudEnabled() async {
        guard Self.isICloudMode else { return }

        // the sync service owns the sync report
        migrationProgress.start(title: "Syncing with iCloud…", message: "Running full sync")
        await cloudSyncService.performFullSync()
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
                        migrationProgress.update(message: "Fetched \(count) \(type)")
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncPushedCountNotification"))) { output in
                    if let info = (output.userInfo as? [String: Any]), let type = info["type"] as? String, let count = info["count"] as? Int {
                        migrationProgress.update(message: "Uploaded \(count) \(type)")
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncImportedCountNotification"))) { output in
                    if let info = (output.userInfo as? [String: Any]), let type = info["type"] as? String, let count = info["count"] as? Int {
                        migrationProgress.update(message: "Imported \(count) \(type)")
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncStartedNotification"))) { _ in
                    migrationProgress.start(title: "Syncing with iCloud…", message: "Starting")
                }
                .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SyncCompletedNotification"))) { _ in
                    migrationProgress.succeed(message: "Sync complete")
                }
        } else {
            content
        }
    }
}

