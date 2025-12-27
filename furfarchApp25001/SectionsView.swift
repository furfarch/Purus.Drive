import SwiftUI

struct SectionsView: View {
    @State private var showingAbout = false

    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    VehiclesListView()
                } label: {
                    Label("Vehicles", systemImage: "car")
                }
                NavigationLink {
                    DriveLogListView()
                } label: {
                    Label("Drive Log", systemImage: "road.lanes")
                }
                NavigationLink {
                    ChecklistListView()
                } label: {
                    Label("Checklist", systemImage: "checklist")
                }
            }
            .navigationTitle("Sections")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAbout = true } label: { Label("About", systemImage: "info.circle") }
                }
            }
            .sheet(isPresented: $showingAbout) {
                NavigationStack { AboutView().navigationTitle("About") }
            }
        }
    }
}

#Preview {
    SectionsView()
}
