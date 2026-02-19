// CameraService.swift
// DIETCapture
//
// AVFoundation camera control: exposure, focus, white balance, zoom, capture.

import Foundation
import AVFoundation
import UIKit
import Combine

@Observable
final class CameraService: NSObject {
    
    // MARK: - Session
    
    let captureSession = AVCaptureSession()
    private(set) var currentDevice: AVCaptureDevice?
    private var deviceInput: AVCaptureDeviceInput?
    
    // Outputs
    let photoOutput = AVCapturePhotoOutput()
    let movieOutput = AVCaptureMovieFileOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    
    // Preview
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    
    // State
    var isSessionRunning = false
    var isRecording = false
    var currentISO: Float = 100
    var currentShutterSpeed: CMTime = CMTimeMake(value: 1, timescale: 60)
    var currentEV: Float = 0
    var currentFocusPosition: Float = 0.5
    var currentZoomFactor: CGFloat = 1.0
    
    // Ranges (populated from active format)
    var minISO: Float = 32
    var maxISO: Float = 3200
    var minShutterSpeed: CMTime = CMTimeMake(value: 1, timescale: 8000)
    var maxShutterSpeed: CMTime = CMTimeMake(value: 1, timescale: 3)
    var minEV: Float = -8.0
    var maxEV: Float = 8.0
    
    // Callbacks
    var onVideoFrame: ((CMSampleBuffer) -> Void)?
    var onPhotoCaptured: ((Data?, Error?) -> Void)?
    var onRecordingFinished: ((URL?, Error?) -> Void)?
    
    // Queues
    private let sessionQueue = DispatchQueue(label: "com.dietcapture.camera.session")
    private let videoOutputQueue = DispatchQueue(label: "com.dietcapture.camera.videodata")
    
    // MARK: - Setup
    
    func setupSession(preferredLens: LensType = .wide) {
        sessionQueue.async { [weak self] in
            self?.configureSession(preferredLens: preferredLens)
        }
    }
    
