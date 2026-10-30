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
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
