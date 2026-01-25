import SwiftUI
import UIKit
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        previewLayer.frame = uiView.bounds
    }
}

struct LivePlateScannerView: View {
    @StateObject private var model = CameraScannerModel()
    private var scanner: CameraScanner

    init() {
        let model = CameraScannerModel()
        _model = StateObject(wrappedValue: model)
        self.scanner = CameraScanner(model: model)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            CameraPreviewView(previewLayer: scanner.previewLayer)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                if let best = model.latestResult?.bestMatch {
                    Text(best)
                        .font(.largeTitle).bold()
                        .padding(12)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.top, 40)
                } else {
                    Text("Point camera at plate")
                        .padding(8)
                        .background(.ultraThinMaterial, in: Capsule())
                }

                HStack(spacing: 16) {
                    Button("Start Scan") { scanner.start() }
                        .buttonStyle(.borderedProminent)
                    Button("Stop") { scanner.stop() }
                        .buttonStyle(.bordered)
                }
            }
            .padding(.bottom, 30)
        }
    }
}

#Preview {
    LivePlateScannerView()
}
