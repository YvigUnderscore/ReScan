// CaptureViewModel.swift
// ReScan
//
// Orchestrates recording: ARKit frames → Stray Scanner format export.
// Handles FPS subsampling — ARKit runs at native rate, only selected frames are captured.

import Foundation
import AVFoundation
import ARKit
import Combine

@Observable
final class CaptureViewModel {
    
    // MARK: - Sub-ViewModels
    
    var camera = CameraViewModel()
    var lidar = LiDARViewModel()
    
    // MARK: - Session
    
    let session = CaptureSession()
    var settings = SessionSettings()
    
    // MARK: - Services
    
    private let exportService = ExportService()
    
    /// Adaptive mesh refinement service — created when refinement is enabled.
    private var meshRefinement: AdaptiveMeshRefinement?
    
    // MARK: - State
    
    var isRecording: Bool { session.state == .recording }
    var isSaving: Bool { session.state == .saving }
    /// True while the app has queued a recording start but is waiting for the first mesh polygons.
    var isWaitingForMesh: Bool = false
    var errorMessage: String?
    var showError: Bool = false
    
    // Performance
    var thermalState: ProcessInfo.ThermalState { camera.capabilities.thermalState }
    var batteryPercentage: Int { camera.capabilities.batteryPercentage }
    var storageAvailableMB: Double { session.availableStorageMB }
    
    var elapsedTimeString: String { session.elapsedTime.recordingDurationString }
    var frameCountString: String { "\(session.frameCount)" }
    
    // Active encoding mode (resolved at recording start)
    var activeEncodingMode: VideoEncodingMode = .standardHEVC
    
    // Timer
    private var recordingTimer: Timer?
    
    // Export queue
    private let exportQueue = DispatchQueue(label: "com.rescan.capturevm.export", qos: .utility)
    
    // Intrinsics saved flag
    private var intrinsicsSaved = false
    
    // FPS subsampling
    private var lastCaptureTimestamp: TimeInterval = -1
    private var captureInterval: TimeInterval = 1.0 / 30.0 // Default 30fps
    
    // MARK: - Computed
    
    /// Whether Apple Log (ProRes) is available on this device
    var supportsAppleLog: Bool {
        ExportService.supportsAppleLog
    }
    
    // MARK: - Setup
    
    func setup() {
        lidar.start()
        session.updateStorageInfo()
        
        // Apply User Defaults
        let defaults = AppSettings.shared
        lidar.settings.maxDistance = Float(defaults.defaultMaxDistance)
        if let conf = ConfidenceThreshold(rawValue: defaults.defaultConfidence) {
            lidar.settings.confidenceThreshold = conf
        }
        lidar.settings.smoothingEnabled = defaults.defaultSmoothing
        
        // Attach camera controls to ARKit's device
        camera.setup(device: lidar.arService.captureDevice)
        
        // Wire up AR frame callback
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
    
    // MARK: - Encoding Mode Resolution
    
    /// Determines the actual encoding mode based on settings and device capabilities
    private func resolveEncodingMode() -> VideoEncodingMode {
        let settings = AppSettings.shared
        
        // EXR conversion is now performed manually from the media library after capture.
        // Always record as video for better performance and lower resource usage during capture.
        if settings.useAppleLog {
            if supportsAppleLog {
                return .appleLog
            } else {
                print("[CaptureVM] Apple Log not supported on this device, falling back to HDR HEVC")
                return settings.enableHDR ? .hdrHEVC : .standardHEVC
            }
        } else if settings.enableHDR {
            return .hdrHEVC
        } else {
            return .standardHEVC
        }
    }
    
    // MARK: - Recording
    
    func startRecording() {
        guard !isRecording && !isWaitingForMesh else { return }
        do {
            // Resolve encoding mode
            activeEncodingMode = resolveEncodingMode()
            session.encodingMode = activeEncodingMode
            
            // Set capture FPS interval
            let appSettings = AppSettings.shared
            captureInterval = appSettings.captureFPS.captureInterval
            lastCaptureTimestamp = -1
            
            _ = try session.createSessionDirectory()
            
            // Initialize adaptive mesh refinement if enabled
            if appSettings.adaptiveMeshRefinement {
                meshRefinement = AdaptiveMeshRefinement(detailLevel: appSettings.meshDetailLevel)
            } else {
                meshRefinement = nil
            }
            
            if appSettings.meshStartMode == .bruteForce {
                beginCapture()
            } else {
                // WaitForPolygons: defer actual start until first mesh anchors arrive
                isWaitingForMesh = true
            }
            
        } catch {
            showError(message: "Failed to create session: \(error.localizedDescription)")
        }
    }
    
    /// Performs the actual recording start (opens video writer, odometry file, starts timer).
    /// Called either immediately (BruteForce) or upon first mesh polygon detection.
    private func beginCapture() {
        isWaitingForMesh = false
        session.startRecording()
        intrinsicsSaved = false
        
        // Open odometry CSV
        if let odometryURL = session.odometryURL {
            exportService.openOdometryFile(at: odometryURL)
        }
        
        // Start timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.session.updateElapsedTime()
            self?.session.updateStorageInfo()
        }
        
        let appSettings = AppSettings.shared
        if storageAvailableMB < 1024 {
            showError(message: "⚠️ Less than 1 GB storage remaining")
        }
        
        print("[CaptureVM] Recording started — \(appSettings.captureFPS.label), encoding: \(activeEncodingMode.label)")
    }
    
