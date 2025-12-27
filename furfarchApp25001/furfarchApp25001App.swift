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
