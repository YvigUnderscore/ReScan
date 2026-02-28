// ReMapModels.swift
// ReScan
//
// Data models for the ReMap API integration.

import Foundation

// MARK: - Server Configuration

struct ReMapServerConfig {
    var serverURL: String = ""
    var apiKey: String = ""
    
    var isConfigured: Bool {
        !serverURL.isEmpty && !apiKey.isEmpty
    }
    
    var baseURL: String {
        let url = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        return "\(url)/api/v1"
    }
}

// MARK: - Health Check

struct ReMapHealthResponse: Codable {
    let status: String
    let version: String
    let server: String
    let timestamp: String
}

// MARK: - Upload Response

struct ReMapUploadResponse: Codable {
    let datasetId: String
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case datasetId = "dataset_id"
        case message
    }
}

// MARK: - Process Response

struct ReMapProcessResponse: Codable {
    let jobId: String
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case message
    }
}

// MARK: - Job Status

enum ReMapJobStatus: String, Codable, CaseIterable, Identifiable {
    case queued
    case processing
    case completed
    case failed
    case cancelled
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .queued: return "Queued"
        case .processing: return "Processing"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var icon: String {
        switch self {
        case .queued: return "clock.fill"
        case .processing: return "gearshape.2.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        }
    }
    
    var color: String {
        switch self {
        case .queued: return "orange"
        case .processing: return "blue"
        case .completed: return "green"
        case .failed: return "red"
        case .cancelled: return "gray"
        }
    }
    
    var isTerminal: Bool {
        self == .completed || self == .failed || self == .cancelled
    }
}

struct ReMapJobStatusResponse: Codable {
    let jobId: String
    let status: String
    let progress: Int
    let currentStep: String?
    let message: String?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case progress
        case currentStep = "current_step"
        case message
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Job Log Entry

struct ReMapJobLogEntry: Codable, Identifiable {
    let step: String
    let message: String
    let timestamp: String?
    let level: String?
    
    var id: String { "\(step)_\(timestamp ?? UUID().uuidString)" }
}

struct ReMapJobLogsResponse: Codable {
    let jobId: String
    let logs: [ReMapJobLogEntry]
    
    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case logs
    }
}

// MARK: - Job List Item

struct ReMapJobListItem: Codable, Identifiable {
    let jobId: String
    let status: String
    let progress: Int
    let currentStep: String?
    let createdAt: String?
    let datasetId: String?
    
    var id: String { jobId }
    
    var parsedStatus: ReMapJobStatus {
        ReMapJobStatus(rawValue: status) ?? .failed
    }
    
    enum CodingKeys: String, CodingKey {
        case jobId = "job_id"
        case status
        case progress
        case currentStep = "current_step"
        case createdAt = "created_at"
        case datasetId = "dataset_id"
    }
}

struct ReMapJobListResponse: Codable {
    let jobs: [ReMapJobListItem]
}

// MARK: - Colorspace

enum ReMapColorspace: String, CaseIterable, Identifiable, Codable {
    case linear
    case srgb
    case acescg
    case aces2065_1 = "aces2065-1"
    case rec709
    case log
    case raw
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .linear: return "Linear"
        case .srgb: return "sRGB"
        case .acescg: return "ACEScg"
        case .aces2065_1: return "ACES2065-1"
        case .rec709: return "Rec.709"
        case .log: return "Log"
        case .raw: return "Raw"
        }
    }
    
    var description: String {
        switch self {
        case .linear: return "Linear light sRGB — pipeline internal working space"
        case .srgb: return "Display sRGB (gamma-corrected, standard monitor output)"
        case .acescg: return "ACEScg — ACES CG rendering/compositing working space"
        case .aces2065_1: return "ACES2065-1 — ACES interchange / archive format"
        case .rec709: return "Rec. 709 — broadcast/HD television standard"
        case .log: return "Generic logarithmic encoding"
        case .raw: return "No colorspace interpretation (pass-through)"
        }
    }
}

// MARK: - Processing Settings

struct ReMapProcessingSettings: Codable {
    var fps: Double = 5.0
    var featureType: String = "superpoint_aachen"
    var matcherType: String = "superpoint+lightglue"
    var maxKeypoints: Int = 8192
    var cameraModel: String = "PINHOLE"
    var mapperType: String = "GLOMAP"
    var strayApproach: String = "full_sfm"
    var pairingMode: String = "exhaustive"
    var numThreads: Int?
    var strayConfidence: Int = 2
    var strayDepthSubsample: Int = 2
    var strayGenPointcloud: Bool = true
    
    // Colorspace (top-level in API, but stored here for convenience)
    var colorspaceEnabled: Bool = false
    var inputColorspace: ReMapColorspace = .linear
    var outputColorspace: ReMapColorspace = .linear
    
    enum CodingKeys: String, CodingKey {
        case fps
        case featureType = "feature_type"
        case matcherType = "matcher_type"
        case maxKeypoints = "max_keypoints"
        case cameraModel = "camera_model"
        case mapperType = "mapper_type"
        case strayApproach = "stray_approach"
        case pairingMode = "pairing_mode"
        case numThreads = "num_threads"
        case strayConfidence = "stray_confidence"
        case strayDepthSubsample = "stray_depth_subsample"
        case strayGenPointcloud = "stray_gen_pointcloud"
        case colorspaceEnabled = "colorspace_enabled"
        case inputColorspace = "input_colorspace"
        case outputColorspace = "output_colorspace"
    }
    
