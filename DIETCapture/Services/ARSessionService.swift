// ARSessionService.swift
// DIETCapture
//
// ARKit session management: LiDAR depth, confidence, pose tracking, mesh reconstruction.

import Foundation
import ARKit
import Combine

@Observable
final class ARSessionService: NSObject {
    
    // MARK: - Session
    
    let arSession = ARSession()
    
    // MARK: - State
    
    var isRunning = false
    var trackingState: ARCamera.TrackingState = .notAvailable
    var trackingStateString: String = "Not Available"
    var trackingStateColor: String = "red"
    
    // Current Frame Data
    var currentDepthMap: CVPixelBuffer?
    var currentConfidenceMap: CVPixelBuffer?
    var currentSmoothedDepthMap: CVPixelBuffer?
    var currentCameraPose: simd_float4x4 = matrix_identity_float4x4
    var currentIntrinsics: simd_float3x3 = matrix_identity_float3x3
    var depthMapResolution: (width: Int, height: Int) = (256, 192)
    
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
        
        let configuration = ARWorldTrackingConfiguration()
        
        // Scene depth (LiDAR)
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics.insert(.sceneDepth)
        }
        
        // Smoothed scene depth
        if smoothingEnabled,
           ARWorldTrackingConfiguration.supportsFrameSemantics(.smoothedSceneDepth) {
            configuration.frameSemantics.insert(.smoothedSceneDepth)
        }
        
        // Scene reconstruction (mesh)
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(.meshWithClassification) {
            configuration.sceneReconstruction = .meshWithClassification
        }
        
        // Environment texturing
        configuration.environmentTexturing = .automatic
        
        // High resolution frame capturing
        if let hiResFormat = ARWorldTrackingConfiguration
            .recommendedVideoFormatForHighResolutionFrameCapturing {
            configuration.videoFormat = hiResFormat
        }
        
        // World alignment
        configuration.worldAlignment = .gravity
        
        arSession.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        isRunning = true
    }
    
    func stopSession() {
        arSession.pause()
        isRunning = false
    }
    
    func updateSettings(maxDistance: Float, confidence: ConfidenceThreshold, smoothing: Bool) {
        self.maxDistance = maxDistance
        self.confidenceThreshold = confidence
        
        // Re-run if smoothing changed
        if self.smoothingEnabled != smoothing {
            self.smoothingEnabled = smoothing
            if isRunning {
                stopSession()
                startSession()
            }
        }
    }
    
    // MARK: - Depth Processing
    
    func processDepthMap(_ depthMap: CVPixelBuffer, maxDistance: Float) -> CVPixelBuffer {
        CVPixelBufferLockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: 0)) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return depthMap }
        let pointer = baseAddress.assumingMemoryBound(to: Float32.self)
        
        for i in 0..<(width * height) {
            if pointer[i] > maxDistance || pointer[i].isNaN {
                pointer[i] = 0.0
            }
        }
        
        return depthMap
    }
    
    func filterByConfidence(
        depthMap: CVPixelBuffer,
        confidenceMap: CVPixelBuffer,
        threshold: ConfidenceThreshold
    ) -> CVPixelBuffer {
        CVPixelBufferLockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: 0))
        CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: 0))
            CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly)
        }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        guard let depthBase = CVPixelBufferGetBaseAddress(depthMap),
              let confBase = CVPixelBufferGetBaseAddress(confidenceMap) else {
            return depthMap
        }
        
        let depthPointer = depthBase.assumingMemoryBound(to: Float32.self)
        let confPointer = confBase.assumingMemoryBound(to: UInt8.self)
        
        for i in 0..<(width * height) {
            if confPointer[i] < UInt8(threshold.rawValue) {
                depthPointer[i] = 0.0
            }
        }
        
        return depthMap
    }
    
    // MARK: - Point Cloud Generation
    
    func generatePointCloud(
        depthMap: CVPixelBuffer,
        confidenceMap: CVPixelBuffer?,
        intrinsics: simd_float3x3,
        cameraPose: simd_float4x4,
        maxDistance: Float,
        confidenceThreshold: ConfidenceThreshold
    ) -> [(position: simd_float3, color: simd_float3)] {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        guard let depthBase = CVPixelBufferGetBaseAddress(depthMap) else { return [] }
        let depthPointer = depthBase.assumingMemoryBound(to: Float32.self)
        
        var confPointer: UnsafeMutablePointer<UInt8>?
        if let confMap = confidenceMap {
            CVPixelBufferLockBaseAddress(confMap, .readOnly)
            if let confBase = CVPixelBufferGetBaseAddress(confMap) {
                confPointer = confBase.assumingMemoryBound(to: UInt8.self)
            }
        }
        
        let fx = intrinsics.columns.0.x
        let fy = intrinsics.columns.1.y
        let cx = intrinsics.columns.2.x
        let cy = intrinsics.columns.2.y
        
        var points: [(position: simd_float3, color: simd_float3)] = []
        points.reserveCapacity(width * height / 4)
        
        for y in stride(from: 0, to: height, by: 2) {  // Downsample 2x for performance
            for x in stride(from: 0, to: width, by: 2) {
                let index = y * width + x
                let depth = depthPointer[index]
                
                // Filter by distance
                guard depth > 0 && depth <= maxDistance else { continue }
                
                // Filter by confidence
                if let conf = confPointer, conf[index] < UInt8(confidenceThreshold.rawValue) {
                    continue
                }
                
                // Unproject to 3D (camera space)
                let xCam = (Float(x) - cx) * depth / fx
                let yCam = (Float(y) - cy) * depth / fy
                let zCam = depth
                let pointCamera = simd_float4(xCam, yCam, zCam, 1.0)
                
                // Transform to world space
                let pointWorld = cameraPose * pointCamera
                
                // Default gray color (RGB overlay would replace this)
                let color = simd_float3(0.7, 0.7, 0.7)
                
                points.append((
                    position: simd_float3(pointWorld.x, pointWorld.y, pointWorld.z),
                    color: color
                ))
            }
        }
        
        if let confMap = confidenceMap {
            CVPixelBufferUnlockBaseAddress(confMap, .readOnly)
        }
        
        return points
    }
    
    // MARK: - Mesh Export
    
    func collectMeshAnchors() -> [ARMeshAnchor] {
        return arSession.currentFrame?.anchors.compactMap { $0 as? ARMeshAnchor } ?? []
    }
    
    // MARK: - Camera Data
    
    func extractCameraData(from frame: ARFrame) -> (pose: simd_float4x4, intrinsics: simd_float3x3) {
        return (frame.camera.transform, frame.camera.intrinsics)
    }
}

// MARK: - ARSessionDelegate

extension ARSessionService: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Update tracking state
        let newTrackingState = frame.camera.trackingState
        DispatchQueue.main.async { [weak self] in
            self?.trackingState = newTrackingState
            self?.updateTrackingStateUI(newTrackingState)
        }
        
        // Update depth data
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
        
        // Update camera data
        currentCameraPose = frame.camera.transform
        currentIntrinsics = frame.camera.intrinsics
        
        // Update mesh anchors
        meshAnchors = frame.anchors.compactMap { $0 as? ARMeshAnchor }
        
        // Callback
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
        DispatchQueue.main.async { [weak self] in
            self?.trackingStateString = "Resuming..."
            self?.trackingStateColor = "yellow"
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