    func stopRecording() {
        // Cancel pending "wait for mesh" state
        if isWaitingForMesh {
            isWaitingForMesh = false
            // Clean up the session directory that was pre-created
            if let dir = session.sessionDirectory {
                try? FileManager.default.removeItem(at: dir)
                session.sessionDirectory = nil
            }
            return
        }
        
        guard isRecording else { return }
        
        // Hide ghost mesh overlay immediately so it is not visible in subsequent scans
        lidar.ghostMeshEnabled = false
        
        session.stopRecording()
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Close odometry
        exportService.closeOdometryFile()
        
        // Export mesh if available
        let meshAnchors = lidar.meshAnchors
        if !meshAnchors.isEmpty, let meshURL = session.meshURL {
            if let refinement = meshRefinement {
                // Export adaptively refined mesh
                let (vertices, faces) = refinement.buildRefinedMesh(from: meshAnchors)
                exportService.exportRefinedMeshAsOBJ(vertices: vertices, faces: faces, to: meshURL)
                let stats = refinement.statistics
                print("[CaptureVM] Refined mesh: \(stats.totalVertices) verts, \(stats.totalFaces) faces, \(stats.refinedRegions) refined regions")
            } else {
                exportService.exportMeshAsOBJ(anchors: meshAnchors, to: meshURL)
            }
        }
        
        // Clean up refinement service
        meshRefinement?.reset()
        meshRefinement = nil
        
        // Finish video
        exportService.finishVideoRecording { [weak self] in
            DispatchQueue.main.async {
                self?.session.finishSaving()
            }
        }
    }
    
    // MARK: - AR Frame Handling
    
    private func handleARFrame(_ frame: ARFrame) {
        // While waiting for the first mesh polygons, watch for their arrival and then begin capture.
        if isWaitingForMesh {
            let hasMeshAnchors = frame.anchors.contains { $0 is ARMeshAnchor }
            if hasMeshAnchors {
                beginCapture()
            }
            return
        }
        
        guard session.state == .recording else { return }
        
        let timestamp = frame.timestamp
        
        // FPS subsampling: skip frames that are too close together
        if lastCaptureTimestamp >= 0 {
            let elapsed = timestamp - lastCaptureTimestamp
            if elapsed < captureInterval * 0.9 { // 0.9 factor for tolerance
                return
            }
        }
        lastCaptureTimestamp = timestamp
        
        let frameIndex = session.frameCount
        let pose = frame.camera.transform
        let intrinsics = frame.camera.intrinsics
        let capturedImage = frame.capturedImage
        
        // Save intrinsics once
        if !intrinsicsSaved {
            intrinsicsSaved = true
            if let url = session.cameraMatrixURL {
                exportService.saveCameraMatrix(intrinsics, to: url)
            }
            
            // Start video writer with actual frame dimensions
            let width = CVPixelBufferGetWidth(capturedImage)
            let height = CVPixelBufferGetHeight(capturedImage)
            if let videoURL = session.videoURL {
                do {
                    try exportService.startVideoRecording(
                        to: videoURL,
                        width: width,
                        height: height,
                        encodingMode: activeEncodingMode
                    )
                } catch {
                    print("[CaptureVM] Video start error: \(error)")
                }
            }
        }
        
        // Append video frame
        exportService.appendVideoFrame(capturedImage, timestamp: timestamp)
        
        // Append odometry
        exportService.appendOdometry(timestamp: timestamp, frame: frameIndex, pose: pose)
        
        // Record mesh observations for adaptive refinement
        if let refinement = meshRefinement {
            let anchors = frame.anchors.compactMap { $0 as? ARMeshAnchor }
            if !anchors.isEmpty {
                refinement.recordObservations(anchors: anchors, timestamp: timestamp)
            }
        }
        
        // Tracking state
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
        
        DispatchQueue.main.async {
            self.session.addFrame(metadata: metadata)
        }
        
        // Export depth and confidence asynchronously
        exportQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Save depth map (16-bit PNG in mm)
            if let depthMap = frame.sceneDepth?.depthMap,
               let depthCopy = DepthMapProcessor.copyDepthMap(depthMap),
               let url = self.session.depthURL(for: frameIndex) {
                DepthMapProcessor.filterByDistance(depthCopy, maxDistance: self.settings.lidar.maxDistance)
                self.exportService.saveDepthMap16BitPNG(depthCopy, to: url) { result in
                    if case .failure(let error) = result {
                        print("[CaptureVM] Depth export error: \(error)")
                    }
                }
            }
            
            // Save confidence map
            if let confMap = frame.sceneDepth?.confidenceMap,
               let confCopy = DepthMapProcessor.copyDepthMap(confMap),
               let url = self.session.confidenceURL(for: frameIndex) {
                self.exportService.saveConfidenceMap(confCopy, to: url) { result in
                    if case .failure(let error) = result {
                        print("[CaptureVM] Confidence export error: \(error)")
                    }
                }
            }
        }
    }
    
    // MARK: - Thermal
    
    func checkThermalState() {
        switch thermalState {
        case .critical:
            if isRecording {
                stopRecording()
                showError(message: "🛑 Critical temperature. Recording stopped.")
            }
        default:
            break
        }
    }
    
    // MARK: - Error
    
    private func showError(message: String) {
        DispatchQueue.main.async {
            self.errorMessage = message
            self.showError = true
        }
    }
}
