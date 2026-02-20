// ExportService.swift
// ReScan
//
// Stray Scanner format export: depth maps (16-bit PNG mm), confidence maps,
// video recording via AVAssetWriter, camera_matrix.csv, odometry.csv.

import Foundation
import AVFoundation
import ARKit
import UIKit
import CoreImage
import VideoToolbox

struct UnsafeSendableWrapper<T>: @unchecked Sendable {
    let value: T
}

final class ExportService {
    
    // MARK: - Queues
    
    private let writeQueue = DispatchQueue(label: "com.rescan.export.write", qos: .utility)
    
    // MARK: - AVAssetWriter for Video
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var videoStartTime: CMTime?
    private var isWritingVideo = false
    
    // MARK: - Odometry CSV
    
    private var odometryFileHandle: FileHandle?
    private var hasWrittenOdometryHeader = false
    
    // MARK: - Video Recording
    
    func startVideoRecording(to url: URL, width: Int, height: Int) throws {
        let writer = try AVAssetWriter(url: url, fileType: .mp4)
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 20_000_000,
                AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main_AutoLevel,
            ]
        ]
        
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true
        // ARKit capturedImage is landscape-right, rotate 90° anti-clockwise for portrait video
        input.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        
        let sourceAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourceAttributes
        )
        
        if writer.canAdd(input) {
            writer.add(input)
        }
        
        writer.startWriting()
        
        assetWriter = writer
        videoInput = input
        pixelBufferAdaptor = adaptor
        videoStartTime = nil
        isWritingVideo = true
    }
    
    func appendVideoFrame(_ pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) {
        guard isWritingVideo, let writer = assetWriter, let input = videoInput,
              let adaptor = pixelBufferAdaptor else { return }
        
        let presentationTime = CMTimeMakeWithSeconds(timestamp, preferredTimescale: 600)
        
        if videoStartTime == nil {
            videoStartTime = presentationTime
            writer.startSession(atSourceTime: presentationTime)
        }
        
        if input.isReadyForMoreMediaData {
            adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
        }
    }
    
    func finishVideoRecording(completion: @escaping () -> Void) {
        guard isWritingVideo, let writer = assetWriter else {
            completion()
            return
        }
        
        isWritingVideo = false
        videoInput?.markAsFinished()
        writer.finishWriting {
            completion()
        }
        
        assetWriter = nil
        videoInput = nil
        pixelBufferAdaptor = nil
        videoStartTime = nil
    }
    
    // MARK: - Camera Matrix CSV (Stray Scanner format: 3x3 intrinsics)
    
    func saveCameraMatrix(_ intrinsics: simd_float3x3, to url: URL) {
        let cols = intrinsics.columns
        // 3x3 row-major format
        let csv = """
        \(cols.0.x),\(cols.1.x),\(cols.2.x)
        \(cols.0.y),\(cols.1.y),\(cols.2.y)
        \(cols.0.z),\(cols.1.z),\(cols.2.z)
        """
        try? csv.write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Odometry CSV (Stray Scanner format)
    
    func openOdometryFile(at url: URL) {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        odometryFileHandle = try? FileHandle(forWritingTo: url)
        hasWrittenOdometryHeader = false
        
        // Write header
        let header = "timestamp, frame, x, y, z, qx, qy, qz, qw\n"
        odometryFileHandle?.write(header.data(using: .utf8)!)
        hasWrittenOdometryHeader = true
    }
    
    func appendOdometry(timestamp: Double, frame: Int, pose: simd_float4x4) {
        guard let handle = odometryFileHandle else { return }
        
        // Extract position (translation from 4x4 matrix)
        let position = pose.position
        
        // Extract quaternion from rotation matrix
        let quat = quaternionFromMatrix(pose.rotation3x3)
        
        let line = "\(timestamp), \(frame), \(position.x), \(position.y), \(position.z), \(quat.vector.x), \(quat.vector.y), \(quat.vector.z), \(quat.vector.w)\n"
        handle.write(line.data(using: .utf8)!)
    }
    
    func closeOdometryFile() {
        odometryFileHandle?.closeFile()
        odometryFileHandle = nil
        hasWrittenOdometryHeader = false
    }
    
    // MARK: - Quaternion from Rotation Matrix
    
    private func quaternionFromMatrix(_ R: simd_float3x3) -> simd_quatf {
        return simd_quatf(R)
    }
    
    // MARK: - Depth Map Export (16-bit PNG, millimeters)
    
    func saveDepthMap16BitPNG(_ depthMap: CVPixelBuffer, to url: URL) {
        let bufferWrapper = UnsafeSendableWrapper(value: depthMap)
        writeQueue.async {
            let depthMap = bufferWrapper.value
            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
            
            let width = CVPixelBufferGetWidth(depthMap)
            let height = CVPixelBufferGetHeight(depthMap)
            
            guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return }
            let floatPointer = baseAddress.assumingMemoryBound(to: Float32.self)
            
            // Convert float meters to UInt16 millimeters
            var uint16Data = [UInt16](repeating: 0, count: width * height)
            for i in 0..<(width * height) {
                let meters = floatPointer[i]
                if meters > 0 && !meters.isNaN && !meters.isInfinite {
                    uint16Data[i] = UInt16(min(Float(UInt16.max), meters * 1000.0))
                }
            }
            
            let bytesPerRow = width * 2
            let colorSpace = CGColorSpaceCreateDeviceGray()
            
            uint16Data.withUnsafeMutableBytes { rawBuffer in
                guard let context = CGContext(
                    data: rawBuffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 16,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                ),
                      let cgImage = context.makeImage(),
                      let pngData = UIImage(cgImage: cgImage).pngData()
                else { return }
                
                try? pngData.write(to: url)
            }
        }
    }
    
    // MARK: - Confidence Map Export
    
    func saveConfidenceMap(_ confidenceMap: CVPixelBuffer, to url: URL) {
        let bufferWrapper = UnsafeSendableWrapper(value: confidenceMap)
        writeQueue.async {
            let confidenceMap = bufferWrapper.value
            CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly) }
            
            let width = CVPixelBufferGetWidth(confidenceMap)
            let height = CVPixelBufferGetHeight(confidenceMap)
            
            guard let baseAddress = CVPixelBufferGetBaseAddress(confidenceMap) else { return }
            let pointer = baseAddress.assumingMemoryBound(to: UInt8.self)
            
            // Scale 0,1,2 → 0, 127, 255
            var scaledData = [UInt8](repeating: 0, count: width * height)
            for i in 0..<(width * height) {
                switch pointer[i] {
                case 0: scaledData[i] = 0
                case 1: scaledData[i] = 127
                case 2: scaledData[i] = 255
                default: scaledData[i] = 0
                }
            }
            
            scaledData.withUnsafeMutableBytes { rawBuffer in
                guard let context = CGContext(
                    data: rawBuffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                ),
                      let cgImage = context.makeImage(),
                      let pngData = UIImage(cgImage: cgImage).pngData()
                else { return }
                
                try? pngData.write(to: url)
            }
        }
    }
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case bufferAccessFailed
    case conversionFailed
    case fileWriteFailed
    
    var errorDescription: String? {
        switch self {
        case .bufferAccessFailed: return "Failed to access pixel buffer"
        case .conversionFailed: return "Image conversion failed"
        case .fileWriteFailed: return "File write failed"
        }
    }
}
