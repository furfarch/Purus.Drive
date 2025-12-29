import SwiftUI
import UIKit

struct VehicleFormView: View {
    @State private var plate: String = ""
    @State private var model: String = ""
    @State private var color: String = ""
    @State private var showingPlateCamera = false
    @State private var carPhoto: UIImage? = nil

    var body: some View {
        Form {
            Section(header: Text("Vehicle Details")) {
                TextField("License Plate", text: $plate)
                Button {
                    // Present camera to capture an image for OCR
                    // Reuse the CameraPicker via a sheet
                    showingPlateCamera = true
                } label: {
                    Label("Scan Plate", systemImage: "camera.viewfinder")
                }
                TextField("Model", text: $model)
                TextField("Color", text: $color)
            }
            .sheet(isPresented: $showingPlateCamera) {
                CameraPicker { img in
                    showingPlateCamera = false
                    guard let img else { return }
                    PlateRecognizer.recognize(from: img) { result in
                        DispatchQueue.main.async {
                            if let best = result.bestMatch {
                                self.plate = best
                            }
                        }
                    }
                }
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
