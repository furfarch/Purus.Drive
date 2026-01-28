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

    private let container: ModelContainer?
    private let initErrorMessage: String?

    init() {
        let schema = Schema([
            Item.self,
            Vehicle.self,
            Trailer.self,
            DriveLog.self,
            Checklist.self,
            ChecklistItem.self,
        ])

        let storageRaw = UserDefaults.standard.string(forKey: Self.storageLocationKey) ?? StorageLocation.local.rawValue
        let wantsICloud = (storageRaw == StorageLocation.icloud.rawValue)

        print("🔧 [INIT] Storage preference: \(storageRaw), wantsICloud: \(wantsICloud)")
        print("🔧 [INIT] CloudKit container ID: \(Self.cloudContainerId)")

        // Set diagnostics for in-app display
        CloudKitDiagnostics.storageMode = wantsICloud ? "iCloud" : "Local"

        // Helper to avoid duplicating fallback logic
        func makeLocalContainer() -> ModelContainer? {
            // Explicitly set URL for local storage in application support directory
            let localConfig = ModelConfiguration(
                schema: schema,
                url: URL.applicationSupportDirectory.appending(path: Self.localStoreFileName),
                cloudKitDatabase: .none
            )
            do {
                let c = try ModelContainer(for: schema, configurations: [localConfig])
                print("✅ [INIT] Local container created successfully")
                return c
            } catch {
                print("❌ [INIT] Local container failed: \(error)")
            }

            do {
                let inMemoryConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                let c = try ModelContainer(for: schema, configurations: [inMemoryConfig])
                print("⚠️ [INIT] Using in-memory container as fallback")
                return c
            } catch {
                print("❌ [INIT] In-memory container failed: \(error)")
                return nil
            }
        }

        if wantsICloud {
            let cloudConfig = ModelConfiguration(
                schema: schema,
                url: URL.applicationSupportDirectory.appending(path: Self.cloudStoreFileName),
                cloudKitDatabase: .private(Self.cloudContainerId)
            )

            do {
                let c = try ModelContainer(for: schema, configurations: [cloudConfig])
                self.container = c
                self.initErrorMessage = nil
                CloudKitDiagnostics.containerCreationResult = "Success"
                CloudKitDiagnostics.containerError = nil
                print("✅ [INIT] CloudKit container created successfully")
                print("🔧 [INIT] Store URL: \(URL.applicationSupportDirectory.appending(path: Self.cloudStoreFileName))")

                // Check CloudKit account status
                CKContainer(identifier: Self.cloudContainerId).accountStatus { status, error in
                    if let error = error {
                        print("❌ [CloudKit] Account status error: \(error)")
                    } else {
                        switch status {
                        case .available:
                            print("✅ [CloudKit] Account status: Available")
                        case .noAccount:
                            print("❌ [CloudKit] Account status: No iCloud account signed in")
                        case .restricted:
                            print("❌ [CloudKit] Account status: Restricted")
                        case .couldNotDetermine:
                            print("❌ [CloudKit] Account status: Could not determine")
                        case .temporarilyUnavailable:
                            print("⚠️ [CloudKit] Account status: Temporarily unavailable")
                        @unknown default:
                            print("❌ [CloudKit] Account status: Unknown")
                        }
                    }
                }
            } catch {
                print("❌ [INIT] CloudKit container FAILED: \(error)")
                print("❌ [INIT] Error details: \(String(describing: error))")
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
            print("🔧 [INIT] Using local storage (user preference)")
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
