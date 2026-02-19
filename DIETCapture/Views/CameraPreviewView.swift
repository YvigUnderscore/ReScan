// CameraPreviewView.swift
// DIETCapture
//
// UIViewRepresentable wrapping AVCaptureVideoPreviewLayer for the live camera feed.

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    
    let cameraService: CameraService
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        let previewLayer = cameraService.createPreviewLayer()
        view.previewLayer = previewLayer
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        uiView.previewLayer?.frame = uiView.bounds
    }
}

class CameraPreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}

// MARK: - Depth Overlay Image View

struct DepthOverlayImageView: View {
    let pixelBuffer: CVPixelBuffer?
    
    var body: some View {
        if let buffer = pixelBuffer, let image = imageFromPixelBuffer(buffer) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .allowsHitTesting(false)
        }
    }
    
    private func imageFromPixelBuffer(_ buffer: CVPixelBuffer) -> UIImage? {
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
