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
            // Use the CameraPickerUniversal implementation from CarPhotoPickerView.swift
            CameraPickerUniversal { image in
                // Keep the sheet open while processing so the user can see progress and results
                print("DEBUG: PlateScanner CameraPickerUniversal completion invoked; image=\(image != nil)")
                guard let image = image else {
                    // user cancelled camera — just close the sheet
                    DispatchQueue.main.async { showingCamera = false }
                    return
                }

                // Start processing on main so UI updates are immediate
                DispatchQueue.main.async {
                    isProcessing = true
                    recognizedPlate = nil
                    rawCandidates = []
                }

                PlateRecognizer.recognize(from: image) { result in
                    DispatchQueue.main.async {
                        print("DEBUG: PlateRecognizer result best=\(result.bestMatch ?? "<nil>") candidates=\(result.rawCandidates)")
                        isProcessing = false
                        rawCandidates = result.rawCandidates

                        if let best = result.bestMatch {
                            // auto-use the best match: call the callback and dismiss
                            onPlateRecognized(best)
                            showingCamera = false
                        } else {
                            // no confident match — present candidate list for manual pick
                            recognizedPlate = nil
                            // keep the sheet open so user can inspect candidates and press a Use button if we provide one
                        }
                    }
                }
            }
        }
    }
}

// CameraPickerUniversal is implemented in CarPhotoPickerView.swift to avoid duplicate declarations.
