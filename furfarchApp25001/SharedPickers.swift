import UIKit
import SwiftUI

#if canImport(UIKit)
/// Shared camera picker used across the app (handles simulator fallback).
struct CameraPickerUniversal: UIViewControllerRepresentable {
    var completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        #if targetEnvironment(simulator)
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
            DispatchQueue.main.async { self.parent.completion(nil) }
            picker.dismiss(animated: true)
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            DispatchQueue.main.async { self.parent.completion(image) }
            picker.dismiss(animated: true)
        }
    }
}
#endif
