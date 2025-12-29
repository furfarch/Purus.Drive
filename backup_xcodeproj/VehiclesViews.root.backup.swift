import SwiftUI
import UIKit

struct VehicleFormView: View {
    @State private var plate: String = ""
    @State private var model: String = ""
    @State private var color: String = ""
    @State private var carPhoto: UIImage?

    var body: some View {
        Form {
            Section(header: Text("Vehicle Details")) {
                TextField("License Plate", text: $plate)
                PlateScannerView { recognized in
                    // Prefill the plate field with recognized text
                    self.plate = recognized
                }
                TextField("Model", text: $model)
                TextField("Color", text: $color)
            }
            Section(header: Text("Car Photo")) {
                if let carPhoto {
                    Image(uiImage: carPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .clipped()
                        .cornerRadius(12)
                }
                CarPhotoPickerView { img in
                    self.carPhoto = img
                    // TODO: Persist this image with your vehicle model if desired
                }
            }
        }
        .navigationTitle("Add/Edit Vehicle")
    }
}
