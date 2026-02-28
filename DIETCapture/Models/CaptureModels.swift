// CaptureModels.swift
// ReScan
//
// Core data models, enums, and settings structs.

import Foundation
import AVFoundation
import ARKit
import CoreMedia

// MARK: - Exposure

enum ExposureMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case manual = "Manual"
    case locked = "Locked"
    
    var id: String { rawValue }
    
    var avMode: AVCaptureDevice.ExposureMode {
        switch self {
        case .auto: return .continuousAutoExposure
        case .manual: return .custom
        case .locked: return .locked
        }
    }
}

// MARK: - Focus

enum FocusMode: String, CaseIterable, Identifiable {
    case auto = "AF"
    case autoContinuous = "AF-C"
    case manual = "MF"
    
    var id: String { rawValue }
    
    var avMode: AVCaptureDevice.FocusMode {
        switch self {
        case .auto: return .autoFocus
        case .autoContinuous: return .continuousAutoFocus
        case .manual: return .locked
        }
    }
}

// MARK: - White Balance

enum WhiteBalanceMode: String, CaseIterable, Identifiable {
    case auto = "Auto"
    case manual = "Manual"
    
    var id: String { rawValue }
}

struct WhiteBalanceValues {
    var temperature: Float = 5500.0
    var tint: Float = 0.0
    
    static let temperatureRange: ClosedRange<Float> = 2000...10000
    static let tintRange: ClosedRange<Float> = -150...150
}

// MARK: - Confidence

enum ConfidenceThreshold: Int, CaseIterable, Identifiable {
    case low = 0
    case medium = 1
    case high = 2
    
    var id: Int { rawValue }
    
    var label: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Med"
        case .high: return "High"
        }
    }
}

// MARK: - View Mode (Pass Viewer)

enum ViewMode: String, CaseIterable, Identifiable {
    case rgb = "RGB"
    case depth = "Depth"
    case confidence = "Conf"
    case mesh = "Mesh"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .rgb: return "camera.fill"
        case .depth: return "cube.fill"
        case .confidence: return "checkmark.shield.fill"
        case .mesh: return "move.3d"
        }
    }
}

// MARK: - Video Encoding Mode

enum VideoEncodingMode: String, CaseIterable, Identifiable {
    case appleLog = "Apple Log (ProRes)"
    case hdrHEVC = "HDR HEVC"
    case standardHEVC = "HEVC"
    case exrSequence = "EXR Sequence (Linear)"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .appleLog: return "mov"
        case .hdrHEVC, .standardHEVC: return "mp4"
        case .exrSequence: return "exr"
        }
    }
    
    var label: String { rawValue }
}

// MARK: - Lens Selection

enum LensType: String, CaseIterable, Identifiable {
    case ultraWide = "0.5x"
    case wide = "1x"
    case telephoto3x = "3x"
    case telephoto5x = "5x"
    
    var id: String { rawValue }
    
    var deviceType: AVCaptureDevice.DeviceType {
        switch self {
        case .ultraWide: return .builtInUltraWideCamera
        case .wide: return .builtInWideAngleCamera
        case .telephoto3x, .telephoto5x: return .builtInTelephotoCamera
        }
    }
    
    var zoomFactor: CGFloat {
        switch self {
        case .ultraWide: return 0.5
        case .wide: return 1.0
        case .telephoto3x: return 3.0
        case .telephoto5x: return 5.0
        }
    }
}

// MARK: - Shutter Speed Presets

struct ShutterSpeedPreset: Identifiable {
    let label: String
    let time: CMTime
    
    var id: String { label }
    
    static let presets: [ShutterSpeedPreset] = [
        .init(label: "1/8000", time: CMTimeMake(value: 1, timescale: 8000)),
        .init(label: "1/4000", time: CMTimeMake(value: 1, timescale: 4000)),
        .init(label: "1/2000", time: CMTimeMake(value: 1, timescale: 2000)),
        .init(label: "1/1000", time: CMTimeMake(value: 1, timescale: 1000)),
        .init(label: "1/500",  time: CMTimeMake(value: 1, timescale: 500)),
        .init(label: "1/250",  time: CMTimeMake(value: 1, timescale: 250)),
        .init(label: "1/125",  time: CMTimeMake(value: 1, timescale: 125)),
        .init(label: "1/60",   time: CMTimeMake(value: 1, timescale: 60)),
        .init(label: "1/30",   time: CMTimeMake(value: 1, timescale: 30)),
        .init(label: "1/15",   time: CMTimeMake(value: 1, timescale: 15)),
        .init(label: "1/8",    time: CMTimeMake(value: 1, timescale: 8)),
        .init(label: "1/4",    time: CMTimeMake(value: 1, timescale: 4)),
        .init(label: "1/3",    time: CMTimeMake(value: 1, timescale: 3)),
    ]
}

// MARK: - Camera Settings

struct CameraSettings {
    var exposureMode: ExposureMode = .auto
    var shutterSpeed: CMTime = CMTimeMake(value: 1, timescale: 60)
    var iso: Float = 100.0
    var exposureCompensation: Float = 0.0
    
    var focusMode: FocusMode = .autoContinuous
    var manualFocusPosition: Float = 0.5
    
    var whiteBalanceMode: WhiteBalanceMode = .auto
    var whiteBalance: WhiteBalanceValues = .init()
    
    var zoomFactor: CGFloat = 1.0
    var selectedLens: LensType = .wide
}

// MARK: - LiDAR Settings

struct LiDARSettings {
    var maxDistance: Float = 5.0
    var confidenceThreshold: ConfidenceThreshold = .medium
    var smoothingEnabled: Bool = true
    
    static let distanceRange: ClosedRange<Float> = 0.5...5.0
}

// MARK: - Session Settings

struct SessionSettings {
    var camera: CameraSettings = .init()
    var lidar: LiDARSettings = .init()
}

// MARK: - Capture Frame Metadata

struct CaptureFrameMetadata: Codable {
    let frameIndex: Int
    let timestamp: Double
    let cameraPose: [[Float]]
    let cameraIntrinsics: [[Float]]
    let exposureDuration: Double
    let iso: Float
    let lensPosition: Float
    let trackingState: String
}

// MARK: - Thermal State

extension ProcessInfo.ThermalState {
    var label: String {
        switch self {
        case .nominal: return "Normal"
        case .fair: return "Warm"
        case .serious: return "Hot"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
    
    var color: String {
        switch self {
        case .nominal: return "green"
        case .fair: return "yellow"
        case .serious: return "orange"
        case .critical: return "red"
        @unknown default: return "gray"
        }
    }
}

// MARK: - Recorded Session (for Media Library)

struct RecordedSession: Identifiable, Hashable {
    let id: String
    let name: String
    let date: Date
    let directory: URL
    let frameCount: Int
    let hasDepth: Bool
    let hasConfidence: Bool
    let videoURL: URL?
    let thumbnailURL: URL?
    let hasEXR: Bool
    let exrDirectory: URL?

    var hasVideo: Bool { videoURL != nil }
    /// True when the session has a video file that has not yet been converted to an EXR sequence.
    var canConvertToEXR: Bool { hasVideo && !hasEXR }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: RecordedSession, rhs: RecordedSession) -> Bool { lhs.id == rhs.id }
}
