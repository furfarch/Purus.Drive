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

private struct StorageInitErrorView: View {
    let message: String

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Storage Error")
                    .font(.title2)
                    .bold()

                Text("The app couldn’t start its database.")
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
    private static let cloudStoreFileName = "cloud.store"
    private static let appVersionKey = "lastInstalledVersion"

    private let container: ModelContainer?
    private let initErrorMessage: String?

    init() {
        // Detect fresh install by checking app version
        // This works reliably across all platforms including Mac Catalyst
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let lastVersion = UserDefaults.standard.string(forKey: Self.appVersionKey)
        let localStoreURL = URL.applicationSupportDirectory.appending(path: Self.localStoreFileName)
        let localStoreExists = FileManager.default.fileExists(atPath: localStoreURL.path)

        // Fresh install: no previous version AND no local store file
        if lastVersion == nil && !localStoreExists {
            UserDefaults.standard.removeObject(forKey: Self.storageLocationKey)
        }
        UserDefaults.standard.set(currentVersion, forKey: Self.appVersionKey)

        let schema = Schema([
            Vehicle.self,
            Trailer.self,
            DriveLog.self,
            Checklist.self,
            ChecklistItem.self,
        ])

        let storageRaw = UserDefaults.standard.string(forKey: Self.storageLocationKey) ?? StorageLocation.local.rawValue
        let wantsICloud = (storageRaw == StorageLocation.icloud.rawValue)

        // Set diagnostics for in-app display
        CloudKitDiagnostics.storageMode = wantsICloud ? "iCloud" : "Local"

        // Helper to avoid duplicating fallback logic
        func makeLocalContainer() -> ModelContainer? {
            let localConfig = ModelConfiguration(
                schema: schema,
                url: localStoreURL,
                cloudKitDatabase: .none
            )
            if let c = try? ModelContainer(for: schema, configurations: [localConfig]) {
                return c
            }
            let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try? ModelContainer(for: schema, configurations: [inMemoryConfig])
        }

        // Helper to delete CloudKit store files if corrupted
        func deleteCloudStoreIfExists() {
            let cloudStoreURL = URL.applicationSupportDirectory.appending(path: Self.cloudStoreFileName)
            let filesToDelete = [
                cloudStoreURL,
                cloudStoreURL.appendingPathExtension("ckassets"),
                cloudStoreURL.deletingPathExtension().appendingPathExtension("store-shm"),
                cloudStoreURL.deletingPathExtension().appendingPathExtension("store-wal"),
            ]
            for fileURL in filesToDelete {
                try? FileManager.default.removeItem(at: fileURL)
            }
            // Also try to delete the default SwiftData CloudKit store location
            if let defaultStoreURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let defaultCloudStore = defaultStoreURL.appending(path: "default.store")
                try? FileManager.default.removeItem(at: defaultCloudStore)
            }
        }

        if wantsICloud {
            // Try CloudKit with minimal configuration - no custom URL
            var lastError: Error?

            do {
                let cloudConfig = ModelConfiguration(
                    cloudKitDatabase: .private(Self.cloudContainerId)
                )
                let c = try ModelContainer(
                    for: Vehicle.self, Trailer.self, DriveLog.self, Checklist.self, ChecklistItem.self,
                    configurations: cloudConfig
                )
                self.container = c
                self.initErrorMessage = nil
                CloudKitDiagnostics.containerCreationResult = "Success"
                CloudKitDiagnostics.containerError = nil
            } catch {
                lastError = error

                // Try deleting any cached CloudKit data and retry
                deleteCloudStoreIfExists()

                do {
                    let cloudConfig = ModelConfiguration(
                        cloudKitDatabase: .private(Self.cloudContainerId)
                    )
                    let c = try ModelContainer(
                        for: Vehicle.self, Trailer.self, DriveLog.self, Checklist.self, ChecklistItem.self,
                        configurations: cloudConfig
                    )
                    self.container = c
                    self.initErrorMessage = nil
                    CloudKitDiagnostics.containerCreationResult = "Success (retry)"
                    CloudKitDiagnostics.containerError = nil
                } catch let retryError {
                    lastError = retryError

                    // Capture full error details
                    let errorDescription = String(describing: retryError)
                    CloudKitDiagnostics.containerCreationResult = "Failed"
                    CloudKitDiagnostics.containerError = errorDescription

                    if let local = makeLocalContainer() {
                        self.container = local
                        self.initErrorMessage = "iCloud error: \(errorDescription)"
                        CloudKitDiagnostics.storageMode = "Local (fallback)"
                    } else {
                        self.container = nil
                        self.initErrorMessage = "Could not open any storage. Error: \(errorDescription)"
                    }
                }
            }
        } else {
            if let local = makeLocalContainer() {
                self.container = local
                self.initErrorMessage = nil
            } else {
                self.container = nil
                self.initErrorMessage = "Could not open local store or in-memory store."
            }
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
            } else {
                StorageInitErrorView(message: initErrorMessage ?? "Unknown error")
            }
        }
    }
}
