import SwiftUI
import UIKit

struct CarPhotoPickerView: View {
    @State private var showingCamera = false
    @State private var image: UIImage?
    var onImagePicked: (UIImage) -> Void

    var body: some View {
        VStack(spacing: 12) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .clipped()
                    .cornerRadius(12)
                    .overlay(alignment: .bottomTrailing) {
                        Text("Retake")
                            .padding(6)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .padding(8)
                    }
                    .onTapGesture { showingCamera = true }
            } else {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take Car Photo", systemImage: "camera")
                }
                .buttonStyle(.bordered)
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker { img in
                showingCamera = false
                guard let img else { return }
                image = img
                onImagePicked(img)
            }
        }
    }
}
struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let vc = UIImagePickerController()
        #if targetEnvironment(simulator)
        vc.sourceType = .photoLibrary
        #else
        vc.sourceType = .camera
        #endif
        vc.allowsEditing = false
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage)
    }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImage: (UIImage?) -> Void

        init(onImage: @escaping (UIImage?) -> Void) {
            self.onImage = onImage
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true) {
                self.onImage(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                self.onImage(nil)
            }
        }
    }
}

