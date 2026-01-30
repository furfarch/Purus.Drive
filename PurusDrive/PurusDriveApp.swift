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
    private static let freshInstallMarker = "installed.marker"

    private let container: ModelContainer?
    private let initErrorMessage: String?

    init() {
        // Detect fresh install - if marker file doesn't exist, reset storage preference
        let markerURL = URL.applicationSupportDirectory.appending(path: Self.freshInstallMarker)
        if !FileManager.default.fileExists(atPath: markerURL.path) {
            // Fresh install - reset to local storage and create marker
            UserDefaults.standard.removeObject(forKey: Self.storageLocationKey)
            try? FileManager.default.createDirectory(at: URL.applicationSupportDirectory, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: markerURL.path, contents: nil)
        }

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
                url: URL.applicationSupportDirectory.appending(path: Self.localStoreFileName),
                cloudKitDatabase: .none
            )
            if let c = try? ModelContainer(for: schema, configurations: [localConfig]) {
                return c
            }
            let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try? ModelContainer(for: schema, configurations: [inMemoryConfig])
        }

        if wantsICloud {
            // For CloudKit, don't specify a custom URL - let SwiftData manage the store location
            let cloudConfig = ModelConfiguration(
                schema: schema,
                cloudKitDatabase: .private(Self.cloudContainerId)
            )
            do {
                let c = try ModelContainer(for: schema, configurations: [cloudConfig])
                self.container = c
                self.initErrorMessage = nil
                CloudKitDiagnostics.containerCreationResult = "Success"
                CloudKitDiagnostics.containerError = nil
            } catch {
                CloudKitDiagnostics.containerCreationResult = "Failed"
                CloudKitDiagnostics.containerError = error.localizedDescription

                if let local = makeLocalContainer() {
                    self.container = local
                    self.initErrorMessage = "iCloud storage was selected but couldn't be opened. Using local storage instead. Error: \(error.localizedDescription)"
                    CloudKitDiagnostics.storageMode = "Local (fallback)"
                } else {
                    self.container = nil
                    self.initErrorMessage = "Could not open iCloud store, local store, or in-memory store."
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
