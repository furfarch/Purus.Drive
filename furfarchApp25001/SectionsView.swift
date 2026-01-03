import SwiftUI

struct SectionsView: View {
    @State private var showingAbout = false
    @State private var showingAddVehicle = false

    var body: some View {
        NavigationStack {
            VehiclesListView()
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        HStack(spacing: 12) {
                            // About on the left (as requested)
                            Button { showingAbout = true } label: {
                                Image(systemName: "info.circle")
                            }
                            .accessibilityLabel("About")

                            // Readable title block (left-aligned); remove the word "Vehicles" to free space.
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Image(systemName: "car")
                                    Text(" ")
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: "road.lanes")
                                    Text("Drive Log")
                                }
                                HStack(spacing: 6) {
                                    Image(systemName: "checklist")
                                    Text("Checklists")
                                }
                            }
                            .font(.footnote)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                        }
                    }
                    // + on the right (as requested)
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingAddVehicle = true } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add Vehicle")
                    }
                }
                .sheet(isPresented: $showingAbout) {
                    NavigationStack { AboutView().navigationTitle("About") }
                }
                // Present the same Add Vehicle flow used in VehiclesListView
                .sheet(isPresented: $showingAddVehicle) {
                    NavigationStack { AddVehicleFlowView() }
                }
        }
    }
}

#Preview {
    SectionsView()
}
