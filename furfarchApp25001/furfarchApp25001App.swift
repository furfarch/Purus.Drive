//
//  furfarchApp25001App.swift
//  furfarchApp25001
//
//  Created by Chris Furfari on 27.12.2025.
//

/*
 App Display Name:
 Set in target -> Info (or Info.plist) as CFBundleDisplayName to:
 "Personal Vehicle and Drive / Checklist Log"
*/

import SwiftUI
import SwiftData

@main
struct furfarchApp25001App: App {
    private static let schemaVersionKey = "swiftdata_schema_version"
    private static let currentSchemaVersion = 2

    var sharedModelContainer: ModelContainer = {
        // If we're changing the schema and don't want to migrate, wipe the local store.
        let defaults = UserDefaults.standard
        let previous = defaults.integer(forKey: schemaVersionKey)
        if previous != currentSchemaVersion {
            // Silent wipe (Option A): delete default SwiftData store files.
            let fm = FileManager.default
            if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                // SwiftData typically stores under Application Support/default.store
                // We remove any known store directories that might exist.
                let candidates = ["default.store", "Model.sqlite", "Model.sqlite-shm", "Model.sqlite-wal"]
                for name in candidates {
                    let url = appSupport.appendingPathComponent(name)
                    if fm.fileExists(atPath: url.path) {
                        try? fm.removeItem(at: url)
                    }
                }
                // Also remove any SwiftData/CloudKit subfolders if present.
                let swiftDataDir = appSupport.appendingPathComponent("SwiftData")
                if fm.fileExists(atPath: swiftDataDir.path) {
                    try? fm.removeItem(at: swiftDataDir)
                }
            }
            defaults.set(currentSchemaVersion, forKey: schemaVersionKey)
        }

        // Register all @Model types so SwiftData knows about them
        let schema = Schema([
            Item.self,
            Vehicle.self,
            Trailer.self,
            DriveLog.self,
            Checklist.self,
            ChecklistItem.self,
        ])
        do {
            return try ModelContainer(for: schema)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
