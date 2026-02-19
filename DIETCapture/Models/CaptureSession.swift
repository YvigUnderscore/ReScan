// CaptureSession.swift
// DIETCapture
//
// Represents one recording session: tracks frames, timestamps, and output paths.

import Foundation

@Observable
final class CaptureSession {
    
    // MARK: - State
    
    enum State: String {
        case idle
        case recording
        case paused
        case saving
    }
    
    enum CaptureType: String {
        case photo
        case video
    }
    
    // MARK: - Properties
    
    var state: State = .idle
    var captureType: CaptureType = .video
    var frameCount: Int = 0
    var startTime: Date?
    var elapsedTime: TimeInterval = 0
    var sessionDirectory: URL?
    var frameMetadata: [CaptureFrameMetadata] = []
    
    // Storage
    var estimatedStorageUsedMB: Double = 0
    var availableStorageMB: Double = 0
    
    // MARK: - Directory Structure
    
    private let fileManager = FileManager.default
    
    var rgbDirectory: URL? { sessionDirectory?.appendingPathComponent("rgb") }
    var depthDirectory: URL? { sessionDirectory?.appendingPathComponent("depth") }
    var confidenceDirectory: URL? { sessionDirectory?.appendingPathComponent("confidence") }
    var posesDirectory: URL? { sessionDirectory?.appendingPathComponent("poses") }
    var pointcloudsDirectory: URL? { sessionDirectory?.appendingPathComponent("pointclouds") }
    var meshDirectory: URL? { sessionDirectory?.appendingPathComponent("mesh") }
    var metadataDirectory: URL? { sessionDirectory?.appendingPathComponent("metadata") }
    var colmapDirectory: URL? { sessionDirectory?.appendingPathComponent("metadata/colmap") }
    var videoDirectory: URL? { sessionDirectory?.appendingPathComponent("video") }
    
    // MARK: - Methods
    
    func createSessionDirectory() throws -> URL {
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let sessionName = "capture_session_\(dateFormatter.string(from: Date()))"
        let sessionDir = documentsDir.appendingPathComponent(sessionName)
        
        let subdirectories = [
            "rgb", "depth", "confidence", "poses",
            "pointclouds", "mesh", "metadata", "metadata/colmap", "video"
        ]
        
        for subdir in subdirectories {
            let dir = sessionDir.appendingPathComponent(subdir)
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        sessionDirectory = sessionDir
        return sessionDir
    }
    
    func startRecording() {
        state = .recording
        startTime = Date()
        frameCount = 0
        frameMetadata = []
        elapsedTime = 0
    }
    
    func stopRecording() {
        state = .saving
    }
    
    func finishSaving() {
        state = .idle
    }
    
    func addFrame(metadata: CaptureFrameMetadata) {
        frameMetadata.append(metadata)
        frameCount += 1
    }
    
    func updateElapsedTime() {
        guard let start = startTime else { return }
        elapsedTime = Date().timeIntervalSince(start)
    }
    
    func updateStorageInfo() {
        if let attrs = try? fileManager.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        ) {
            if let freeSize = attrs[.systemFreeSize] as? Int64 {
                availableStorageMB = Double(freeSize) / (1024 * 1024)
            }
        }
    }
    
    // MARK: - Frame Naming
    
    func frameName(for index: Int) -> String {
        return String(format: "frame_%06d", index)
    }
    
    func rgbURL(for index: Int, extension ext: String) -> URL? {
        rgbDirectory?.appendingPathComponent("\(frameName(for: index)).\(ext)")
    }
    
    func depthURL(for index: Int, extension ext: String) -> URL? {
        depthDirectory?.appendingPathComponent("\(frameName(for: index)).\(ext)")
    }
    
    func confidenceURL(for index: Int) -> URL? {
        confidenceDirectory?.appendingPathComponent("\(frameName(for: index)).png")
    }
    
    func poseURL(for index: Int) -> URL? {
        posesDirectory?.appendingPathComponent("\(frameName(for: index)).txt")
    }
    
    func pointCloudURL(for index: Int) -> URL? {
        pointcloudsDirectory?.appendingPathComponent("\(frameName(for: index)).ply")
    }
    
    // MARK: - Session Info Export
    
    func exportSessionInfo(settings: SessionSettings, deviceName: String) throws {
        guard let metaDir = metadataDirectory else { return }
        
        let info: [String: Any] = [
            "device": deviceName,
            "startTime": startTime?.iso8601String ?? "",
            "endTime": Date().iso8601String,
            "frameCount": frameCount,
            "settings": [
                "exposureMode": settings.camera.exposureMode.rawValue,
                "photoFormat": settings.camera.photoFormat.rawValue,
                "videoCodec": settings.camera.videoCodec.rawValue,
                "depthFormat": settings.camera.depthExportFormat.rawValue,
                "targetFramerate": settings.camera.targetFramerate,
                "lidarMaxDistance": settings.lidar.maxDistance,
                "lidarSmoothing": settings.lidar.smoothingEnabled,
                "confidenceThreshold": settings.lidar.confidenceThreshold.rawValue
            ]
        ]
        
        let data = try JSONSerialization.data(withJSONObject: info, options: .prettyPrinted)
        let url = metaDir.appendingPathComponent("session_info.json")
        try data.write(to: url)
    }
}

// MARK: - Date Extension

fileprivate extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
