//
//  ContentView.swift
//  SimplyDrive
//
//  Created by Chris Furfari on 27.12.2025.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    // The Xcode template's unused @Query for Item was removed: Item is not in the app's schema,
    // and that query crashed the app on the first save that touched checklist items.
    var body: some View {
        SectionsView()
    }
}

#Preview {
    // same schema as the app; .none because the CloudKit entitlement would otherwise turn on auto-sync and reject the schema
    let schema = Schema([Vehicle.self, Trailer.self, DriveLog.self, Checklist.self, ChecklistItem.self, DeletedRecord.self])
    let container = try! ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)])
    return ContentView().modelContainer(container)
}
