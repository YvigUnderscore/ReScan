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

// MARK: - Processing Settings

struct ReMapProcessingSettings: Codable {
    var fps: Double = 4.0
    var strayApproach: String = "full_sfm"
    var featureType: String = "superpoint_aachen"
    var matcherType: String = "superglue"
    var singleCamera: Bool = true
    var cameraModel: String = "PINHOLE"
    var useGPU: Bool = true
    
    enum CodingKeys: String, CodingKey {
        case fps
        case strayApproach = "stray_approach"
        case featureType = "feature_type"
        case matcherType = "matcher_type"
        case singleCamera = "single_camera"
        case cameraModel = "camera_model"
        case useGPU = "use_gpu"
    }
    
    var dictionary: [String: Any] {
        [
            "fps": fps,
            "stray_approach": strayApproach,
            "feature_type": featureType,
            "matcher_type": matcherType,
            "single_camera": singleCamera,
            "camera_model": cameraModel,
            "use_gpu": useGPU
        ]
    }
    
    // MARK: - Available Options
    
    static let strayApproachOptions = ["full_sfm", "triangulation"]
    
    static let featureTypeOptions = [
        "superpoint_aachen",
        "superpoint_max",
        "superpoint_inloc",
        "disk",
        "sosnet",
        "hardnet",
        "d2net-ss",
        "sift",
        "alike",
        "aliked-n16",
        "aliked-n32"
    ]
    
    static let matcherTypeOptions = [
        "superglue",
        "superglue-fast",
        "NN-superpoint",
        "NN-ratio",
        "NN-mutual",
        "adalam",
        "lightglue",
        "lightglue-aliked",
        "lightglue-disk"
    ]
    
    static let cameraModelOptions = [
        "PINHOLE",
        "SIMPLE_PINHOLE",
        "SIMPLE_RADIAL",
        "RADIAL",
        "OPENCV",
        "OPENCV_FISHEYE"
    ]
    
    // MARK: - Presets
    
    static let presetIndoor: ReMapProcessingSettings = {
        var s = ReMapProcessingSettings()
        s.fps = 3.0
        s.featureType = "superpoint_aachen"
        s.matcherType = "superglue"
        return s
    }()
    
    static let presetOutdoor: ReMapProcessingSettings = {
        var s = ReMapProcessingSettings()
        s.fps = 2.0
        s.featureType = "superpoint_max"
        s.matcherType = "lightglue"
        return s
    }()
    
    static let presetTurntable: ReMapProcessingSettings = {
        var s = ReMapProcessingSettings()
        s.fps = 5.0
        s.strayApproach = "full_sfm"
        s.featureType = "superpoint_aachen"
        s.matcherType = "superglue"
        return s
    }()
    
    // MARK: - Tooltips
    
    static func tooltip(for key: String) -> String {
        switch key {
        case "fps":
            return "Frames per second extracted from the video for SfM. Lower = faster processing, higher = more detail."
        case "stray_approach":
            return "full_sfm: Complete Structure-from-Motion pipeline. triangulation: Faster, uses existing poses."
        case "feature_type":
            return "Feature extraction method. SuperPoint variants are neural-network based and generally more robust. SIFT is classical."
        case "matcher_type":
            return "Feature matching method. SuperGlue and LightGlue are learned matchers. NN variants are classical nearest-neighbor."
        case "single_camera":
            return "Assume all images come from a single camera (recommended for iPhone captures)."
        case "camera_model":
            return "Camera distortion model. PINHOLE works well for most iPhone captures."
        case "use_gpu":
            return "Use GPU acceleration on the server for feature extraction and matching."
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
