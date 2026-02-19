// DeviceCapabilityService.swift
// ReScan
//
// Detects hardware capabilities: LiDAR, ProRAW, available lenses.

import Foundation
import AVFoundation
import ARKit

@Observable
final class DeviceCapabilityService {
    
    // MARK: - Capabilities
    
    var hasLiDAR: Bool = false
    var hasProRAW: Bool = false
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
        deviceName = UIDevice.current.name
        hasLiDAR = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        
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
        if #available(iOS 16.0, *) {
            let photoOutput = AVCapturePhotoOutput()
            hasProRAW = photoOutput.isAppleProRAWSupported
        }
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
