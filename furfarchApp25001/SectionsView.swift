import SwiftUI

struct SectionsView: View {
    @State private var showingAbout = false
    @State private var showingAddVehicle = false

    var body: some View {
        NavigationStack {
            VehiclesListView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    // Leading: About icon (replaces the previous 3-line title view)
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showingAbout = true } label: {
                            Image(systemName: "info.circle")
                        }
                        .accessibilityLabel("About")
                    }

                    // Trailing: + only
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingAddVehicle = true } label: { Image(systemName: "plus") }
                            .accessibilityLabel("Add Vehicle")
                    }
                }
                .sheet(isPresented: $showingAbout) {
                    NavigationStack { AboutView().navigationTitle("About") }
                }
                .sheet(isPresented: $showingAddVehicle) {
                    NavigationStack { AddVehicleFlowView() }
                }
        }
    }
}

#Preview {
    SectionsView()
}
