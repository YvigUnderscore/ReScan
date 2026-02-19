// DepthMapProcessor.swift
// DIETCapture
//
// Depth map utilities: filtering, colormap generation, pixel buffer operations.

import Foundation
import CoreVideo
import simd
import Accelerate

final class DepthMapProcessor {
    
    // MARK: - Distance Filtering
    
    /// Zeros out depth values beyond maxDistance.
    static func filterByDistance(_ depthMap: CVPixelBuffer, maxDistance: Float) {
        CVPixelBufferLockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(depthMap, CVPixelBufferLockFlags(rawValue: 0)) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return }
        
        let pointer = baseAddress.assumingMemoryBound(to: Float32.self)
        let count = width * height
        
        for i in 0..<count {
            if pointer[i] > maxDistance || pointer[i].isNaN || pointer[i] < 0 {
                pointer[i] = 0.0
            }
        }
    }
    
    // MARK: - Confidence Filtering
    
    /// Zeros out depth values where confidence is below threshold.
    static func filterByConfidence(
        depth: CVPixelBuffer,
        confidence: CVPixelBuffer,
        threshold: ConfidenceThreshold
    ) {
        CVPixelBufferLockBaseAddress(depth, CVPixelBufferLockFlags(rawValue: 0))
        CVPixelBufferLockBaseAddress(confidence, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(depth, CVPixelBufferLockFlags(rawValue: 0))
            CVPixelBufferUnlockBaseAddress(confidence, .readOnly)
        }
        
        let width = CVPixelBufferGetWidth(depth)
        let height = CVPixelBufferGetHeight(depth)
        
        guard let depthBase = CVPixelBufferGetBaseAddress(depth),
              let confBase = CVPixelBufferGetBaseAddress(confidence) else { return }
        
        let depthPointer = depthBase.assumingMemoryBound(to: Float32.self)
        let confPointer = confBase.assumingMemoryBound(to: UInt8.self)
        
        for i in 0..<(width * height) {
            if confPointer[i] < UInt8(threshold.rawValue) {
                depthPointer[i] = 0.0
            }
        }
    }
    
    // MARK: - Jet Colormap
    
    /// Converts a depth value (normalized 0-1) to RGB using the jet colormap.
    static func jetColormap(_ value: Float) -> (r: Float, g: Float, b: Float) {
        let v = max(0, min(1, value))
        
        var r: Float = 0, g: Float = 0, b: Float = 0
        
        if v < 0.125 {
            r = 0
            g = 0
            b = 0.5 + v * 4.0
        } else if v < 0.375 {
            r = 0
            g = (v - 0.125) * 4.0
            b = 1.0
        } else if v < 0.625 {
            r = (v - 0.375) * 4.0
            g = 1.0
            b = 1.0 - (v - 0.375) * 4.0
        } else if v < 0.875 {
            r = 1.0
            g = 1.0 - (v - 0.625) * 4.0
            b = 0
        } else {
            r = 1.0 - (v - 0.875) * 4.0
            g = 0
            b = 0
        }
        
        return (r, g, b)
    }
    
    // MARK: - Depth to RGBA Colormap
    
    /// Generates an RGBA pixel buffer from a depth map using jet colormap.
    static func depthToColormapRGBA(
        depthMap: CVPixelBuffer,
        minDepth: Float = 0.0,
        maxDepth: Float = 5.0,
        opacity: Float = 0.5
    ) -> CVPixelBuffer? {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        
        guard let depthBase = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let depthPointer = depthBase.assumingMemoryBound(to: Float32.self)
        
        // Create RGBA output buffer
        var outputBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, width, height,
            kCVPixelFormatType_32BGRA, nil, &outputBuffer
        )
        guard status == kCVReturnSuccess, let output = outputBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(output, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(output, CVPixelBufferLockFlags(rawValue: 0)) }
        
        guard let outputBase = CVPixelBufferGetBaseAddress(output) else { return nil }
        let outputPointer = outputBase.assumingMemoryBound(to: UInt8.self)
        let outputBytesPerRow = CVPixelBufferGetBytesPerRow(output)
        
        let range = maxDepth - minDepth
        
        for y in 0..<height {
            for x in 0..<width {
                let depthIndex = y * width + x
                let depth = depthPointer[depthIndex]
                
                let outputOffset = y * outputBytesPerRow + x * 4
                
                if depth <= 0 || depth.isNaN {
                    // Transparent for invalid depth
                    outputPointer[outputOffset] = 0     // B
                    outputPointer[outputOffset + 1] = 0 // G
                    outputPointer[outputOffset + 2] = 0 // R
                    outputPointer[outputOffset + 3] = 0 // A
                } else {
                    let normalized = (depth - minDepth) / range
                    let (r, g, b) = jetColormap(normalized)
                    
                    outputPointer[outputOffset] = UInt8(b * 255)     // B
                    outputPointer[outputOffset + 1] = UInt8(g * 255) // G
                    outputPointer[outputOffset + 2] = UInt8(r * 255) // R
                    outputPointer[outputOffset + 3] = UInt8(opacity * 255) // A
                }
            }
        }
        
        return output
    }
    
    // MARK: - Confidence to RGBA
    
    static func confidenceToColormapRGBA(
        confidenceMap: CVPixelBuffer,
        opacity: Float = 0.5
    ) -> CVPixelBuffer? {
        CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(confidenceMap)
        let height = CVPixelBufferGetHeight(confidenceMap)
        
        guard let confBase = CVPixelBufferGetBaseAddress(confidenceMap) else { return nil }
        let confPointer = confBase.assumingMemoryBound(to: UInt8.self)
        
        var outputBuffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &outputBuffer)
        guard let output = outputBuffer else { return nil }
        
        CVPixelBufferLockBaseAddress(output, CVPixelBufferLockFlags(rawValue: 0))
        defer { CVPixelBufferUnlockBaseAddress(output, CVPixelBufferLockFlags(rawValue: 0)) }
        
        guard let outputBase = CVPixelBufferGetBaseAddress(output) else { return nil }
        let outputPointer = outputBase.assumingMemoryBound(to: UInt8.self)
        let outputBytesPerRow = CVPixelBufferGetBytesPerRow(output)
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                let confidence = confPointer[index]
                let outputOffset = y * outputBytesPerRow + x * 4
                
                let (r, g, b): (UInt8, UInt8, UInt8) = {
                    switch confidence {
                    case 0: return (255, 50, 50)    // Red = low
                    case 1: return (255, 200, 50)   // Yellow = medium
                    case 2: return (50, 255, 50)    // Green = high
                    default: return (128, 128, 128)
                    }
                }()
                
                outputPointer[outputOffset] = b
                outputPointer[outputOffset + 1] = g
                outputPointer[outputOffset + 2] = r
                outputPointer[outputOffset + 3] = UInt8(opacity * 255)
            }
        }
        
        return output
    }
    
    // MARK: - Depth Statistics
    
    static func depthStatistics(_ depthMap: CVPixelBuffer) -> (min: Float, max: Float, mean: Float) {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
        
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard let base = CVPixelBufferGetBaseAddress(depthMap) else {
            return (0, 0, 0)
        }
        
        let pointer = base.assumingMemoryBound(to: Float32.self)
        var minVal: Float = .greatestFiniteMagnitude
        var maxVal: Float = 0
        var sum: Float = 0
        var count: Int = 0
        
        for i in 0..<(width * height) {
            let v = pointer[i]
            guard v > 0, !v.isNaN, !v.isInfinite else { continue }
            minVal = min(minVal, v)
            maxVal = max(maxVal, v)
            sum += v
            count += 1
        }
        
        let mean = count > 0 ? sum / Float(count) : 0
        return (count > 0 ? minVal : 0, maxVal, mean)
    }
    
    // MARK: - Copy Depth Map
    
    /// Creates a deep copy of a CVPixelBuffer for safe async processing.
    static func copyDepthMap(_ source: CVPixelBuffer) -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        let pixelFormat = CVPixelBufferGetPixelFormatType(source)
        
        var copy: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, pixelFormat, nil, &copy)
        guard status == kCVReturnSuccess, let dest = copy else { return nil }
        
        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(dest, CVPixelBufferLockFlags(rawValue: 0))
        defer {
            CVPixelBufferUnlockBaseAddress(source, .readOnly)
            CVPixelBufferUnlockBaseAddress(dest, CVPixelBufferLockFlags(rawValue: 0))
        }
        
        guard let srcBase = CVPixelBufferGetBaseAddress(source),
              let dstBase = CVPixelBufferGetBaseAddress(dest) else { return nil }
        
        let byteCount = CVPixelBufferGetDataSize(source)
        memcpy(dstBase, srcBase, min(byteCount, CVPixelBufferGetDataSize(dest)))
        
        return dest
    }
}
