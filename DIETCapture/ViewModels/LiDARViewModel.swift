// LiDARViewModel.swift
// DIETCapture
//
// Observable ViewModel binding LiDAR controls to ARSessionService.

import Foundation
import ARKit

@Observable
final class LiDARViewModel {
    
    // MARK: - Service
    
    let arService = ARSessionService()
    
    // MARK: - Settings
    
    var settings = LiDARSettings()
    
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
    
    func setOverlayMode(_ mode: DepthOverlayMode) {
        settings.overlayMode = mode
    }
    
    func setOverlayOpacity(_ opacity: Float) {
        settings.overlayOpacity = opacity
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
    
    var currentPose: simd_float4x4 {
        arService.currentCameraPose
    }
    
    var currentIntrinsics: simd_float3x3 {
        arService.currentIntrinsics
    }
    
    var meshAnchors: [ARMeshAnchor] {
        arService.meshAnchors
    }
    
    // MARK: - Depth Overlay Image
    
    func generateOverlayBuffer() -> CVPixelBuffer? {
        switch settings.overlayMode {
        case .none:
            return nil
            
        case .depth:
            guard let depth = currentDepthMap else { return nil }
            guard let depthCopy = DepthMapProcessor.copyDepthMap(depth) else { return nil }
            DepthMapProcessor.filterByDistance(depthCopy, maxDistance: settings.maxDistance)
            return DepthMapProcessor.depthToColormapRGBA(
                depthMap: depthCopy,
                minDepth: 0.0,
                maxDepth: settings.maxDistance,
                opacity: settings.overlayOpacity
            )
            
        case .confidence:
            guard let confidence = currentConfidenceMap else { return nil }
            return DepthMapProcessor.confidenceToColormapRGBA(
                confidenceMap: confidence,
                opacity: settings.overlayOpacity
            )
            
        case .mesh:
            // Mesh wireframe overlay requires Metal rendering, skip for now
            return nil
        }
    }
}