    var settingsDictionary: [String: Any] {
        var dict: [String: Any] = [
            "fps": fps,
            "feature_type": featureType,
            "matcher_type": matcherType,
            "max_keypoints": maxKeypoints,
            "camera_model": cameraModel,
            "mapper_type": mapperType,
            "stray_approach": strayApproach,
            "pairing_mode": pairingMode,
            "stray_confidence": strayConfidence,
            "stray_depth_subsample": strayDepthSubsample,
            "stray_gen_pointcloud": strayGenPointcloud
        ]
        if let numThreads = numThreads {
            dict["num_threads"] = numThreads
        }
        return dict
    }
    
    // MARK: - Available Options
    
    static let featureTypeOptions = [
        "superpoint_aachen",
        "superpoint_max",
        "disk",
        "aliked-n16",
        "sift"
    ]
    
    static let matcherTypeOptions = [
        "superpoint+lightglue",
        "superglue",
        "disk+lightglue",
        "adalam"
    ]
    
    static let cameraModelOptions = [
        "OPENCV",
        "PINHOLE",
        "SIMPLE_RADIAL",
        "OPENCV_FISHEYE"
    ]
    
    static let mapperTypeOptions = ["COLMAP", "GLOMAP"]
    
    static let strayApproachOptions = ["full_sfm", "known_poses"]
    
    static let pairingModeOptions = ["sequential", "exhaustive"]
    
    // MARK: - Presets
    
    static let presetIndoor: ReMapProcessingSettings = {
        var s = ReMapProcessingSettings()
        s.fps = 3.0
        s.featureType = "superpoint_aachen"
        s.matcherType = "superpoint+lightglue"
        return s
    }()
    
    static let presetOutdoor: ReMapProcessingSettings = {
        var s = ReMapProcessingSettings()
        s.fps = 2.0
        s.featureType = "superpoint_max"
        s.matcherType = "superpoint+lightglue"
        return s
    }()
    
    static let presetTurntable: ReMapProcessingSettings = {
        var s = ReMapProcessingSettings()
        s.fps = 5.0
        s.strayApproach = "full_sfm"
        s.featureType = "superpoint_aachen"
        s.matcherType = "superpoint+lightglue"
        return s
    }()
    
    // MARK: - Tooltips
    
    static func tooltip(for key: String) -> String {
        switch key {
        case "fps":
            return "Frames per second extracted from the video for SfM. Lower = faster processing, higher = more detail."
        case "feature_type":
            return "Feature extraction method. SuperPoint variants are neural-network based and generally more robust. SIFT is classical."
        case "matcher_type":
            return "Feature matching method. SuperGlue and LightGlue are learned matchers. AdaLAM is classical."
        case "max_keypoints":
            return "Maximum number of keypoints detected per image."
        case "camera_model":
            return "Camera distortion model. PINHOLE works well for most iPhone captures."
        case "mapper_type":
            return "SfM engine. GLOMAP is faster and modern, COLMAP is the classic reference."
        case "stray_approach":
            return "full_sfm: Complete Structure-from-Motion pipeline. known_poses: Uses ARKit poses directly."
        case "pairing_mode":
            return "sequential: Pairs consecutive frames. exhaustive: Pairs all frames (slower but more robust)."
        case "num_threads":
            return "Number of CPU threads for processing. Leave at 0 to use all available cores."
        case "stray_confidence":
            return "LiDAR depth confidence threshold (0–2). Higher = stricter filtering."
        case "stray_depth_subsample":
            return "Depth frame subsampling factor. Higher = fewer depth frames used."
        case "stray_gen_pointcloud":
            return "Generate a 3D point cloud from LiDAR depth data."
        default:
            return ""
        }
    }
}

// MARK: - Upload Source Type

enum ReMapUploadSource: String, CaseIterable, Identifiable {
    case video = "RGB Video"
    case exr = "EXR Sequence"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .video: return "Upload the RGB video file (rgb.mp4/mov) with depth and odometry data."
        case .exr: return "Upload EXR image sequence with depth and odometry data (higher quality, larger files)."
        }
    }
}

// MARK: - API Error

enum ReMapAPIError: LocalizedError {
    case notConfigured
    case invalidURL
    case unauthorized
    case forbidden
    case badRequest(String)
    case payloadTooLarge
    case notFound
    case conflict(String)
    case serverError(Int, String)
    case networkError(Error)
    case invalidResponse
    case zipCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Server not configured. Please enter the server URL and API key in Settings."
        case .invalidURL:
            return "Invalid server URL."
        case .unauthorized:
            return "Authentication failed. Please check your API key."
        case .forbidden:
            return "Access denied. Invalid API key."
        case .badRequest(let msg):
            return "Bad request: \(msg)"
        case .payloadTooLarge:
            return "Dataset too large for the server."
        case .notFound:
            return "Resource not found on the server."
        case .conflict(let msg):
            return "Conflict: \(msg)"
        case .serverError(let code, let msg):
            return "Server error (\(code)): \(msg)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from server."
        case .zipCreationFailed:
            return "Failed to create ZIP archive for upload."
        }
    }
}
