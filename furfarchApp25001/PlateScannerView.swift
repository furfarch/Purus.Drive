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

// CameraPickerUniversal is implemented in CarPhotoPickerView.swift to avoid duplicate declarations.
