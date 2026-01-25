import SwiftUI
import SwiftData
import UIKit

/// Public trailer creation view used by TrailerPickerInline.
/// Edit flow remains in VehiclesViews.swift via the existing `NewTrailerFormView(existing:)`.
struct CreateTrailerView: View {
    @Environment(\.dismiss) private var dismiss

    var onCreate: (Trailer) -> Void

    @State private var brandModel = ""
    @State private var color = ""
    @State private var plate = ""
    @State private var notes = ""
    @State private var showingPlateScanner = false
    @State private var trailerPhoto: UIImage? = nil

    var body: some View {
        Form {
            Section("Details") {
                TextField("Brand / Model", text: $brandModel)
                TextField("Color", text: $color)

                HStack {
                    TextField("Plate", text: $plate)
                    Button { showingPlateScanner = true } label: { Image(systemName: "camera.viewfinder") }
                        .buttonStyle(.bordered)
                }
                .sheet(isPresented: $showingPlateScanner) {
                    PlateScannerView { recognized in
                        self.plate = recognized
                        showingPlateScanner = false
                    }
                }

                TextField("Notes", text: $notes, axis: .vertical)
            }

            Section(header: Text("Photo")) {
                if let trailerPhoto {
                    Image(uiImage: trailerPhoto)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 160)
                        .clipped()
                        .cornerRadius(12)
                }

                CarPhotoPickerView { img in
                    DispatchQueue.main.async { trailerPhoto = img }
                }
            }
        }
        .navigationTitle("New Trailer")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let t = Trailer(brandModel: brandModel, color: color, plate: plate, notes: notes, lastEdited: .now)
                    if let img = trailerPhoto, let data = img.jpegData(compressionQuality: 0.8) {
                        t.photoData = data
                    }
                    onCreate(t)
                    dismiss()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .accessibilityLabel("Save")
            }
        }
    }
}
