// AppSettings.swift
// ReScan
//
// Shared user preferences via AppStorage.

import SwiftUI
import ARKit

final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    // MARK: - Video Settings
    
    @AppStorage("videoResolution") var videoResolution: VideoResolution = .high
    
    /// Capture FPS — frames saved to disk per second (ARKit still runs at native rate for tracking)
    @AppStorage("captureFPS") var captureFPS: CaptureFPS = .fps30
    
    /// Apple Log (ProRes HQ) — only available on iPhone 15 Pro+
    @AppStorage("useAppleLog") var useAppleLog: Bool = false
    
    /// HDR video capture
    @AppStorage("enableHDR") var enableHDR: Bool = true
    
    // MARK: - External Storage
    
    @Published var hasExternalStorage: Bool = false
    
    // MARK: - Mesh Start Mode

    enum MeshStartMode: String, CaseIterable, Identifiable {
        case waitForPolygons = "Wait for First Polygons"
        case bruteForce = "BruteForce (Instant)"
        var id: String { rawValue }
    }

    @AppStorage("meshStartMode") var meshStartMode: MeshStartMode = .waitForPolygons

    // MARK: - LiDAR Defaults
    
    @AppStorage("defaultMaxDistance") var defaultMaxDistance: Double = 5.0
    @AppStorage("defaultConfidence") var defaultConfidence: Int = 1 // Medium
    @AppStorage("defaultSmoothing") var defaultSmoothing: Bool = true
    @AppStorage("depthColorMap") var depthColorMap: DepthColorMap = .jet
    
    // MARK: - Adaptive Mesh Refinement
    
    /// Enable adaptive mesh refinement during capture
    @AppStorage("adaptiveMeshRefinement") var adaptiveMeshRefinement: Bool = false
    
    /// Detail level for adaptive mesh subdivision
    @AppStorage("meshDetailLevel") var meshDetailLevel: MeshDetailLevel = .medium
    
    enum DepthColorMap: String, CaseIterable, Identifiable {
        case jet = "Jet"
        case viridis = "Viridis"
        case turbo = "Turbo"
        var id: String { rawValue }
        
        var processorColorMap: DepthMapProcessor.ColorMap {
            switch self {
            case .jet:    return .jet
            case .viridis: return .viridis
            case .turbo:  return .turbo
            }
        }
    }
    
    enum VideoResolution: String, CaseIterable, Identifiable {
        case high = "3840 × 2160 (4K)"
        case medium = "1920 × 1080 (1080p)"
        var id: String { rawValue }
    }
    
    enum CaptureFPS: Int, CaseIterable, Identifiable {
        case fps60 = 60
        case fps30 = 30
        case fps15 = 15
        case fps10 = 10
        case fps5 = 5
        case fps2 = 2
        case fps1 = 1
        
        var id: Int { rawValue }
        
        var label: String { "\(rawValue) FPS" }
        
        /// Minimum interval in seconds between captured frames
        var captureInterval: TimeInterval {
            return 1.0 / Double(rawValue)
        }
    }
}
