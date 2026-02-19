// CaptureViewModel.swift
// DIETCapture
//
// Orchestrates recording: synchronizes RGB + LiDAR capture, manages sessions, exports data.

import Foundation
import AVFoundation
import ARKit
import Combine

@Observable
final class CaptureViewModel {
    
    // MARK: - Sub-ViewModels
    
    let camera = CameraViewModel()
    let lidar = LiDARViewModel()
    
    // MARK: - Session
    
    let session = CaptureSession()
    var settings = SessionSettings()
    
    // MARK: - Services
    
    private let exportService = ExportService()
    
    // MARK: - State
    
    var isRecording: Bool { session.state == .recording }
    var isSaving: Bool { session.state == .saving }
    var errorMessage: String?
    var showError: Bool = false
    
    // Performance Monitoring
    var thermalState: ProcessInfo.ThermalState { camera.capabilities.thermalState }
    var batteryPercentage: Int { camera.capabilities.batteryPercentage }
    var storageAvailableMB: Double { session.availableStorageMB }
    
    var elapsedTimeString: String { session.elapsedTime.recordingDurationString }
    var frameCountString: String { "\(session.frameCount)" }
    
    // Timer
    private var recordingTimer: Timer?
    
    // Export queue
    private let exportQueue = DispatchQueue(label: "com.dietcapture.capturevm.export", qos: .utility)
    
    // MARK: - Setup
    
    func setup() {
        camera.setup()
        lidar.start()
        session.updateStorageInfo()
        
        // Wire up AR frame callback for synchronized capture
        lidar.arService.onFrameUpdate = { [weak self] frame in
            self?.handleARFrame(frame)
        }
    }
    
