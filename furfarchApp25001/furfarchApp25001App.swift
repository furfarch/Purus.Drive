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
    var sharedModelContainer: ModelContainer = {
        // Register all @Model types so SwiftData knows about them
        let schema = Schema([
            Item.self,
            Vehicle.self,
            Trailer.self,
            DriveLog.self,
            Checklist.self,
            ChecklistItem.self,
        ])

        // Prefer CloudKit sync, but fall back to local-only store if CloudKit init fails.
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.furfarch.MyDriverLog")
        )

        do {
            return try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            // CloudKit-backed stores can fail to initialize (e.g. iCloud not available, container mismatch).
            // Falling back keeps the app usable instead of crashing at launch.
            print("WARNING: CloudKit ModelContainer init failed. Falling back to local store. Error: \(error)")

            let localConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )

            do {
                return try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    init() {
        ChecklistOwnershipMigration.runIfNeeded(using: sharedModelContainer)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
