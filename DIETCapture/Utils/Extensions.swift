// Extensions.swift
// DIETCapture
//
// Utility extensions for simd, CMTime, CVPixelBuffer, and formatting.

import Foundation
import simd
import CoreMedia
import CoreVideo
import UIKit

// MARK: - simd_float4x4 → Quaternion

extension simd_float4x4 {
    /// Convert 4×4 transform to column-major flat array for serialization.
    var flatArray: [[Float]] {
        return [
            [columns.0.x, columns.0.y, columns.0.z, columns.0.w],
            [columns.1.x, columns.1.y, columns.1.z, columns.1.w],
            [columns.2.x, columns.2.y, columns.2.z, columns.2.w],
            [columns.3.x, columns.3.y, columns.3.z, columns.3.w]
        ]
    }
    
    var position: simd_float3 {
        return simd_float3(columns.3.x, columns.3.y, columns.3.z)
    }
    
    var rotation3x3: simd_float3x3 {
        return simd_float3x3(
            simd_float3(columns.0.x, columns.0.y, columns.0.z),
            simd_float3(columns.1.x, columns.1.y, columns.1.z),
            simd_float3(columns.2.x, columns.2.y, columns.2.z)
        )
    }
}

// MARK: - simd_float3x3 Serialization

extension simd_float3x3 {
    var flatArray: [[Float]] {
        return [
            [columns.0.x, columns.0.y, columns.0.z],
            [columns.1.x, columns.1.y, columns.1.z],
            [columns.2.x, columns.2.y, columns.2.z]
        ]
    }
}

// MARK: - CMTime Formatting

extension CMTime {
    /// Format as fractional shutter speed string, e.g. "1/60".
    var shutterSpeedString: String {
        let seconds = CMTimeGetSeconds(self)
        guard seconds > 0 && seconds.isFinite else { return "—" }
        
        if seconds >= 1.0 {
            return String(format: "%.1fs", seconds)
        } else {
            let denominator = Int(round(1.0 / seconds))
            return "1/\(denominator)"
        }
    }
    
    /// Normalized value for slider (log scale between min and max shutter speeds).
    static func shutterSpeedSliderValue(
        speed: CMTime,
        min: CMTime,
        max: CMTime
    ) -> Float {
        let logMin = log(Float(CMTimeGetSeconds(min)))
        let logMax = log(Float(CMTimeGetSeconds(max)))
        let logVal = log(Float(CMTimeGetSeconds(speed)))
        
        guard logMax != logMin else { return 0.5 }
        return (logVal - logMin) / (logMax - logMin)
    }
    
    /// Convert slider value (0-1 log scale) to CMTime.
    static func shutterSpeedFromSlider(
        value: Float,
        min: CMTime,
        max: CMTime
    ) -> CMTime {
        let logMin = log(Float(CMTimeGetSeconds(min)))
        let logMax = log(Float(CMTimeGetSeconds(max)))
        let logVal = logMin + Float(value) * (logMax - logMin)
        let seconds = exp(logVal)
        return CMTimeMakeWithSeconds(Float64(seconds), preferredTimescale: 1000000)
    }
}

// MARK: - CVPixelBuffer Utilities

extension CVPixelBuffer {
    var width: Int { CVPixelBufferGetWidth(self) }
    var height: Int { CVPixelBufferGetHeight(self) }
    var pixelFormatType: OSType { CVPixelBufferGetPixelFormatType(self) }
}

// MARK: - Float Formatting

extension Float {
    /// Format with specified decimal places.
    func formatted(decimals: Int = 1) -> String {
        return String(format: "%.\(decimals)f", self)
    }
}

// MARK: - TimeInterval Formatting

extension TimeInterval {
    /// Format as HH:MM:SS or MM:SS.
    var recordingDurationString: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - UIDevice Battery

extension UIDevice.BatteryState {
    var icon: String {
        switch self {
        case .charging: return "battery.100.bolt"
        case .full: return "battery.100"
        case .unplugged:
            let level = UIDevice.current.batteryLevel
            if level > 0.75 { return "battery.100" }
            if level > 0.50 { return "battery.75" }
            if level > 0.25 { return "battery.50" }
            return "battery.25"
        case .unknown: return "battery.0"
        @unknown default: return "battery.0"
        }
    }
}

// MARK: - Storage Formatting

extension Double {
    /// Format megabytes to human-readable string.
    var storageString: String {
        if self >= 1024 {
            return String(format: "%.1f GB", self / 1024)
        }
        return String(format: "%.0f MB", self)
    }
}

// MARK: - Color from String Name

import SwiftUI

extension Color {
    static func fromString(_ name: String) -> Color {
        switch name {
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "red": return .red
        default: return .gray
        }
    }
}
