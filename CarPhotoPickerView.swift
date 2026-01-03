import SwiftUI
import PhotosUI

struct CarPhotoPickerView: View {
    var completion: (UIImage?) -> Void
    @State private var showingAction = false
    @State private var showingCamera = false

    // Use PhotosPicker directly (this triggers permission prompts correctly on device)
    @State private var showingPicker = false
    @State private var libraryItem: PhotosPickerItem? = nil

    var body: some View {
        Button(action: { showingAction = true }) {
            Label("Add Photo", systemImage: "camera")
        }
        .confirmationDialog("Photo", isPresented: $showingAction, titleVisibility: .visible) {
            Button("Take Photo") { showingCamera = true }
            Button("Choose From Library") { showingPicker = true }
            Button("Cancel", role: .cancel) { }
        }
        .photosPicker(isPresented: $showingPicker, selection: $libraryItem, matching: .images)
        .onChange(of: libraryItem) { _, newItem in
            guard let item = newItem else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self),
                       let ui = UIImage(data: data) {
                        await MainActor.run { completion(ui) }
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
                completion(img)
            }
        }
    }
}
