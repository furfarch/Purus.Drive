import SwiftUI
import PhotosUI

/// Delivers the picked photo already downscaled (JPEG), or nil on cancel/failure.
struct CarPhotoPickerView: View {
    var completion: (Data?) -> Void

    @State private var showingAction = false
    @State private var showingCamera = false

    // Use PhotosPicker directly (this reliably triggers the permission prompt on device)
    @State private var showingLibraryPicker = false
    @State private var libraryItem: PhotosPickerItem? = nil

    var body: some View {
        Button(action: { showingAction = true }) {
            Label("Add Photo", systemImage: "camera")
        }
        .confirmationDialog("Photo", isPresented: $showingAction, titleVisibility: .visible) {
            Button("Take Photo") { showingCamera = true }
            Button("Choose From Library") { showingLibraryPicker = true }
            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(isPresented: $showingLibraryPicker, selection: $libraryItem, matching: .images)
        .onChange(of: libraryItem) { _, newItem in
            guard let item = newItem else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        await MainActor.run { completion(ui.downscaledJPEG()) }
                    } else {
                        await MainActor.run { completion(nil) }
                    }
                } catch {
                    await MainActor.run { completion(nil) }
                }
                await MainActor.run { libraryItem = nil }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPickerUniversal { img in
                showingCamera = false
                completion(img?.downscaledJPEG())
            }
        }
    }
}
