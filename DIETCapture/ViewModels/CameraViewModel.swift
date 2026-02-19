// CameraViewModel.swift
// DIETCapture
//
// Observable ViewModel binding camera controls to CameraService.

import Foundation
import AVFoundation
import Combine
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
    
    var shutterSliderValue: Float = 0.5
    var isoSliderValue: Float = 0.5
    var evSliderValue: Float = 0.5
    var focusSliderValue: Float = 0.5
    var zoomSliderValue: Float = 0.0
    
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
    
    var zoomDisplay: String {
        "\(settings.zoomFactor.formatted(decimals: 1))x"
    }
    
    // MARK: - Setup
    
    func setup() {
        cameraService.setupSession(preferredLens: settings.selectedLens)
    }
    
    func teardown() {
        cameraService.stopSession()
    }
    
    // MARK: - Exposure
    
    func setExposureMode(_ mode: ExposureMode) {
        settings.exposureMode = mode
        cameraService.setExposureMode(mode)
    }
    
    func updateShutterSpeed(sliderValue: Float) {
        shutterSliderValue = sliderValue
        let speed = CMTime.shutterSpeedFromSlider(
            value: sliderValue,
            min: cameraService.minShutterSpeed,
            max: cameraService.maxShutterSpeed
        )
        settings.shutterSpeed = speed
        
        if settings.exposureMode == .manual {
            cameraService.setManualExposure(
                shutterSpeed: speed,
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
            cameraService.setManualFocus(position: sliderValue)
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
    
    // MARK: - Lens / Zoom
    
    func selectLens(_ lens: LensType) {
        guard capabilities.availableLenses.contains(lens) else { return }
        settings.selectedLens = lens
        cameraService.switchLens(lens)
    }
    
    func updateZoom(factor: CGFloat) {
        settings.zoomFactor = factor
        cameraService.setZoom(factor)
    }
    
    // MARK: - Format Configuration
    
    func setFrameRate(_ fps: Double) {
        settings.targetFramerate = fps
        cameraService.setFrameRate(fps)
    }
    
    func setResolution(_ preset: ResolutionPreset) {
        guard let format = preset.format else { return }
        cameraService.setFormat(format)
    }
    
    // MARK: - Capture
    
    func capturePhoto() {
        cameraService.capturePhoto(format: settings.photoFormat)
    }
    
    func startRecording(to url: URL) {
        cameraService.startRecording(to: url, codec: settings.videoCodec)
    }
    
    func stopRecording() {
        cameraService.stopRecording()
    }
}

extension CGFloat {
    func formatted(decimals: Int = 1) -> String {
        return String(format: "%.\(decimals)f", self)
    }
}
