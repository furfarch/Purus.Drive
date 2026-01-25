import SwiftUI
import SwiftData

/// Simple add-vehicle flow used by the main (+) button.
/// This was referenced from SectionsView but missing from the target.
struct AddVehicleFlowView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VehicleFormView(vehicle: nil)
                // Intentionally no extra toolbar items here; VehicleFormView provides Cancel.
        }
    }
}
