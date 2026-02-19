// Extensions.swift
// ReScan
//
// Utility extensions for simd, CMTime, CVPixelBuffer, and formatting.

import Foundation
import simd
import CoreMedia
import CoreVideo
import UIKit

// MARK: - simd_float4x4

extension simd_float4x4 {
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

// MARK: - simd_float3x3

extension simd_float3x3 {
    var flatArray: [[Float]] {
        return [
            [columns.0.x, columns.0.y, columns.0.z],
            [columns.1.x, columns.1.y, columns.1.z],
            [columns.2.x, columns.2.y, columns.2.z]
        ]
    }
}

// MARK: - CMTime

extension CMTime {
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
}

// MARK: - CVPixelBuffer

extension CVPixelBuffer {
    var width: Int { CVPixelBufferGetWidth(self) }
    var height: Int { CVPixelBufferGetHeight(self) }
}

// MARK: - Float

extension Float {
    func formatted(decimals: Int = 1) -> String {
        return String(format: "%.\(decimals)f", self)
    }
}

// MARK: - TimeInterval

extension TimeInterval {
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

// MARK: - Storage

extension Double {
    var storageString: String {
        if self >= 1024 {
            return String(format: "%.1f GB", self / 1024)
        }
        return String(format: "%.0f MB", self)
    }
}

// MARK: - Color

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
