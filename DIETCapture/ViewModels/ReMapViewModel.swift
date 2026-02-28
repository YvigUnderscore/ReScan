// ReMapViewModel.swift
// ReScan
//
// ViewModel managing all ReMap API interaction state:
// server config, dataset upload, job tracking, polling, logs, and result download.

import Foundation
import SwiftUI
import Combine

@Observable
final class ReMapViewModel {
    
    // MARK: - Server State
    
    var serverURL: String = ""
    var apiKey: String = ""
    var isServerOnline: Bool = false
    var serverVersion: String?
    var isCheckingServer: Bool = false
    
    // MARK: - Upload State
    
    var isCreatingZIP: Bool = false
    var isUploading: Bool = false
    var uploadProgress: Double = 0
    var zipProgress: Double = 0
    var lastDatasetId: String?
    var uploadSource: ReMapUploadSource = .video
    var showSourcePicker: Bool = false
    
    // EXR generation
    var showEXRGenerationPrompt: Bool = false
    var isGeneratingEXR: Bool = false
    var exrGenerationProgress: Double = 0
    var pendingEXRSession: RecordedSession?
    
    // MARK: - Processing State
    
    var isStartingProcess: Bool = false
    var processingSettings: ReMapProcessingSettings = .init()
    
    // MARK: - Jobs
    
    var jobs: [ReMapJobListItem] = []
    var activeJobId: String?
    var activeJobStatus: ReMapJobStatusResponse?
    var isPolling: Bool = false
    
    // MARK: - Logs
    
    var jobLogs: [ReMapJobLogEntry] = []
    var isLoadingLogs: Bool = false
    
    // MARK: - Download
    
    var isDownloading: Bool = false
    var downloadProgress: Double = 0
    var lastDownloadedURL: URL?
    
    // MARK: - Error / Alert
    
    var showError: Bool = false
    var errorMessage: String?
    var showSuccess: Bool = false
    var successMessage: String?
    
    // MARK: - Private
    
