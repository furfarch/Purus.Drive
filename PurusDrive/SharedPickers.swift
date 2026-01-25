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
            // Notify parent that the user cancelled — the SwiftUI parent view controls the presentation state.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.parent.completion(nil) }
            // Do NOT call picker.dismiss here; let SwiftUI control dismissal of the fullScreenCover/sheet.
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            // Deliver the image on the main thread after a short delay and let the SwiftUI parent decide when to dismiss the picker UI.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.parent.completion(image) }
            // Do NOT call picker.dismiss here; SwiftUI will dismiss the presentation when the parent updates its binding.
        }
    }
}
#endif
