// CameraViewModel.swift
// ReScan
//
// Observable ViewModel for camera manual controls.

import Foundation
import Observation
import AVFoundation
import CoreMedia

@Observable
final class CameraViewModel {
    
    // MARK: - Services
    
    let cameraService = CameraService()
    let capabilities = DeviceCapabilityService()
    
    // MARK: - Settings
    
    var settings = CameraSettings()
    
    // MARK: - Computed Ranges
    
    var isoRange: ClosedRange<Float> {
        cameraService.minISO...cameraService.maxISO
    }
    
    var evRange: ClosedRange<Float> {
        cameraService.minEV...cameraService.maxEV
    }
    
    // MARK: - Slider Values (normalized 0-1)
    
    var isoSliderValue: Float = 0.5
    var evSliderValue: Float = 0.5
    var focusSliderValue: Float = 0.5
    
    // MARK: - Selected Shutter Preset
    
    var selectedShutterPreset: ShutterSpeedPreset? = nil
    
    // MARK: - Display Values
    
    var shutterSpeedDisplay: String {
        settings.shutterSpeed.shutterSpeedString
    }
    
    var isoDisplay: String {
        "\(Int(settings.iso))"
    }
    
    var evDisplay: String {
        let sign = settings.exposureCompensation >= 0 ? "+" : ""
        return "\(sign)\(settings.exposureCompensation.formatted(decimals: 1))"
    }
    
    var focusDisplay: String {
        if settings.focusMode == .manual {
            return settings.manualFocusPosition.formatted(decimals: 2)
        }
        return settings.focusMode.rawValue
    }
    
    // MARK: - Setup
    
    func setup(device: AVCaptureDevice?) {
        cameraService.attachToDevice(device)
    }
    
    func teardown() {
        // Nothing to tear down — ARKit owns the session
    }
    
    // MARK: - Exposure
    
    func setExposureMode(_ mode: ExposureMode) {
        settings.exposureMode = mode
        cameraService.setExposureMode(mode)
    }
    
    func setShutterPreset(_ preset: ShutterSpeedPreset) {
        selectedShutterPreset = preset
        settings.shutterSpeed = preset.time
        
        if settings.exposureMode == .manual {
            cameraService.setManualExposure(
                shutterSpeed: preset.time,
                iso: settings.iso
            )
        }
    }
    
    func updateISO(sliderValue: Float) {
        isoSliderValue = sliderValue
        let range = isoRange
        let iso = range.lowerBound + sliderValue * (range.upperBound - range.lowerBound)
        settings.iso = iso
        
        if settings.exposureMode == .manual {
            cameraService.setManualExposure(
                shutterSpeed: settings.shutterSpeed,
                iso: iso
            )
        }
    }
    
    func updateEV(sliderValue: Float) {
        evSliderValue = sliderValue
        let range = evRange
        let ev = range.lowerBound + sliderValue * (range.upperBound - range.lowerBound)
        settings.exposureCompensation = ev
        cameraService.setExposureCompensation(ev)
    }
    
    // MARK: - Focus
    
    func setFocusMode(_ mode: FocusMode) {
        settings.focusMode = mode
        cameraService.setFocusMode(mode, lensPosition: settings.manualFocusPosition)
    }
    
    func updateFocus(sliderValue: Float) {
        focusSliderValue = sliderValue
        settings.manualFocusPosition = sliderValue
        if settings.focusMode == .manual {
            cameraService.setFocusMode(.manual, lensPosition: sliderValue)
        }
    }
    
    // MARK: - White Balance
    
    func setWhiteBalanceMode(_ mode: WhiteBalanceMode) {
        settings.whiteBalanceMode = mode
        switch mode {
        case .auto:
            cameraService.setAutoWhiteBalance()
        case .manual:
            cameraService.setManualWhiteBalance(
                temperature: settings.whiteBalance.temperature,
                tint: settings.whiteBalance.tint
            )
        }
    }
    
    func updateWhiteBalance(temperature: Float, tint: Float) {
        settings.whiteBalance.temperature = temperature
        settings.whiteBalance.tint = tint
        if settings.whiteBalanceMode == .manual {
            cameraService.setManualWhiteBalance(temperature: temperature, tint: tint)
        }
    }
}

extension CGFloat {
    func formatted(decimals: Int = 1) -> String {
        return String(format: "%.\(decimals)f", self)
    }
}
