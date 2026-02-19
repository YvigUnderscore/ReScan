// CameraPreviewView.swift
// ReScan
//
// Deprecated: Preview is now rendered from ARKit frames in ViewfinderView.
// This file is kept for compatibility but no longer used.

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let pixelBuffer: CVPixelBuffer?
    
    func makeUIView(context: Context) -> UIImageView {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        guard let buffer = pixelBuffer else { return }
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let context = CIContext()
        if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
            uiView.image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
        }
    }
}
