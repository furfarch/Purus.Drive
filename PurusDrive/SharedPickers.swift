import UIKit
import SwiftUI

extension UIImage {
    /// Photos are stored in SwiftData and synced, so keep them small: max 1600 px on the long side, JPEG 0.8.
    func downscaledJPEG(maxPixels: CGFloat = 1600) -> Data? {
        let pixelW = size.width * scale, pixelH = size.height * scale
        let factor = min(1, maxPixels / max(pixelW, pixelH, 1))
        let target = CGSize(width: (pixelW * factor).rounded(), height: (pixelH * factor).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        // draw(in:) applies imageOrientation, so the result is upright
        let resized = UIGraphicsImageRenderer(size: target, format: format).image { _ in draw(in: CGRect(origin: .zero, size: target)) }
        return resized.jpegData(compressionQuality: 0.8)
    }
}

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
