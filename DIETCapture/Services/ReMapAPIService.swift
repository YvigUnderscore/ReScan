// ReMapAPIService.swift
// ReScan
//
// Networking service for all ReMap REST API endpoints.
// Handles authentication, upload with progress, job management, and result download.

import Foundation

final class ReMapAPIService: Sendable {
    static let shared = ReMapAPIService()
    
    // MARK: - Configuration
    
    private var config: ReMapServerConfig {
        ReMapServerConfig(
            serverURL: AppSettings.shared.remapServerURL,
            apiKey: KeychainService.shared.read(key: "remapAPIKey") ?? ""
        )
    }
    
    // MARK: - Health Check
    
    func healthCheck() async throws -> ReMapHealthResponse {
        let url = try makeURL("/health")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        // Health check does not require auth
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(ReMapHealthResponse.self, from: data)
    }
    
    // MARK: - Upload Dataset
    
    /// Standard upload with progress tracking via delegate
    func uploadDatasetStandard(zipURL: URL, progressHandler: @escaping (Double) -> Void) async throws -> ReMapUploadResponse {
        let url = try makeURL("/upload")
        let boundary = UUID().uuidString
        
        var request = try makeAuthenticatedRequest(url: url, method: "POST")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        let fileData = try Data(contentsOf: zipURL)
        let totalSize = fileData.count
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(zipURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/zip\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Track upload progress using observation
        let delegate = UploadProgressDelegate(totalBytes: Int64(totalSize), progressHandler: progressHandler)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        
        let (data, response) = try await session.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(ReMapUploadResponse.self, from: data)
    }
    
    // MARK: - Start Processing
    
    func startProcessing(datasetId: String, settings: ReMapProcessingSettings) async throws -> ReMapProcessResponse {
        let url = try makeURL("/process")
        
        var request = try makeAuthenticatedRequest(url: url, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "dataset_id": datasetId,
            "settings": settings.dictionary
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(ReMapProcessResponse.self, from: data)
    }
    
    // MARK: - Job Status
    
    func jobStatus(jobId: String) async throws -> ReMapJobStatusResponse {
        let url = try makeURL("/jobs/\(jobId)/status")
        let request = try makeAuthenticatedRequest(url: url)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(ReMapJobStatusResponse.self, from: data)
    }
    
    // MARK: - Job Logs
    
    func jobLogs(jobId: String) async throws -> ReMapJobLogsResponse {
        let url = try makeURL("/jobs/\(jobId)/logs")
        let request = try makeAuthenticatedRequest(url: url)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        return try JSONDecoder().decode(ReMapJobLogsResponse.self, from: data)
    }
    
    // MARK: - Download Result
    
    func downloadResult(jobId: String, to destinationURL: URL) async throws -> URL {
        let url = try makeURL("/jobs/\(jobId)/result")
        let request = try makeAuthenticatedRequest(url: url)
        
        let (tempURL, response) = try await URLSession.shared.download(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                let data = try? Data(contentsOf: tempURL)
                let message = data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }?["error"] as? String ?? "Unknown error"
                switch httpResponse.statusCode {
                case 404: throw ReMapAPIError.notFound
                case 409: throw ReMapAPIError.conflict(message)
                default: throw ReMapAPIError.serverError(httpResponse.statusCode, message)
                }
            }
        }
        
        // Move to destination
        let fm = FileManager.default
        if fm.fileExists(atPath: destinationURL.path) {
            try fm.removeItem(at: destinationURL)
        }
        try fm.moveItem(at: tempURL, to: destinationURL)
        return destinationURL
    }
    
    // MARK: - List Jobs
    
    func listJobs() async throws -> [ReMapJobListItem] {
        let url = try makeURL("/jobs")
        let request = try makeAuthenticatedRequest(url: url)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
        let listResponse = try JSONDecoder().decode(ReMapJobListResponse.self, from: data)
        return listResponse.jobs
    }
    
    // MARK: - Cancel Job
    
    func cancelJob(jobId: String) async throws {
        let url = try makeURL("/jobs/\(jobId)/cancel")
        let request = try makeAuthenticatedRequest(url: url, method: "POST")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateResponse(response, data: data)
    }
    
    // MARK: - ZIP Creation
    
