// CaptureSession.swift
// ReScan
//
// Represents one recording session. Stray Scanner-compatible directory structure.

import Foundation

@Observable
final class CaptureSession {
    
    // MARK: - State
    
    enum State: String {
        case idle
        case recording
        case saving
    }
    
    // MARK: - Properties
    
    var state: State = .idle
    var frameCount: Int = 0
    var startTime: Date?
    var elapsedTime: TimeInterval = 0
    var sessionDirectory: URL?
    var frameMetadata: [CaptureFrameMetadata] = []
    var encodingMode: VideoEncodingMode = .standardHEVC
    
    var estimatedStorageUsedMB: Double = 0
    var availableStorageMB: Double = 0
    
    // MARK: - Stray Scanner Directory Structure
    
    private let fileManager = FileManager.default
    
    var depthDirectory: URL? { sessionDirectory?.appendingPathComponent("depth") }
    var confidenceDirectory: URL? { sessionDirectory?.appendingPathComponent("confidence") }
    
    /// Video URL — .mov for ProRes/Apple Log, .mp4 for HEVC. Nil if EXR sequence.
    var videoURL: URL? {
        if encodingMode == .exrSequence { return nil }
        return sessionDirectory?.appendingPathComponent("rgb.\(encodingMode.fileExtension)")
    }
    
    var exrDirectory: URL? {
        if encodingMode == .exrSequence {
            return sessionDirectory?.appendingPathComponent("rgb")
        }
        return nil
    }
    
    var cameraMatrixURL: URL? { sessionDirectory?.appendingPathComponent("camera_matrix.csv") }
    var odometryURL: URL? { sessionDirectory?.appendingPathComponent("odometry.csv") }
    var meshURL: URL? { sessionDirectory?.appendingPathComponent("mesh.obj") }
    
    // MARK: - Methods
    
    func createSessionDirectory() throws -> URL {
        let documentsDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let sessionName = "scan_\(dateFormatter.string(from: Date()))"
        let sessionDir = documentsDir.appendingPathComponent(sessionName)
        
        var subdirectories = ["depth", "confidence"]
        
        if encodingMode == .exrSequence {
            subdirectories.append("rgb")
        }
        
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
    
    // MARK: - Stray Scanner Naming (6-digit zero-padded)
    
    func frameName(for index: Int) -> String {
        return String(format: "%06d", index)
    }
    
    func depthURL(for index: Int) -> URL? {
        depthDirectory?.appendingPathComponent("\(frameName(for: index)).png")
    }
    
    func confidenceURL(for index: Int) -> URL? {
        confidenceDirectory?.appendingPathComponent("\(frameName(for: index)).png")
    }
    
    func exrURL(for index: Int) -> URL? {
        exrDirectory?.appendingPathComponent("\(frameName(for: index)).exr")
    }
    
    // MARK: - List All Sessions
    
    static func listSessions() -> [RecordedSession] {
        let fm = FileManager.default
        guard let documentsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return [] }
        
        guard let contents = try? fm.contentsOfDirectory(
            at: documentsDir, includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        var sessions: [RecordedSession] = []
        
        for dir in contents {
            guard dir.hasDirectoryPath else { continue }
            let name = dir.lastPathComponent
            guard name.hasPrefix("scan_") else { continue }
            
            let depthDir = dir.appendingPathComponent("depth")
            let confDir = dir.appendingPathComponent("confidence")
            // Check for both .mp4 and .mov video files
            let videoFileMp4 = dir.appendingPathComponent("rgb.mp4")
            let videoFileMov = dir.appendingPathComponent("rgb.mov")
            
            var videoURL: URL?
            if fm.fileExists(atPath: videoFileMp4.path) {
                videoURL = videoFileMp4
            } else if fm.fileExists(atPath: videoFileMov.path) {
                videoURL = videoFileMov
            }

            let depthFiles = (try? fm.contentsOfDirectory(atPath: depthDir.path))?.filter { $0.hasSuffix(".png") } ?? []
            let hasConf = fm.fileExists(atPath: confDir.path)
            
            let creationDate = (try? fm.attributesOfItem(atPath: dir.path))?[.creationDate] as? Date ?? Date()
            
            // Thumbnail: first depth frame
            let thumbURL = depthFiles.isEmpty ? nil : depthDir.appendingPathComponent(depthFiles.sorted().first!)
            
            sessions.append(RecordedSession(
                id: name,
                name: name,
                date: creationDate,
                directory: dir,
                frameCount: depthFiles.count,
                hasDepth: !depthFiles.isEmpty,
                hasConfidence: hasConf,
                videoURL: videoURL,
                thumbnailURL: thumbURL
            ))
        }
        
        return sessions.sorted { $0.date > $1.date }
    }
    
    // MARK: - Delete Session
    
    static func deleteSession(_ session: RecordedSession) {
        let fm = FileManager.default
        do {
            try fm.removeItem(at: session.directory)
        } catch {
            print("[CaptureSession] Failed to delete session: \(error)")
        }
    }
}

// MARK: - Date Extension

fileprivate extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
