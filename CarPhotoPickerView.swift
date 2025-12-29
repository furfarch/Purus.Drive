import SwiftUI
import PhotosUI

struct CarPhotoPickerView: View {
    var completion: (UIImage?) -> Void
    @State private var showingAction = false
    @State private var showingPHPicker = false
    @State private var showingCamera = false

    var body: some View {
        Button(action: { showingAction = true }) {
            Label("Add Photo", systemImage: "camera")
        }
        .confirmationDialog("Photo", isPresented: $showingAction, titleVisibility: .visible) {
            Button("Take Photo") { showingCamera = true }
            Button("Choose From Library") { showingPHPicker = true }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingPHPicker) {
            PhotoPicker(filter: .images) { result in
                showingPHPicker = false
                switch result {
                case .success(let img): completion(img)
                case .failure(_): completion(nil)
                }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPickerUniversal { img in
                showingCamera = false
                completion(img)
            }
        }
    }
}

// MARK: - PhotoPicker wrapper (PHPicker)
struct PhotoPicker: UIViewControllerRepresentable {
    var filter: PHPickerFilter = .images
    var completion: (Result<UIImage, Error>) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: PHPhotoLibrary.shared())
        config.filter = filter
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPicker

        init(_ parent: PhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true, completion: nil)

            guard let item = results.first?.itemProvider, item.canLoadObject(ofClass: UIImage.self) else {
                parent.completion(.failure(NSError(domain: "Picker", code: 1)))
                return
            }

            item.loadObject(ofClass: UIImage.self) { object, error in
                DispatchQueue.main.async {
                    if let err = error { self.parent.completion(.failure(err)); return }
                    if let img = object as? UIImage { self.parent.completion(.success(img)); return }
                    self.parent.completion(.failure(NSError(domain: "Picker", code: 2)))
                }
            }
        }
    }
}

// MARK: - Camera picker wrapper (UIImagePickerController)
struct CameraPickerUniversal: UIViewControllerRepresentable {
    var completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        #if targetEnvironment(simulator)
        // Simulator has no camera; present photo library instead
        picker.sourceType = .photoLibrary
        #else
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.cameraCaptureMode = .photo
        #endif
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPickerUniversal
        init(_ parent: CameraPickerUniversal) { self.parent = parent }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.completion(nil)
            picker.dismiss(animated: true, completion: nil)
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            parent.completion(image)
            picker.dismiss(animated: true, completion: nil)
        }
    }
}
