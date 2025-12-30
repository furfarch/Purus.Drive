import Foundation
import AVFoundation
import UIKit

@MainActor
final class CameraScannerModel: ObservableObject {
    @Published var latestResult: PlateRecognitionResult?
}

final class CameraScanner: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    let previewLayer = AVCaptureVideoPreviewLayer()

    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "CameraScanner.VideoQueue")
    private var isProcessing = false

    private let model: CameraScannerModel

    init(model: CameraScannerModel) {
        self.model = model
        super.init()
        setupSession()
    }

    private func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .high

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            print("CameraScanner: cannot create camera input")
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        output.setSampleBufferDelegate(self, queue: queue)
        output.alwaysDiscardsLateVideoFrames = true
        guard session.canAddOutput(output) else {
            print("CameraScanner: cannot add video output")
            session.commitConfiguration()
            return
        }
        session.addOutput(output)

        if let connection = output.connection(with: .video), connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill

        session.commitConfiguration()
    }

    func start() {
        if !session.isRunning {
            session.startRunning()
        }
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isProcessing else { return }
        isProcessing = true

        PlateRecognizer.recognize(from: sampleBuffer) { [weak self] result in
            guard let self = self else { return }
            Task { @MainActor in
                self.model.latestResult = result
                self.isProcessing = false
            }
        }
    }
}
