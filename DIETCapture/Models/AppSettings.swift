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
    @AppStorage("videoFramerate") var videoFramerate: VideoFramerate = .fps60
    
    // MARK: - LiDAR Defaults
    
    @AppStorage("defaultMaxDistance") var defaultMaxDistance: Double = 5.0
    @AppStorage("defaultConfidence") var defaultConfidence: Int = 1 // Medium
    @AppStorage("defaultSmoothing") var defaultSmoothing: Bool = true
    
    enum VideoResolution: String, CaseIterable, Identifiable {
        case high = "Highest Available (Near 4K)"
        case medium = "1080p"
        var id: String { rawValue }
    }
    
    enum VideoFramerate: String, CaseIterable, Identifiable {
        case fps30 = "30 FPS"
        case fps60 = "60 FPS"
        var id: String { rawValue }
    }
}