    private let api = ReMapAPIService.shared
    private var pollingTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        loadConfig()
        loadDefaultSettings()
    }
    
    // MARK: - Config Management
    
    func loadConfig() {
        serverURL = AppSettings.shared.remapServerURL
        apiKey = KeychainService.shared.read(key: "remapAPIKey") ?? ""
    }
    
    func loadDefaultSettings() {
        let s = AppSettings.shared
        processingSettings.fps = s.remapDefaultFPS
        processingSettings.strayApproach = s.remapDefaultApproach
        processingSettings.featureType = s.remapDefaultFeatureType
        processingSettings.matcherType = s.remapDefaultMatcherType
        processingSettings.cameraModel = s.remapDefaultCameraModel
        processingSettings.maxKeypoints = s.remapDefaultMaxKeypoints
        processingSettings.mapperType = s.remapDefaultMapperType
        processingSettings.pairingMode = s.remapDefaultPairingMode
        processingSettings.numThreads = s.remapDefaultNumThreads > 0 ? s.remapDefaultNumThreads : nil
        processingSettings.strayConfidence = s.remapDefaultStrayConfidence
        processingSettings.strayDepthSubsample = s.remapDefaultStrayDepthSubsample
        processingSettings.strayGenPointcloud = s.remapDefaultStrayGenPointcloud
        processingSettings.colorspaceEnabled = s.remapDefaultColorspaceEnabled
        processingSettings.inputColorspace = ReMapColorspace(rawValue: s.remapDefaultInputColorspace) ?? .linear
        processingSettings.outputColorspace = ReMapColorspace(rawValue: s.remapDefaultOutputColorspace) ?? .linear
    }
    
    func saveConfig() {
        AppSettings.shared.remapServerURL = serverURL
        if !apiKey.isEmpty {
            _ = KeychainService.shared.save(key: "remapAPIKey", value: apiKey)
        } else {
            _ = KeychainService.shared.delete(key: "remapAPIKey")
        }
    }
    
    var isConfigured: Bool {
        !serverURL.isEmpty && !apiKey.isEmpty
    }
    
    // MARK: - Health Check
    
    func checkServer() async {
        isCheckingServer = true
        defer { isCheckingServer = false }
        
        do {
            let health = try await api.healthCheck()
            isServerOnline = health.status == "ok"
            serverVersion = health.version
        } catch {
            isServerOnline = false
            serverVersion = nil
        }
    }
    
    // MARK: - Upload
    
    func uploadDataset(session: RecordedSession) async {
        // Check if EXR is available and let user choose
        if session.hasEXR && session.hasVideo {
            showSourcePicker = true
            return
        }
        
        // Auto-select source
        if session.hasEXR && !session.hasVideo {
            uploadSource = .exr
        } else {
            uploadSource = .video
        }
        
        await performUpload(session: session)
    }
    
    func performUpload(session: RecordedSession) async {
        guard isConfigured else {
            showErrorMessage("Server not configured. Go to Settings to add server URL and API key.")
            return
        }
        
        // Validate required files
        let fm = FileManager.default
        let hasOdometry = fm.fileExists(atPath: session.directory.appendingPathComponent("odometry.csv").path)
        let hasCameraMatrix = fm.fileExists(atPath: session.directory.appendingPathComponent("camera_matrix.csv").path)
        
        guard hasOdometry && hasCameraMatrix else {
            showErrorMessage("Dataset missing required files (camera_matrix.csv and/or odometry.csv).")
            return
        }
        
        if uploadSource == .video {
            guard session.hasVideo else {
                showErrorMessage("No RGB video found in this dataset.")
                return
            }
        } else {
            guard session.hasEXR else {
                // Propose auto-generation if video is available
                if session.hasVideo {
                    pendingEXRSession = session
                    showEXRGenerationPrompt = true
                } else {
                    showErrorMessage("No EXR sequence or video found in this dataset.")
                }
                return
            }
        }
        
        // Step 1: Create ZIP
        isCreatingZIP = true
        zipProgress = 0
        
        do {
            let zipURL = try await api.createDatasetZIP(session: session, source: uploadSource) { progress in
                self.zipProgress = progress
            }
            isCreatingZIP = false
            
            // Step 2: Upload
            isUploading = true
            uploadProgress = 0
            
            let response = try await api.uploadDatasetStandard(zipURL: zipURL) { progress in
                self.uploadProgress = progress
            }
            
            lastDatasetId = response.datasetId
            isUploading = false
            
            // Cleanup temp zip
            try? FileManager.default.removeItem(at: zipURL)
            
            showSuccessMessage("Dataset uploaded successfully! ID: \(response.datasetId)")
        } catch {
            isCreatingZIP = false
            isUploading = false
            showErrorMessage(error.localizedDescription)
        }
    }
    
    // MARK: - EXR Generation
    
    func generateEXRAndUpload(session: RecordedSession) async {
        guard let videoURL = session.videoURL else {
            showErrorMessage("No video file found for EXR conversion.")
            return
        }
        
        isGeneratingEXR = true
        exrGenerationProgress = 0
        
        let exportService = ExportService()
        let rgbDir = session.directory.appendingPathComponent("rgb")
        
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            exportService.convertVideoToEXR(
                videoURL: videoURL,
                outputDirectory: rgbDir,
                progress: { progress in
                    self.exrGenerationProgress = progress
                },
                completion: { result in
                    self.isGeneratingEXR = false
                    self.exrGenerationProgress = 0
                    
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        self.showErrorMessage("EXR generation failed: \(error.localizedDescription)")
                        continuation.resume()
                    }
                }
            )
        }
        
        // Re-read sessions to get updated hasEXR state
        let updatedSessions = CaptureSession.listSessions()
        if let updatedSession = updatedSessions.first(where: { $0.id == session.id }), updatedSession.hasEXR {
            await performUpload(session: updatedSession)
        } else if !isGeneratingEXR {
            // Only show error if generation didn't already report a failure
            showErrorMessage("EXR generation completed but no EXR files were found. Upload aborted.")
        }
    }
    
    // MARK: - Processing
    
    func startProcessing(datasetId: String? = nil) async {
        guard let id = datasetId ?? lastDatasetId else {
            showErrorMessage("No dataset uploaded yet. Please upload a dataset first.")
            return
        }
        
        isStartingProcess = true
        
        do {
            let response = try await api.startProcessing(datasetId: id, settings: processingSettings)
            activeJobId = response.jobId
            isStartingProcess = false
            
            showSuccessMessage("Processing started! Job ID: \(response.jobId)")
            
            // Start polling
            startPolling(jobId: response.jobId)
            
            // Refresh job list
            await refreshJobs()
        } catch {
            isStartingProcess = false
            showErrorMessage(error.localizedDescription)
        }
    }
    
    // MARK: - Job Status Polling
    
    func startPolling(jobId: String) {
        stopPolling()
        activeJobId = jobId
        isPolling = true
        
        pollingTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            // Immediate first poll
            await self.pollJobStatus()
            
            while !Task.isCancelled && self.isPolling {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                guard !Task.isCancelled && self.isPolling else { break }
                await self.pollJobStatus()
            }
        }
    }
    
    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
        isPolling = false
    }
    
    private func pollJobStatus() async {
        guard let jobId = activeJobId else { return }
        
        do {
            let status = try await api.jobStatus(jobId: jobId)
            activeJobStatus = status
            
            let parsedStatus = ReMapJobStatus(rawValue: status.status)
            if parsedStatus?.isTerminal == true {
                stopPolling()
                await refreshJobs()
                
                if parsedStatus == .completed {
                    showSuccessMessage("Job completed successfully!")
                } else if parsedStatus == .failed {
                    showErrorMessage("Job failed: \(status.message ?? "Unknown error")")
                }
            }
        } catch {
            // Don't stop polling on transient errors
            print("[ReMapVM] Poll error: \(error)")
        }
    }
    
    // MARK: - Jobs List
    
    func refreshJobs() async {
        do {
            jobs = try await api.listJobs()
        } catch {
            print("[ReMapVM] List jobs error: \(error)")
        }
    }
    
    // MARK: - Logs
    
    func loadLogs(jobId: String) async {
        isLoadingLogs = true
        defer { isLoadingLogs = false }
        
        do {
            let response = try await api.jobLogs(jobId: jobId)
            jobLogs = response.logs
        } catch {
            showErrorMessage("Failed to load logs: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Download
    
    func downloadResult(jobId: String) async {
        isDownloading = true
        downloadProgress = 0
        
        // Sanitize jobId to only allow alphanumeric characters and hyphens
        let safeJobId = jobId.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        guard !safeJobId.isEmpty else {
            isDownloading = false
            showErrorMessage("Invalid job ID.")
            return
        }
        
        do {
            guard let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw ReMapAPIError.invalidResponse
            }
            let resultDir = documentsDir.appendingPathComponent("ReMap_Results")
            try FileManager.default.createDirectory(at: resultDir, withIntermediateDirectories: true)
            
            let destURL = resultDir.appendingPathComponent("result_\(safeJobId).zip")
            let url = try await api.downloadResult(jobId: safeJobId, to: destURL)
            lastDownloadedURL = url
            isDownloading = false
            showSuccessMessage("Result downloaded to Files app.")
        } catch {
            isDownloading = false
            showErrorMessage("Download failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Cancel
    
    func cancelJob(jobId: String) async {
        do {
            try await api.cancelJob(jobId: jobId)
            if activeJobId == jobId {
                stopPolling()
                activeJobStatus = nil
                activeJobId = nil
            }
            await refreshJobs()
            showSuccessMessage("Job cancelled.")
        } catch {
            showErrorMessage("Failed to cancel job: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Presets
    
    func applyPreset(_ preset: ReMapProcessingSettings) {
        processingSettings = preset
    }
    
    // MARK: - Error/Success Helpers
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    private func showSuccessMessage(_ message: String) {
        successMessage = message
        showSuccess = true
    }
}
