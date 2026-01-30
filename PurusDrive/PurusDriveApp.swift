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

    private let container: ModelContainer?
    private let initErrorMessage: String?
    private let cloudSyncService = CloudKitSyncService.shared

    @Environment(\.scenePhase) private var scenePhase

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

        // Re-read after potential reset
        let finalStorageRaw = UserDefaults.standard.string(forKey: Self.storageLocationKey) ?? StorageLocation.local.rawValue
        let wantsICloud = (finalStorageRaw == StorageLocation.icloud.rawValue)

        // Set diagnostics for in-app display
        CloudKitDiagnostics.storageMode = wantsICloud ? "iCloud" : "Local"

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
                    .task {
                        // Sync on app launch if iCloud is enabled
                        await syncIfCloudEnabled()
                    }
                    .onChange(of: scenePhase) { oldPhase, newPhase in
                        if newPhase == .active {
                            // Sync when app becomes active
                            Task {
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
    private func syncIfCloudEnabled() async {
        let storageRaw = UserDefaults.standard.string(forKey: Self.storageLocationKey) ?? StorageLocation.local.rawValue
        let wantsICloud = (storageRaw == StorageLocation.icloud.rawValue)

        if wantsICloud {
            await cloudSyncService.performFullSync()
        }
    }
}
