import SwiftUI
import PhotosUI

struct CarPhotoPickerView: View {
    var completion: (UIImage?) -> Void
    @State private var showingAction = false
    @State private var showingCamera = false
    @State private var showingLibrary = false
    @State private var libraryItem: PhotosPickerItem? = nil

    var body: some View {
        Button(action: { showingAction = true }) {
            Label("Add Photo", systemImage: "camera")
        }
        .confirmationDialog("Photo", isPresented: $showingAction, titleVisibility: .visible) {
            Button("Take Photo") { showingCamera = true }
            Button("Choose From Library") { showingLibrary = true }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingLibrary) {
            LibraryPickerView(selection: $libraryItem) {
                // user tapped done/cancel; load item if present
                if let item = libraryItem {
                    Task {
                        do {
                            if let data = try await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { completion(ui) }
                            } else {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { completion(nil) }
                            }
                        } catch {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { completion(nil) }
                        }
                        // clear selection to avoid retaining the item
                        DispatchQueue.main.async { libraryItem = nil }
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { completion(nil) }
                }
                showingLibrary = false
            }
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraPickerUniversal { img in
                showingCamera = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { completion(img) }
            }
        }
        .onChange(of: libraryItem) { oldItem, newItem in
            guard let item = newItem else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self), let ui = UIImage(data: data) {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { completion(ui) }
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { completion(nil) }
                    }
                } catch {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { completion(nil) }
                }
                // clear selection to avoid retaining the item
                DispatchQueue.main.async { libraryItem = nil }
            }
        }
    }
}

// Small wrapper view hosting a PhotosPicker
struct LibraryPickerView: View {
    @Binding var selection: PhotosPickerItem?
    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                PhotosPicker(selection: $selection, matching: .images, photoLibrary: .shared()) {
                    Label("Select Photo", systemImage: "photo")
                        .padding()
                }
                Spacer()
            }
            .navigationTitle("Choose Photo")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onDone() }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { selection = nil; onDone() }
                }
            }
        }
    }
}
