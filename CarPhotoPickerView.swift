import SwiftUI
import PhotosUI

struct CarPhotoPickerView: View {
    var completion: (UIImage?) -> Void
    @State private var showingCamera = false
    @State private var libraryItem: PhotosPickerItem? = nil

    var body: some View {
        Menu {
            Button("Take Photo") { showingCamera = true }
            PhotosPicker(selection: $libraryItem, matching: .images, photoLibrary: .shared()) {
                Label("Choose From Library", systemImage: "photo")
            }
        } label: {
            Label("Add Photo", systemImage: "camera")
        }
        .onChange(of: libraryItem) { item in
            guard let item = item else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { completion(ui) }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { completion(nil) }
                    }
                } catch {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { completion(nil) }
                }
                DispatchQueue.main.async { libraryItem = nil }
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPickerUniversal { img in
                // keep a short delay before calling completion to avoid presentation races
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { completion(img) }
                showingCamera = false
            }
        }
    }
}
