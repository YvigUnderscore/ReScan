// CaptureViewModel.swift
// ReScan
//
// Orchestrates recording: ARKit frames → Stray Scanner format export.

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
    
    // MARK: - State
    
    var isRecording: Bool { session.state == .recording }
    var isSaving: Bool { session.state == .saving }
    var errorMessage: String?
    var showError: Bool = false
    
    // Performance
    var thermalState: ProcessInfo.ThermalState { camera.capabilities.thermalState }
    var batteryPercentage: Int { camera.capabilities.batteryPercentage }
    var storageAvailableMB: Double { session.availableStorageMB }
    
    var elapsedTimeString: String { session.elapsedTime.recordingDurationString }
    var frameCountString: String { "\(session.frameCount)" }
    
    // Timer
    private var recordingTimer: Timer?
    
    // Export queue
    private let exportQueue = DispatchQueue(label: "com.rescan.capturevm.export", qos: .utility)
    
    // Intrinsics saved flag
    private var intrinsicsSaved = false
    
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
    
    // MARK: - Recording
    
    func startRecording() {
        do {
            let sessionDir = try session.createSessionDirectory()
            session.startRecording()
            intrinsicsSaved = false
            
            // We start video recording when we get the first frame (need dimensions)
            // Open odometry CSV
            if let odometryURL = session.odometryURL {
                exportService.openOdometryFile(at: odometryURL)
            }
            
            // Start timer
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.session.updateElapsedTime()
                self?.session.updateStorageInfo()
            }
            
            if storageAvailableMB < 1024 {
                showError(message: "⚠️ Less than 1 GB storage remaining")
            }
            
        } catch {
            showError(message: "Failed to create session: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        session.stopRecording()
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        // Close odometry
        exportService.closeOdometryFile()
        
        // Finish video
        exportService.finishVideoRecording { [weak self] in
            DispatchQueue.main.async {
                self?.session.finishSaving()
            }
        }
    }
    
    // MARK: - AR Frame Handling
    
    private func handleARFrame(_ frame: ARFrame) {
        guard session.state == .recording else { return }
        
        let frameIndex = session.frameCount
        let timestamp = frame.timestamp
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
                    try exportService.startVideoRecording(to: videoURL, width: width, height: height)
                } catch {
                    print("[CaptureVM] Video start error: \(error)")
                }
            }
        }
        
        // Append video frame
        exportService.appendVideoFrame(capturedImage, timestamp: timestamp)
        
        // Append odometry
        exportService.appendOdometry(timestamp: timestamp, frame: frameIndex, pose: pose)
        
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
                self.exportService.saveDepthMap16BitPNG(depthCopy, to: url)
            }
            
            // Save confidence map
            if let confMap = frame.sceneDepth?.confidenceMap,
               let confCopy = DepthMapProcessor.copyDepthMap(confMap),
               let url = self.session.confidenceURL(for: frameIndex) {
                self.exportService.saveConfidenceMap(confCopy, to: url)
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