    func teardown() {
        stopRecording()
        camera.teardown()
        lidar.stop()
        recordingTimer?.invalidate()
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto() {
        camera.cameraService.onPhotoCaptured = { [weak self] data, error in
            guard let self = self else { return }
            
            if let error = error {
                self.showError(message: "Photo capture failed: \(error.localizedDescription)")
                return
            }
            
            guard let imageData = data else { return }
            
            // Save photo + current depth/confidence/pose
            self.exportQueue.async {
                self.savePhotoFrame(imageData: imageData)
            }
        }
        
        camera.capturePhoto()
    }
    
    // MARK: - Video Recording
    
    func startRecording() {
        do {
            let sessionDir = try session.createSessionDirectory()
            session.startRecording()
            
            // Start video recording
            let videoURL = sessionDir.appendingPathComponent("video/capture.mov")
            camera.startRecording(to: videoURL)
            
            // Start timer
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.session.updateElapsedTime()
                self?.session.updateStorageInfo()
            }
            
            // Check storage
            if storageAvailableMB < 1024 {
                showError(message: "⚠️ Less than 1 GB storage remaining")
            }
            
        } catch {
            showError(message: "Failed to create session directory: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        session.stopRecording()
        camera.stopRecording()
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Finalize exports
        exportQueue.async { [weak self] in
            self?.finalizeSession()
        }
    }
    
    // MARK: - AR Frame Handling (Synchronized Capture)
    
    private func handleARFrame(_ frame: ARFrame) {
        guard session.state == .recording else { return }
        
        let frameIndex = session.frameCount
        let timestamp = frame.timestamp
        
        // Extract data
        let pose = frame.camera.transform
        let intrinsics = frame.camera.intrinsics
        let trackingState: String = {
            switch frame.camera.trackingState {
            case .normal: return "normal"
            case .notAvailable: return "notAvailable"
            case .limited(let reason):
                switch reason {
                case .initializing: return "initializing"
                case .excessiveMotion: return "excessiveMotion"
                case .insufficientFeatures: return "insufficientFeatures"
                case .relocalizing: return "relocalizing"
                @unknown default: return "limited"
                }
            }
        }()
        
        // Create frame metadata
        let metadata = CaptureFrameMetadata(
            frameIndex: frameIndex,
            timestamp: timestamp,
            cameraPose: pose.flatArray,
            cameraIntrinsics: intrinsics.flatArray,
            exposureDuration: CMTimeGetSeconds(camera.settings.shutterSpeed),
            iso: camera.settings.iso,
            lensPosition: camera.settings.manualFocusPosition,
            trackingState: trackingState
        )
        
        // Add to session
        DispatchQueue.main.async {
            self.session.addFrame(metadata: metadata)
        }
        
        // Export frame data asynchronously
        exportQueue.async { [weak self] in
            guard let self = self else { return }
            self.exportFrameData(
                frame: frame,
                frameIndex: frameIndex,
                pose: pose,
                intrinsics: intrinsics
            )
        }
    }
    
    // MARK: - Frame Export
    
    private func exportFrameData(
        frame: ARFrame,
        frameIndex: Int,
        pose: simd_float4x4,
        intrinsics: simd_float3x3
    ) {
        let frameName = session.frameName(for: frameIndex)
        
        // Save depth map
        if let depthMap = frame.sceneDepth?.depthMap {
            if let depthCopy = DepthMapProcessor.copyDepthMap(depthMap) {
                DepthMapProcessor.filterByDistance(depthCopy, maxDistance: settings.lidar.maxDistance)
                
                if let confidenceMap = frame.sceneDepth?.confidenceMap,
                   let confCopy = DepthMapProcessor.copyDepthMap(confidenceMap) {
                    DepthMapProcessor.filterByConfidence(
                        depth: depthCopy,
                        confidence: confCopy,
                        threshold: settings.lidar.confidenceThreshold
                    )
                }
                
                switch settings.camera.depthExportFormat {
                case .png16:
                    if let url = session.depthURL(for: frameIndex, extension: "png") {
                        exportService.saveDepthMap16BitPNG(depthCopy, to: url)
                    }
                case .tiff32:
                    if let url = session.depthURL(for: frameIndex, extension: "tiff") {
                        exportService.saveDepthMap32BitTIFF(depthCopy, to: url)
                    }
                case .exr:
                    if let url = session.depthURL(for: frameIndex, extension: "exr") {
                        exportService.saveDepthMapEXR(depthCopy, to: url)
                    }
                }
            }
        }
        
        // Save confidence map
        if let confidenceMap = frame.sceneDepth?.confidenceMap,
           let url = session.confidenceURL(for: frameIndex) {
            if let confCopy = DepthMapProcessor.copyDepthMap(confidenceMap) {
                exportService.saveConfidenceMap(confCopy, to: url)
            }
        }
        
        // Save pose
        if settings.exportPoses, let url = session.poseURL(for: frameIndex) {
            exportService.savePose(pose, to: url)
        }
        
        // Save intrinsics (every 30 frames to avoid excessive I/O)
        if settings.exportIntrinsics && frameIndex % 30 == 0 {
            if let metaDir = session.metadataDirectory {
                let url = metaDir.appendingPathComponent("intrinsics_\(frameName).json")
                exportService.saveIntrinsics(intrinsics, frameIndex: frameIndex, to: url)
            }
        }
        
        // Point cloud (every 10 frames to manage I/O load)
        if settings.lidar.exportPointClouds && frameIndex % 10 == 0 {
            if let depthMap = frame.sceneDepth?.depthMap,
               let url = session.pointCloudURL(for: frameIndex) {
                let points = lidar.arService.generatePointCloud(
                    depthMap: depthMap,
                    confidenceMap: frame.sceneDepth?.confidenceMap,
                    intrinsics: intrinsics,
                    cameraPose: pose,
                    maxDistance: settings.lidar.maxDistance,
                    confidenceThreshold: settings.lidar.confidenceThreshold
                )
                exportService.savePointCloudPLY(points: points, to: url)
            }
        }
    }
    
    // MARK: - Photo Frame Save
    
    private func savePhotoFrame(imageData: Data) {
        let frameIndex = session.frameCount
        
        do {
            if session.sessionDirectory == nil {
                _ = try session.createSessionDirectory()
            }
        } catch {
            showError(message: "Directory creation failed: \(error.localizedDescription)")
            return
        }
        
        // Save RGB
        let ext: String
        switch settings.camera.photoFormat {
        case .heif: ext = "heif"
        case .jpeg: ext = "jpg"
        case .proRAW: ext = "dng"
        }
        
        if let url = session.rgbURL(for: frameIndex, extension: ext) {
            exportService.saveRGBImage(imageData, to: url)
        }
        
        // Save accompanying depth/pose 
        let pose = lidar.currentPose
        let intrinsics = lidar.currentIntrinsics
        
        if let depthMap = lidar.currentDepthMap,
           let depthCopy = DepthMapProcessor.copyDepthMap(depthMap) {
            if let url = session.depthURL(for: frameIndex, extension: settings.camera.depthExportFormat.fileExtension) {
                switch settings.camera.depthExportFormat {
                case .png16:
                    exportService.saveDepthMap16BitPNG(depthCopy, to: url)
                case .tiff32:
                    exportService.saveDepthMap32BitTIFF(depthCopy, to: url)
                case .exr:
                    exportService.saveDepthMapEXR(depthCopy, to: url)
                }
            }
        }
        
        if let url = session.poseURL(for: frameIndex) {
            exportService.savePose(pose, to: url)
        }
        
        let metadata = CaptureFrameMetadata(
            frameIndex: frameIndex,
            timestamp: Date().timeIntervalSince1970,
            cameraPose: pose.flatArray,
            cameraIntrinsics: intrinsics.flatArray,
            exposureDuration: CMTimeGetSeconds(settings.camera.shutterSpeed),
            iso: settings.camera.iso,
            lensPosition: settings.camera.manualFocusPosition,
            trackingState: lidar.trackingStateString
        )
        
        DispatchQueue.main.async {
            self.session.addFrame(metadata: metadata)
        }
    }
    
    // MARK: - Session Finalization
    
    private func finalizeSession() {
        guard let colmapDir = session.colmapDirectory else { return }
        
        // Export COLMAP
        if settings.exportCOLMAP {
            do {
                // Use the last known intrinsics and a representative image size
                let intrinsics = lidar.currentIntrinsics
                let depthRes = lidar.arService.depthMapResolution
                
                // Image resolution from camera (approximate from depth res ratio)
                let imageWidth = 1920  // Default; could read from actual capture
                let imageHeight = 1440
                
                let ext: String
                switch settings.camera.photoFormat {
                case .heif: ext = "heif"
                case .jpeg: ext = "jpg"
                case .proRAW: ext = "dng"
                }
                
                try COLMAPExporter.exportAll(
                    frames: session.frameMetadata,
                    intrinsics: intrinsics,
                    imageWidth: imageWidth,
                    imageHeight: imageHeight,
                    imageExtension: ext,
                    to: colmapDir
                )
            } catch {
                print("[CaptureVM] COLMAP export error: \(error)")
            }
        }
        
        // Export session info
        do {
            try session.exportSessionInfo(
                settings: settings,
                deviceName: camera.capabilities.deviceName
            )
        } catch {
            print("[CaptureVM] Session info export error: \(error)")
        }
        
        // Export mesh
        if settings.lidar.exportMesh {
            let anchors = lidar.meshAnchors
            if let meshDir = session.meshDirectory {
                let objURL = meshDir.appendingPathComponent("scene_mesh.obj")
                exportService.saveMeshOBJ(meshAnchors: anchors, to: objURL)
            }
        }
        
        DispatchQueue.main.async {
            self.session.finishSaving()
        }
    }
    
    // MARK: - Thermal Throttling
    
    func checkThermalState() {
        switch thermalState {
        case .serious:
            // Reduce framerate
            camera.setFrameRate(min(settings.camera.targetFramerate, 30))
            showError(message: "⚠️ Device is hot. Reducing framerate.")
        case .critical:
            // Force stop recording
            if isRecording {
                stopRecording()
                showError(message: "🛑 Critical temperature. Recording stopped.")
            }
        default:
            break
        }
    }
    
    // MARK: - Error Handling
    
    private func showError(message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.showError = true
        }
    }
}
