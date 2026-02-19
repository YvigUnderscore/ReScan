// CaptureModels.swift
// DIETCapture
//
// Core data models, enums, and settings structs for the capture app.

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
    var temperature: Float = 5500.0  // Kelvin
    var tint: Float = 0.0
    
    static let temperatureRange: ClosedRange<Float> = 2000...10000
    static let tintRange: ClosedRange<Float> = -150...150
}

// MARK: - Capture Format

enum PhotoFormat: String, CaseIterable, Identifiable {
    case heif = "HEIF"
    case jpeg = "JPEG"
    case proRAW = "ProRAW (DNG)"
    
    var id: String { rawValue }
}

enum VideoCodec: String, CaseIterable, Identifiable {
    case hevc = "HEVC (H.265)"
    case prores422 = "ProRes 422"
    case prores422HQ = "ProRes 422 HQ"
    
    var id: String { rawValue }
    
    var avCodecType: AVVideoCodecType {
        switch self {
        case .hevc: return .hevc
        case .prores422: return .proRes422
        case .prores422HQ: return .proRes422HQ
        }
    }
}

// MARK: - Depth Export

enum DepthExportFormat: String, CaseIterable, Identifiable {
    case exr = "EXR (32-bit float)"
    case png16 = "PNG (16-bit mm)"
    case tiff32 = "TIFF (32-bit float)"
    
    var id: String { rawValue }
    
    var fileExtension: String {
        switch self {
        case .exr: return "exr"
        case .png16: return "png"
        case .tiff32: return "tiff"
        }
    }
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
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

// MARK: - Depth Overlay

enum DepthOverlayMode: String, CaseIterable, Identifiable {
    case none = "None"
    case depth = "Depth"
    case confidence = "Confidence"
    case mesh = "Mesh"
    
    var id: String { rawValue }
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

// MARK: - Resolution Preset

struct ResolutionPreset: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let width: Int
    let height: Int
    let format: AVCaptureDevice.Format?
    
    static func == (lhs: ResolutionPreset, rhs: ResolutionPreset) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Framerate Preset

struct FrameratePreset: Identifiable, Hashable {
    let fps: Double
    
    var id: Double { fps }
    var label: String { "\(Int(fps)) fps" }
    
    static let common: [FrameratePreset] = [
        .init(fps: 24), .init(fps: 25), .init(fps: 30),
        .init(fps: 60), .init(fps: 120), .init(fps: 240)
    ]
}

// MARK: - Camera Settings

struct CameraSettings {
    // Exposure
    var exposureMode: ExposureMode = .auto
    var shutterSpeed: CMTime = CMTimeMake(value: 1, timescale: 60)
    var iso: Float = 100.0
    var exposureCompensation: Float = 0.0
    
    // Focus
    var focusMode: FocusMode = .autoContinuous
    var manualFocusPosition: Float = 0.5  // 0.0 - 1.0
    
    // White Balance
    var whiteBalanceMode: WhiteBalanceMode = .auto
    var whiteBalance: WhiteBalanceValues = .init()
    
    // Format
    var photoFormat: PhotoFormat = .heif
    var videoCodec: VideoCodec = .hevc
    var depthExportFormat: DepthExportFormat = .png16
    
    // Framerate
    var targetFramerate: Double = 30.0
    
    // Zoom
    var zoomFactor: CGFloat = 1.0
    var selectedLens: LensType = .wide
}

// MARK: - LiDAR Settings

struct LiDARSettings {
    var maxDistance: Float = 5.0          // meters
    var confidenceThreshold: ConfidenceThreshold = .medium
    var smoothingEnabled: Bool = true
    var overlayMode: DepthOverlayMode = .none
    var overlayOpacity: Float = 0.5       // 0.0 - 1.0
    var exportPointClouds: Bool = true
    var exportMesh: Bool = false
    
    static let distanceRange: ClosedRange<Float> = 0.5...5.0
}

// MARK: - Session Settings

struct SessionSettings {
    var camera: CameraSettings = .init()
    var lidar: LiDARSettings = .init()
    var exportCOLMAP: Bool = true
    var exportIntrinsics: Bool = true
    var exportPoses: Bool = true
    var geotagging: Bool = false
}

// MARK: - Capture Frame Metadata

struct CaptureFrameMetadata: Codable {
    let frameIndex: Int
    let timestamp: Double
    let cameraPose: [[Float]]        // 4x4 matrix
    let cameraIntrinsics: [[Float]]  // 3x3 matrix
    let exposureDuration: Double
    let iso: Float
    let lensPosition: Float
    let trackingState: String
}

// MARK: - Shutter Speed Presets

struct ShutterSpeedPreset {
    static let presets: [(label: String, time: CMTime)] = [
        ("1/8000", CMTimeMake(value: 1, timescale: 8000)),
        ("1/4000", CMTimeMake(value: 1, timescale: 4000)),
        ("1/2000", CMTimeMake(value: 1, timescale: 2000)),
        ("1/1000", CMTimeMake(value: 1, timescale: 1000)),
        ("1/500",  CMTimeMake(value: 1, timescale: 500)),
        ("1/250",  CMTimeMake(value: 1, timescale: 250)),
        ("1/125",  CMTimeMake(value: 1, timescale: 125)),
        ("1/60",   CMTimeMake(value: 1, timescale: 60)),
        ("1/30",   CMTimeMake(value: 1, timescale: 30)),
        ("1/15",   CMTimeMake(value: 1, timescale: 15)),
        ("1/8",    CMTimeMake(value: 1, timescale: 8)),
        ("1/4",    CMTimeMake(value: 1, timescale: 4)),
        ("1/3",    CMTimeMake(value: 1, timescale: 3)),
    ]
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