    private func configureSession(preferredLens: LensType) {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo
        
        // Select camera device
        guard let device = selectDevice(for: preferredLens) else {
            captureSession.commitConfiguration()
            return
        }
        
        currentDevice = device
        
        // Input
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
                deviceInput = input
            }
        } catch {
            print("[CameraService] Failed to create device input: \(error)")
            captureSession.commitConfiguration()
            return
        }
        
        // Photo output
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
            
            // Enable ProRAW if supported
            if photoOutput.isAppleProRAWSupported {
                photoOutput.isAppleProRAWEnabled = true
            }
        }
        
        // Movie output
        if captureSession.canAddOutput(movieOutput) {
            captureSession.addOutput(movieOutput)
        }
        
        // Video data output (for frame-by-frame processing)
        videoDataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        videoDataOutput.setSampleBufferDelegate(self, queue: videoOutputQueue)
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
        }
        
        captureSession.commitConfiguration()
        
        // Update ranges
        updateDeviceRanges()
        
        // Start
        captureSession.startRunning()
        DispatchQueue.main.async {
            self.isSessionRunning = true
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            self?.captureSession.stopRunning()
            DispatchQueue.main.async {
                self?.isSessionRunning = false
            }
        }
    }
    
    // MARK: - Device Selection
    
    private func selectDevice(for lens: LensType) -> AVCaptureDevice? {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInUltraWideCamera,
                .builtInWideAngleCamera,
                .builtInTelephotoCamera
            ],
            mediaType: .video,
            position: .back
        )
        
        // Try to find exact match
        for device in discoverySession.devices {
            if device.deviceType == lens.deviceType {
                return device
            }
        }
        
        // Fallback to wide angle
        return AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    }
    
    func switchLens(_ lens: LensType) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            guard let newDevice = self.selectDevice(for: lens) else { return }
            guard newDevice.uniqueID != self.currentDevice?.uniqueID else { return }
            
            self.captureSession.beginConfiguration()
            
            // Remove old input
            if let oldInput = self.deviceInput {
                self.captureSession.removeInput(oldInput)
            }
            
            // Add new input
            do {
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if self.captureSession.canAddInput(newInput) {
                    self.captureSession.addInput(newInput)
                    self.deviceInput = newInput
                    self.currentDevice = newDevice
                }
            } catch {
                print("[CameraService] Lens switch failed: \(error)")
                // Re-add old input
                if let oldDevice = self.currentDevice,
                   let oldInput = try? AVCaptureDeviceInput(device: oldDevice),
                   self.captureSession.canAddInput(oldInput) {
                    self.captureSession.addInput(oldInput)
                    self.deviceInput = oldInput
                }
            }
            
            self.captureSession.commitConfiguration()
            self.updateDeviceRanges()
        }
    }
    
    // MARK: - Ranges Update
    
    private func updateDeviceRanges() {
        guard let device = currentDevice else { return }
        let format = device.activeFormat
        
        DispatchQueue.main.async {
            self.minISO = format.minISO
            self.maxISO = format.maxISO
            self.minShutterSpeed = format.minExposureDuration
            self.maxShutterSpeed = format.maxExposureDuration
            self.minEV = device.minExposureTargetBias
            self.maxEV = device.maxExposureTargetBias
        }
    }
    
    // MARK: - Exposure Controls
    
    func setManualExposure(shutterSpeed: CMTime, iso: Float) {
        guard let device = currentDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                let clampedISO = max(device.activeFormat.minISO,
                                     min(iso, device.activeFormat.maxISO))
                let clampedDuration = self.clampShutterSpeed(shutterSpeed, device: device)
                device.setExposureModeCustom(
                    duration: clampedDuration,
                    iso: clampedISO,
                    completionHandler: nil
                )
                device.unlockForConfiguration()
                
                DispatchQueue.main.async {
                    self.currentISO = clampedISO
                    self.currentShutterSpeed = clampedDuration
                }
            } catch {
                print("[CameraService] Exposure error: \(error)")
            }
        }
    }
    
    func setExposureMode(_ mode: ExposureMode) {
        guard let device = currentDevice else { return }
        guard device.isExposureModeSupported(mode.avMode) else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.exposureMode = mode.avMode
                device.unlockForConfiguration()
            } catch {
                print("[CameraService] Exposure mode error: \(error)")
            }
        }
    }
    
    func setExposureCompensation(_ ev: Float) {
        guard let device = currentDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                let clamped = max(device.minExposureTargetBias,
                                  min(ev, device.maxExposureTargetBias))
                device.setExposureTargetBias(clamped, completionHandler: nil)
                device.unlockForConfiguration()
                
                DispatchQueue.main.async {
                    self.currentEV = clamped
                }
            } catch {
                print("[CameraService] EV error: \(error)")
            }
        }
    }
    
    private func clampShutterSpeed(_ speed: CMTime, device: AVCaptureDevice) -> CMTime {
        let minDuration = device.activeFormat.minExposureDuration
        let maxDuration = device.activeFormat.maxExposureDuration
        let seconds = CMTimeGetSeconds(speed)
        let clamped = max(CMTimeGetSeconds(minDuration),
                          min(seconds, CMTimeGetSeconds(maxDuration)))
        return CMTimeMakeWithSeconds(clamped, preferredTimescale: 1000000)
    }
    
    // MARK: - Focus Controls
    
    func setFocusMode(_ mode: FocusMode, lensPosition: Float? = nil) {
        guard let device = currentDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                
                switch mode {
                case .manual:
                    let position = max(0.0, min(lensPosition ?? 0.5, 1.0))
                    device.setFocusModeLocked(lensPosition: position, completionHandler: nil)
                    DispatchQueue.main.async {
                        self.currentFocusPosition = position
                    }
                case .auto:
                    if device.isFocusModeSupported(.autoFocus) {
                        device.focusMode = .autoFocus
                    }
                case .autoContinuous:
                    if device.isFocusModeSupported(.continuousAutoFocus) {
                        device.focusMode = .continuousAutoFocus
                    }
                }
                
                device.unlockForConfiguration()
            } catch {
                print("[CameraService] Focus error: \(error)")
            }
        }
    }
    
    func setManualFocus(position: Float) {
        setFocusMode(.manual, lensPosition: position)
    }
    
    // MARK: - White Balance
    
    func setAutoWhiteBalance() {
        guard let device = currentDevice else { return }
        guard device.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.whiteBalanceMode = .continuousAutoWhiteBalance
                device.unlockForConfiguration()
            } catch {
                print("[CameraService] WB error: \(error)")
            }
        }
    }
    
    func setManualWhiteBalance(temperature: Float, tint: Float) {
        guard let device = currentDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                let temperatureAndTint = AVCaptureDevice.WhiteBalanceTemperatureAndTintValues(
                    temperature: temperature,
                    tint: tint
                )
                let gains = device.deviceWhiteBalanceGains(for: temperatureAndTint)
                let clampedGains = self.clampWhiteBalanceGains(gains, device: device)
                device.setWhiteBalanceModeLocked(with: clampedGains, completionHandler: nil)
                device.unlockForConfiguration()
            } catch {
                print("[CameraService] WB manual error: \(error)")
            }
        }
    }
    
    private func clampWhiteBalanceGains(
        _ gains: AVCaptureDevice.WhiteBalanceGains,
        device: AVCaptureDevice
    ) -> AVCaptureDevice.WhiteBalanceGains {
        let maxGain = device.maxWhiteBalanceGain
        return AVCaptureDevice.WhiteBalanceGains(
            redGain: max(1.0, min(gains.redGain, maxGain)),
            greenGain: max(1.0, min(gains.greenGain, maxGain)),
            blueGain: max(1.0, min(gains.blueGain, maxGain))
        )
    }
    
    // MARK: - Zoom
    
    func setZoom(_ factor: CGFloat, animated: Bool = true) {
        guard let device = currentDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                let clamped = max(device.minAvailableVideoZoomFactor,
                                  min(factor, device.activeFormat.videoMaxZoomFactor))
                if animated {
                    device.ramp(toVideoZoomFactor: clamped, withRate: 8.0)
                } else {
                    device.videoZoomFactor = clamped
                }
                device.unlockForConfiguration()
                
                DispatchQueue.main.async {
                    self.currentZoomFactor = clamped
                }
            } catch {
                print("[CameraService] Zoom error: \(error)")
            }
        }
    }
    
    // MARK: - Framerate
    
    func setFrameRate(_ fps: Double) {
        guard let device = currentDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                
                // Find a format that supports this framerate
                var bestFormat: AVCaptureDevice.Format?
                // var bestFrameRateRange: AVFrameRateRange?
                
                for format in device.formats {
                    for range in format.videoSupportedFrameRateRanges {
                        if range.minFrameRate <= fps && range.maxFrameRate >= fps {
                            bestFormat = format
                            bestFrameRateRange = range
                        }
                    }
                }
                
                if let format = bestFormat {
                    device.activeFormat = format
                }
                
                let duration = CMTimeMake(value: 1, timescale: Int32(fps))
                device.activeVideoMinFrameDuration = duration
                device.activeVideoMaxFrameDuration = duration
                device.unlockForConfiguration()
            } catch {
                print("[CameraService] Framerate error: \(error)")
            }
        }
    }
    
    // MARK: - Resolution
    
    func setFormat(_ format: AVCaptureDevice.Format) {
        guard let device = currentDevice else { return }
        sessionQueue.async {
            do {
                try device.lockForConfiguration()
                device.activeFormat = format
                device.unlockForConfiguration()
                self.updateDeviceRanges()
            } catch {
                print("[CameraService] Format error: \(error)")
            }
        }
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto(format: PhotoFormat = .heif) {
        let settings: AVCapturePhotoSettings
        
        switch format {
        case .heif:
            settings = AVCapturePhotoSettings(format: [
                AVVideoCodecKey: AVVideoCodecType.hevc
            ])
        case .jpeg:
            settings = AVCapturePhotoSettings(format: [
                AVVideoCodecKey: AVVideoCodecType.jpeg
            ])
        case .proRAW:
            if photoOutput.isAppleProRAWSupported,
               let rawFormat = photoOutput.availableRawPhotoPixelFormatTypes.first {
                settings = AVCapturePhotoSettings(
                    rawPixelFormatType: rawFormat,
                    processedFormat: [AVVideoCodecKey: AVVideoCodecType.hevc]
                )
            } else {
                // Fallback to HEIF
                settings = AVCapturePhotoSettings(format: [
                    AVVideoCodecKey: AVVideoCodecType.hevc
                ])
            }
        }
        
        settings.flashMode = .off
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - Video Recording
    
    func startRecording(to url: URL, codec: VideoCodec = .hevc) {
        guard !isRecording else { return }
        
        // Configure codec
        if let connection = movieOutput.connection(with: .video) {
            if movieOutput.availableVideoCodecTypes.contains(codec.avCodecType) {
                movieOutput.setOutputSettings(
                    [AVVideoCodecKey: codec.avCodecType],
                    for: connection
                )
            }
        }
        
        movieOutput.startRecording(to: url, recordingDelegate: self)
        isRecording = true
    }
    
    func stopRecording() {
        guard isRecording else { return }
        movieOutput.stopRecording()
    }
    
    // MARK: - Preview Layer
    
    func createPreviewLayer() -> AVCaptureVideoPreviewLayer {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        previewLayer = layer
        return layer
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraService: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        onVideoFrame?(sampleBuffer)
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            onPhotoCaptured?(nil, error)
            return
        }
        let data = photo.fileDataRepresentation()
        onPhotoCaptured?(data, nil)
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        isRecording = false
        onRecordingFinished?(outputFileURL, error)
    }
}
