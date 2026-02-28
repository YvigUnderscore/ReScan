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
    
    // MARK: - LiDAR Defaults
    
    @AppStorage("defaultMaxDistance") var defaultMaxDistance: Double = 5.0
    @AppStorage("defaultConfidence") var defaultConfidence: Int = 1 // Medium
    @AppStorage("defaultSmoothing") var defaultSmoothing: Bool = true
    
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
