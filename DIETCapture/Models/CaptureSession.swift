// CaptureSession.swift
// ReScan
//
// Represents one recording session. Stray Scanner-compatible directory structure.

import Foundation
import AVFoundation

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
    var lidarEnabled: Bool = true
    
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
    var meshURL: URL? { lidarEnabled ? sessionDirectory?.appendingPathComponent("mesh.obj") : nil }
    
    // MARK: - Methods
    
    func createSessionDirectory() throws -> URL {
        let baseDir: URL
        if let externalURL = SecurityScopedStorageManager.shared.externalStorageURL {
            baseDir = externalURL
        } else {
            baseDir = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let sessionName = "scan_\(dateFormatter.string(from: Date()))"
        let sessionDir = baseDir.appendingPathComponent(sessionName)
        
        var subdirectories: [String] = []
        
        if lidarEnabled {
            subdirectories.append(contentsOf: ["depth", "confidence"])
        }
        
        if encodingMode == .exrSequence {
            subdirectories.append("rgb")
        }
        
        for subdir in subdirectories {
            let dir = sessionDir.appendingPathComponent(subdir)
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        
        // Ensure session directory exists even if no subdirectories
        if subdirectories.isEmpty {
            try fileManager.createDirectory(at: sessionDir, withIntermediateDirectories: true)
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
        let pathToCheck = SecurityScopedStorageManager.shared.externalStorageURL?.path ?? NSHomeDirectory()
        if let attrs = try? fileManager.attributesOfFileSystem(
            forPath: pathToCheck
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
        var sessions: [RecordedSession] = []
        
        // Helper to scan a directory for sessions
        func scanDirectory(_ directory: URL) {
            guard let contents = try? fm.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.creationDateKey],
                options: [.skipsHiddenFiles]
            ) else { return }
            
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
                
                // Detect EXR conversion status
                let rgbDir = dir.appendingPathComponent("rgb")
                let exrFiles = (try? fm.contentsOfDirectory(atPath: rgbDir.path))?.filter { $0.hasSuffix(".exr") } ?? []
                let hasEXR = !exrFiles.isEmpty
                let exrDirectory: URL? = fm.fileExists(atPath: rgbDir.path) ? rgbDir : nil
                
                // Compute total disk size for the session directory
                let diskSizeMB = directorySize(dir, fileManager: fm) / (1024 * 1024)
                
                // Mesh
                let meshObjURL = dir.appendingPathComponent("mesh.obj")
                let meshURL: URL? = fm.fileExists(atPath: meshObjURL.path) ? meshObjURL : nil
                
                // Video duration
                var duration: TimeInterval?
                if let vURL = videoURL {
                    let asset = AVURLAsset(url: vURL)
                    let seconds = asset.duration.seconds
                    if seconds.isFinite && seconds > 0 { duration = seconds }
                }
                
                sessions.append(RecordedSession(
                    id: name,
                    name: name,
                    date: creationDate,
                    directory: dir,
                    frameCount: depthFiles.count,
                    hasDepth: !depthFiles.isEmpty,
                    hasConfidence: hasConf,
                    videoURL: videoURL,
                    thumbnailURL: thumbURL,
                    hasEXR: hasEXR,
                    exrDirectory: exrDirectory,
                    diskSizeMB: diskSizeMB,
                    duration: duration,
                    meshURL: meshURL
                ))
            }
        }
        
        // Scan internal documents directory
        if let documentsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            scanDirectory(documentsDir)
        }
        
        // Scan external directory if available
        if let externalDir = SecurityScopedStorageManager.shared.externalStorageURL {
            scanDirectory(externalDir)
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
    
    // MARK: - Directory Size Helper
    
    private static func directorySize(_ url: URL, fileManager: FileManager) -> Double {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            total += Int64((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return Double(total)
    }
}

// MARK: - Date Extension

fileprivate extension Date {
    var iso8601String: String {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: self)
    }
}
