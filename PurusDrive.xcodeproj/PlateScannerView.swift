import SwiftUI
import UIKit

struct PlateScannerView: View {
    @State private var showingCamera = false
    @State private var recognizedPlate: String?
    @State private var rawCandidates: [String] = []
    @State private var isProcessing = false
    var onPlateRecognized: (String) -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button {
                showingCamera = true
            } label: {
                Label("Scan Plate", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.borderedProminent)

            if isProcessing {
                ProgressView("Reading plate…")
            }

            if let plate = recognizedPlate {
                Text("Detected: \(plate)")
                    .font(.headline)
                    .foregroundColor(.green)
                Button("Use This Plate") {
                    onPlateRecognized(plate)
                }
            } else if !rawCandidates.isEmpty {
                Text("No plate-like text found. Candidates:\n\(rawCandidates.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker { image in
                showingCamera = false
                guard let image else { return }
                isProcessing = true
                PlateRecognizer.recognize(from: image) { result in
                    DispatchQueue.main.async {
                        isProcessing = false
                        rawCandidates = result.rawCandidates
                        recognizedPlate = result.bestMatch
                    }
                }
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
        vc.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
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
