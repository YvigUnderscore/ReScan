// LiDARViewModel.swift
// ReScan
//
// Observable ViewModel for LiDAR controls and pass viewer.

import Foundation
import ARKit

@Observable
final class LiDARViewModel {
    
    // MARK: - Service
    
    let arService = ARSessionService()
    
    // MARK: - Settings
    
    var settings = LiDARSettings()
    
    // MARK: - View Mode (Pass Viewer)
    
    var viewMode: ViewMode = .rgb
    
    // MARK: - Ghost Mesh
    
    /// When true, shows the translucent ARKit mesh overlay over the RGB feed.
    var ghostMeshEnabled: Bool = false
    
    // MARK: - State
    
    var isRunning: Bool { arService.isRunning }
    var trackingStateString: String { arService.trackingStateString }
    var trackingStateColor: String { arService.trackingStateColor }
    var depthResolution: String {
        "\(arService.depthMapResolution.width)×\(arService.depthMapResolution.height)"
    }
    
    // MARK: - Lifecycle
    
    func start() {
        arService.maxDistance = settings.maxDistance
        arService.confidenceThreshold = settings.confidenceThreshold
        arService.smoothingEnabled = settings.smoothingEnabled
        arService.startSession()
    }
    
    func stop() {
        arService.stopSession()
    }
    
    // MARK: - Settings Updates
    
    func updateMaxDistance(_ distance: Float) {
        settings.maxDistance = distance
        arService.maxDistance = distance
    }
    
    func updateConfidenceThreshold(_ threshold: ConfidenceThreshold) {
        settings.confidenceThreshold = threshold
        arService.confidenceThreshold = threshold
    }
    
    func toggleSmoothing(_ enabled: Bool) {
        settings.smoothingEnabled = enabled
        arService.updateSettings(
            maxDistance: settings.maxDistance,
            confidence: settings.confidenceThreshold,
            smoothing: enabled
        )
    }
    
    // MARK: - Depth Data Access
    
    var currentDepthMap: CVPixelBuffer? {
        if settings.smoothingEnabled {
            return arService.currentSmoothedDepthMap ?? arService.currentDepthMap
        }
        return arService.currentDepthMap
    }
    
    var currentConfidenceMap: CVPixelBuffer? {
        arService.currentConfidenceMap
    }
    
    var currentCapturedImage: CVPixelBuffer? {
        arService.currentCapturedImage
    }
    
    var currentPose: simd_float4x4 {
        arService.currentCameraPose
    }
    
    var currentIntrinsics: simd_float3x3 {
        arService.currentIntrinsics
    }
    
    var meshAnchors: [ARMeshAnchor] {
        arService.meshAnchors
    }
    
    // MARK: - Pass Viewer Buffer
    
    func generateViewBuffer() -> CVPixelBuffer? {
        switch viewMode {
        case .rgb, .mesh:
            return nil  // Use ARKit captured image directly
            
        case .depth:
            guard let depth = currentDepthMap else { return nil }
            guard let depthCopy = DepthMapProcessor.copyDepthMap(depth) else { return nil }
            DepthMapProcessor.filterByDistance(depthCopy, maxDistance: settings.maxDistance)
            let colorMap = AppSettings.shared.depthColorMap.processorColorMap
            return DepthMapProcessor.depthToColormapRGBA(
                depthMap: depthCopy,
                minDepth: 0.0,
                maxDepth: settings.maxDistance,
                opacity: 1.0,
                colorMap: colorMap
            )
            
        case .confidence:
            guard let confidence = currentConfidenceMap else { return nil }
            return DepthMapProcessor.confidenceToColormapRGBA(
                confidenceMap: confidence,
                opacity: 1.0
            )
        }
    }
}
