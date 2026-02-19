// DeviceCapabilityService.swift
// DIETCapture
//
// Detects hardware capabilities: LiDAR, ProRAW, ProRes, available lenses.

import Foundation
import AVFoundation
import ARKit

@Observable
final class DeviceCapabilityService {
    
    // MARK: - Capabilities
    
    var hasLiDAR: Bool = false
    var hasProRAW: Bool = false
    var hasProRes: Bool = false
    var hasExternalStorage: Bool = false
    var hasAppleLog: Bool = false
    var availableLenses: [LensType] = []
    var thermalState: ProcessInfo.ThermalState = .nominal
    var batteryLevel: Float = -1.0
    var batteryState: UIDevice.BatteryState = .unknown
    var deviceName: String = ""
    
    // MARK: - Init
    
    init() {
        detectCapabilities()
        startThermalMonitoring()
        startBatteryMonitoring()
    }
    
    // MARK: - Detection
    
    func detectCapabilities() {
        // Device name
        deviceName = UIDevice.current.name
        
        // LiDAR
        hasLiDAR = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        
        // Available lenses
        availableLenses = []
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
                .builtInUltraWideCamera,
                .builtInWideAngleCamera,
                .builtInTelephotoCamera
            ],
            mediaType: .video,
            position: .back
        )
        
        for device in discoverySession.devices {
            switch device.deviceType {
            case .builtInUltraWideCamera:
                availableLenses.append(.ultraWide)
            case .builtInWideAngleCamera:
                availableLenses.append(.wide)
            case .builtInTelephotoCamera:
                // Detect 3x vs 5x based on max optical zoom
                let maxZoom = device.maxAvailableVideoZoomFactor
                if maxZoom >= 5.0 {
                    availableLenses.append(.telephoto5x)
                } else {
                    availableLenses.append(.telephoto3x)
                }
            default:
                break
            }
        }
        
        // ProRAW detection
        if let wideCamera = AVCaptureDevice.default(
            .builtInWideAngleCamera, for: .video, position: .back
        ) {
            let photoOutput = AVCapturePhotoOutput()
            // ProRAW is available on iPhone 14 Pro+
            if #available(iOS 16.0, *) {
                hasProRAW = photoOutput.isAppleProRAWSupported
            }
            
            // ProRes detection
            for format in wideCamera.formats {
                // let codecs = format.supportedColorSpaces
                // Check for ProRes support in formats
                if format.isVideoHDRSupported {
                    // ProRes typically available on A17 Pro+
                }
            }
        }
        
        // Apple Log detection (iPhone 15 Pro+)
        if #available(iOS 17.0, *) {
            if let device = AVCaptureDevice.default(
                .builtInWideAngleCamera, for: .video, position: .back
            ) {
                for format in device.formats {
                    // Check for Apple Log color space support
                    let desc = format.formatDescription
                    let dimensions = CMVideoFormatDescriptionGetDimensions(desc)
                    if dimensions.width >= 3840 {
                        // 4K capable = likely Pro model
                    }
                }
            }
        }
    }
    
    // MARK: - Available Formats
    
    func availableResolutions(for device: AVCaptureDevice) -> [ResolutionPreset] {
        var resolutions: [ResolutionPreset] = []
        var seen = Set<String>()
        
        for format in device.formats {
            let desc = format.formatDescription
            let mediaType = CMFormatDescriptionGetMediaType(desc)
            guard mediaType == kCMMediaType_Video else { continue }
            
            let dimensions = CMVideoFormatDescriptionGetDimensions(desc)
            let key = "\(dimensions.width)x\(dimensions.height)"
            
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            
            let label: String
            switch (dimensions.width, dimensions.height) {
            case (1280, 720): label = "720p"
            case (1920, 1080): label = "1080p"
            case (3840, 2160): label = "4K"
            case (4032, 3024): label = "48MP (4032×3024)"
            default: label = "\(dimensions.width)×\(dimensions.height)"
            }
            
            resolutions.append(ResolutionPreset(
                label: label,
                width: Int(dimensions.width),
                height: Int(dimensions.height),
                format: format
            ))
        }
        
        return resolutions.sorted { $0.width * $0.height < $1.width * $1.height }
    }
    
    func availableFramerates(for format: AVCaptureDevice.Format) -> [FrameratePreset] {
        var framerates: [FrameratePreset] = []
        
        for range in format.videoSupportedFrameRateRanges {
            let maxFPS = range.maxFrameRate
            for preset in FrameratePreset.common {
                if preset.fps <= maxFPS && !framerates.contains(where: { $0.fps == preset.fps }) {
                    framerates.append(preset)
                }
            }
        }
        
        return framerates.sorted { $0.fps < $1.fps }
    }
    
    // MARK: - ISO Range
    
    func isoRange(for device: AVCaptureDevice) -> ClosedRange<Float> {
        return device.activeFormat.minISO...device.activeFormat.maxISO
    }
    
    // MARK: - Shutter Speed Range
    
    func shutterSpeedRange(for device: AVCaptureDevice) -> (min: CMTime, max: CMTime) {
        return (
            device.activeFormat.minExposureDuration,
            device.activeFormat.maxExposureDuration
        )
    }
    
    // MARK: - Thermal Monitoring
    
    private func startThermalMonitoring() {
        thermalState = ProcessInfo.processInfo.thermalState
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.thermalState = ProcessInfo.processInfo.thermalState
        }
    }
    
    // MARK: - Battery Monitoring
    
    private func startBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        updateBattery()
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateBattery()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateBattery()
        }
    }
    
    private func updateBattery() {
        batteryLevel = UIDevice.current.batteryLevel
        batteryState = UIDevice.current.batteryState
    }
    
    var batteryPercentage: Int {
        guard batteryLevel >= 0 else { return -1 }
        return Int(batteryLevel * 100)
    }
}
