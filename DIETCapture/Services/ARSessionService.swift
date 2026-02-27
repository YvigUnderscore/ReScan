// ARSessionService.swift
// ReScan
//
// ARKit session management: LiDAR depth, confidence, pose tracking, camera frames.

import Foundation
import Observation
import ARKit
import Combine

@Observable
final class ARSessionService: NSObject {
    
    // MARK: - Session
    
    let arSession = ARSession()
    private var configuration: ARWorldTrackingConfiguration?
    
    // MARK: - State
    
    var isRunning = false
    var trackingState: ARCamera.TrackingState = .notAvailable
    var trackingStateString: String = "Not Available"
    var trackingStateColor: String = "red"
    
    // Current Frame Data
    var currentFrame: ARFrame?
    var currentDepthMap: CVPixelBuffer?
    var currentConfidenceMap: CVPixelBuffer?
    var currentSmoothedDepthMap: CVPixelBuffer?
    var currentCameraPose: simd_float4x4 = matrix_identity_float4x4
    var currentIntrinsics: simd_float3x3 = matrix_identity_float3x3
    var depthMapResolution: (width: Int, height: Int) = (256, 192)
    var currentCapturedImage: CVPixelBuffer?
    
    // Mesh
    var meshAnchors: [ARMeshAnchor] = []
    
    // Settings
    var maxDistance: Float = 5.0
    var confidenceThreshold: ConfidenceThreshold = .medium
    var smoothingEnabled: Bool = true
    
    // Callbacks
    var onFrameUpdate: ((ARFrame) -> Void)?
    
    // MARK: - Configuration
    
    func startSession() {
        arSession.delegate = self
        
        let config = ARWorldTrackingConfiguration()
        let settings = AppSettings.shared
        
        // Select resolution — always use 30fps for ARKit (best tracking stability)
        // Actual capture FPS is handled by frame subsampling in CaptureViewModel
        let formats = ARWorldTrackingConfiguration.supportedVideoFormats
        
        guard !formats.isEmpty else {
            print("[ARSessionService] No supported video formats available, cannot start session")
            isRunning = false
            return
        }
        
        var selectedFormat: ARConfiguration.VideoFormat
        
        if settings.videoResolution == .high {
            // Highest resolution at 30fps; formats is non-empty (guaranteed by guard above)
            selectedFormat = formats.filter({ $0.framesPerSecond == 30 })
                .max(by: { ($0.imageResolution.width * $0.imageResolution.height) < ($1.imageResolution.width * $1.imageResolution.height) })
                ?? formats.max(by: { ($0.imageResolution.width * $0.imageResolution.height) < ($1.imageResolution.width * $1.imageResolution.height) })
                ?? formats[0]
        } else {
            // Medium (~1080p) at 30fps
            selectedFormat = formats.filter({ $0.framesPerSecond == 30 })
                .first(where: { $0.imageResolution.height >= 1080 && $0.imageResolution.height < 1440 })
                ?? formats.first(where: { $0.imageResolution.height >= 1080 && $0.imageResolution.height < 1440 })
                ?? formats[0]
        }
        
        config.videoFormat = selectedFormat
        print("[ARSessionService] Selected format: \(selectedFormat.imageResolution) @ \(selectedFormat.framesPerSecond)fps")
        
        // HDR support (iOS 16+)
        if settings.enableHDR {
            if selectedFormat.isVideoHDRSupported {
                config.videoHDRAllowed = true
                print("[ARSessionService] HDR enabled")
            } else {
                print("[ARSessionService] HDR not supported for selected format")
            }
        }
        
        // Scene depth (LiDAR)
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            config.frameSemantics.insert(.sceneDepth)
        }
        
        // Smoothed scene depth
        if smoothingEnabled,
           ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            config.frameSemantics.insert(.smoothedSceneDepth)
        }
        
        // Scene reconstruction (mesh)
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            config.sceneReconstruction = .meshWithClassification
        }
        
        // Environment texturing
        config.environmentTexturing = .automatic
        
        // World alignment
        config.worldAlignment = .gravity
        
        self.configuration = config
        arSession.run(config, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
    }
    
    func stopSession() {
        arSession.pause()
        isRunning = false
    }
    
    func resumeSession() {
        guard let config = configuration else {
            startSession()
            return
        }
        // Resume without resetting tracking to maintain pose continuity
        arSession.run(config, options: [])
        isRunning = true
    }
    
    func updateSettings(maxDistance: Float, confidence: ConfidenceThreshold, smoothing: Bool) {
        self.maxDistance = maxDistance
        self.confidenceThreshold = confidence
        
        if self.smoothingEnabled != smoothing {
            self.smoothingEnabled = smoothing
            if isRunning {
                stopSession()
                startSession()
            }
        }
    }
    
    // MARK: - Camera Device Access (for manual controls)
    
    var captureDevice: AVCaptureDevice? {
        // ARKit uses the wide angle camera
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }
}

// MARK: - ARSessionDelegate

extension ARSessionService: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let newTrackingState = frame.camera.trackingState
        
        DispatchQueue.main.async { [weak self] in
            self?.trackingState = newTrackingState
            self?.updateTrackingStateUI(newTrackingState)
        }
        
        // Update current frame data
        currentFrame = frame
        currentCapturedImage = frame.capturedImage
        
        if let sceneDepth = frame.sceneDepth {
            currentDepthMap = sceneDepth.depthMap
            currentConfidenceMap = sceneDepth.confidenceMap
            
            let w = CVPixelBufferGetWidth(sceneDepth.depthMap)
            let h = CVPixelBufferGetHeight(sceneDepth.depthMap)
            DispatchQueue.main.async { [weak self] in
                self?.depthMapResolution = (w, h)
            }
        }
        
        if let smoothedDepth = frame.smoothedSceneDepth {
            currentSmoothedDepthMap = smoothedDepth.depthMap
        }
        
        currentCameraPose = frame.camera.transform
        currentIntrinsics = frame.camera.intrinsics
        meshAnchors = frame.anchors.compactMap { $0 as? ARMeshAnchor }
        
        onFrameUpdate?(frame)
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        print("[ARSessionService] Session failed: \(error)")
        DispatchQueue.main.async { [weak self] in
            self?.trackingStateString = "Error"
            self?.trackingStateColor = "red"
        }
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        DispatchQueue.main.async { [weak self] in
            self?.trackingStateString = "Interrupted"
            self?.trackingStateColor = "orange"
        }
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Automatically resume the session
        DispatchQueue.main.async { [weak self] in
            self?.trackingStateString = "Resuming..."
            self?.trackingStateColor = "yellow"
            self?.resumeSession()
        }
    }
    
    // MARK: - Helpers
    
    private func updateTrackingStateUI(_ state: ARCamera.TrackingState) {
        switch state {
        case .normal:
            trackingStateString = "Normal ✓"
            trackingStateColor = "green"
        case .notAvailable:
            trackingStateString = "Not Available"
            trackingStateColor = "red"
        case .limited(let reason):
            trackingStateColor = "yellow"
            switch reason {
            case .initializing:
                trackingStateString = "Initializing..."
            case .excessiveMotion:
                trackingStateString = "Too Much Motion"
            case .insufficientFeatures:
                trackingStateString = "Low Features"
            case .relocalizing:
                trackingStateString = "Relocalizing..."
            @unknown default:
                trackingStateString = "Limited"
            }
        }
    }
}