    func createDatasetZIP(session: RecordedSession, source: ReMapUploadSource, progressHandler: @escaping (Double) -> Void) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let zipURL = try self.buildZIP(session: session, source: source, progressHandler: progressHandler)
                    continuation.resume(returning: zipURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func buildZIP(session: RecordedSession, source: ReMapUploadSource, progressHandler: @escaping (Double) -> Void) throws -> URL {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("remap_zip_\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Collect all files to include
        var filesToZip: [(source: URL, archivePath: String)] = []
        let sessionDir = session.directory
        
        // Required: camera_matrix.csv, odometry.csv
        let cameraMatrix = sessionDir.appendingPathComponent("camera_matrix.csv")
        let odometry = sessionDir.appendingPathComponent("odometry.csv")
        if fm.fileExists(atPath: cameraMatrix.path) {
            filesToZip.append((cameraMatrix, "camera_matrix.csv"))
        }
        if fm.fileExists(atPath: odometry.path) {
            filesToZip.append((odometry, "odometry.csv"))
        }
        
        // Video or EXR based on source selection
        switch source {
        case .video:
            if let videoURL = session.videoURL, fm.fileExists(atPath: videoURL.path) {
                filesToZip.append((videoURL, videoURL.lastPathComponent))
            }
        case .exr:
            if let exrDir = session.exrDirectory, fm.fileExists(atPath: exrDir.path) {
                let exrFiles = (try? fm.contentsOfDirectory(atPath: exrDir.path))?.filter { $0.hasSuffix(".exr") }.sorted() ?? []
                for file in exrFiles {
                    let fileURL = exrDir.appendingPathComponent(file)
                    filesToZip.append((fileURL, "rgb/\(file)"))
                }
            }
        }
        
        // Depth maps
        let depthDir = sessionDir.appendingPathComponent("depth")
        if fm.fileExists(atPath: depthDir.path) {
            let depthFiles = (try? fm.contentsOfDirectory(atPath: depthDir.path))?.filter { $0.hasSuffix(".png") }.sorted() ?? []
            for file in depthFiles {
                let fileURL = depthDir.appendingPathComponent(file)
                filesToZip.append((fileURL, "depth/\(file)"))
            }
        }
        
        // Confidence maps
        let confDir = sessionDir.appendingPathComponent("confidence")
        if fm.fileExists(atPath: confDir.path) {
            let confFiles = (try? fm.contentsOfDirectory(atPath: confDir.path))?.filter { $0.hasSuffix(".png") }.sorted() ?? []
            for file in confFiles {
                let fileURL = confDir.appendingPathComponent(file)
                filesToZip.append((fileURL, "confidence/\(file)"))
            }
        }
        
        // Mesh
        let meshURL = sessionDir.appendingPathComponent("mesh.obj")
        if fm.fileExists(atPath: meshURL.path) {
            filesToZip.append((meshURL, "mesh.obj"))
        }
        
        guard !filesToZip.isEmpty else {
            throw ReMapAPIError.zipCreationFailed
        }
        
        // Copy files to temp directory maintaining structure
        let total = filesToZip.count
        for (index, file) in filesToZip.enumerated() {
            let destURL = tempDir.appendingPathComponent(file.archivePath)
            let destDir = destURL.deletingLastPathComponent()
            try fm.createDirectory(at: destDir, withIntermediateDirectories: true)
            try fm.copyItem(at: file.source, to: destURL)
            DispatchQueue.main.async {
                progressHandler(Double(index + 1) / Double(total) * 0.5) // 50% for copy
            }
        }
        
        // Create ZIP using NSFileCoordinator
        let zipURL = fm.temporaryDirectory.appendingPathComponent("remap_\(UUID().uuidString).zip")
        if fm.fileExists(atPath: zipURL.path) {
            try fm.removeItem(at: zipURL)
        }
        
        // Use command line zip via Process is not available on iOS, use Archive framework approach
        // We'll use a simple manual approach: copy to a coordinator
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: tempDir, options: [.forUploading], error: &error) { compressedURL in
            do {
                try fm.copyItem(at: compressedURL, to: zipURL)
            } catch {
                print("[ReMapAPI] ZIP copy error: \(error)")
            }
        }
        if let error = error {
            throw error
        }
        
        // Cleanup temp directory
        try? fm.removeItem(at: tempDir)
        
        DispatchQueue.main.async {
            progressHandler(1.0)
        }
        
        guard fm.fileExists(atPath: zipURL.path) else {
            throw ReMapAPIError.zipCreationFailed
        }
        
        return zipURL
    }
    
    // MARK: - Helpers
    
    private func makeAuthenticatedRequest(url: URL, method: String = "GET") throws -> URLRequest {
        guard !config.apiKey.isEmpty else {
            throw ReMapAPIError.unauthorized
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }
    
    private func makeURL(_ path: String) throws -> URL {
        guard config.isConfigured || path == "/health" else {
            throw ReMapAPIError.notConfigured
        }
        
        let baseURL: String
        if path == "/health" && !config.serverURL.isEmpty {
            let url = config.serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
            baseURL = "\(url)/api/v1"
        } else {
            baseURL = config.baseURL
        }
        
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw ReMapAPIError.invalidURL
        }
        return url
    }
    
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReMapAPIError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw ReMapAPIError.unauthorized
        case 403:
            throw ReMapAPIError.forbidden
        case 400:
            let message = extractErrorMessage(from: data)
            throw ReMapAPIError.badRequest(message)
        case 404:
            throw ReMapAPIError.notFound
        case 409:
            let message = extractErrorMessage(from: data)
            throw ReMapAPIError.conflict(message)
        case 413:
            throw ReMapAPIError.payloadTooLarge
        default:
            let message = extractErrorMessage(from: data)
            throw ReMapAPIError.serverError(httpResponse.statusCode, message)
        }
    }
    
    private func extractErrorMessage(from data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? String {
            return error
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
}

// MARK: - Upload Progress Delegate

private class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    let totalBytes: Int64
    let progressHandler: (Double) -> Void
    
    init(totalBytes: Int64, progressHandler: @escaping (Double) -> Void) {
        self.totalBytes = totalBytes
        self.progressHandler = progressHandler
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        DispatchQueue.main.async {
            self.progressHandler(progress)
        }
    }
}
