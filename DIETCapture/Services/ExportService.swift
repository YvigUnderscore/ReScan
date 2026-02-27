// ExportService.swift
// ReScan
//
// Stray Scanner format export: depth maps (16-bit PNG mm), confidence maps,
// video recording via AVAssetWriter (ProRes/Apple Log or HEVC), camera_matrix.csv, odometry.csv.

import Foundation
import AVFoundation
import ARKit
import UIKit
import CoreImage
import VideoToolbox
import ModelIO
import SceneKit
import ImageIO

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
    private var currentEncodingMode: VideoEncodingMode = .standardHEVC
    
    // MARK: - Odometry CSV
    
    private var odometryFileHandle: FileHandle?
    private var hasWrittenOdometryHeader = false
    
    // MARK: - Device Capability Check
    
    /// Check if the device supports Apple Log (ProRes) recording
    static var supportsAppleLog: Bool {
        // Apple Log with ProRes is available on iPhone 15 Pro and later
        if #available(iOS 17.0, *) {
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            if let device = device {
                // Check if any format supports ProRes codec
                for format in device.formats {
                    // Check for Apple Log color space support
                    if format.supportedColorSpaces.contains(.appleLog) {
                        return true
                    }
                }
            }
        }
        return false
    }
    
    // MARK: - Video Recording
    
    func startVideoRecording(to url: URL, width: Int, height: Int, encodingMode: VideoEncodingMode) throws {
        currentEncodingMode = encodingMode
        
        let fileType: AVFileType
        let videoSettings: [String: Any]
        let sourcePixelFormat: OSType
        
        switch encodingMode {
        case .appleLog:
            // ProRes 422 HQ — visually lossless, Apple Log color space
            fileType = .mov
            sourcePixelFormat = kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange
            
            videoSettings = [
                AVVideoCodecKey: AVVideoCodecType.proRes422HQ,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoColorPropertiesKey: [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_Linear,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
                ]
            ]
            print("[ExportService] Starting ProRes 422 HQ recording (Apple Log)")
            
        case .hdrHEVC:
            // HDR HEVC — good quality with HDR metadata
            fileType = .mp4
            sourcePixelFormat = kCVPixelFormatType_32BGRA
            
            videoSettings = [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 40_000_000, // Higher bitrate for HDR
                    AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main10_AutoLevel,
                ],
                AVVideoColorPropertiesKey: [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_2020,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
                ]
            ]
            print("[ExportService] Starting HDR HEVC recording")
            
        case .standardHEVC:
            // Standard HEVC — compressed, smaller files
            fileType = .mp4
            sourcePixelFormat = kCVPixelFormatType_32BGRA
            
            videoSettings = [
                AVVideoCodecKey: AVVideoCodecType.hevc,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 20_000_000,
                    AVVideoProfileLevelKey: kVTProfileLevel_HEVC_Main_AutoLevel,
                ]
            ]
            print("[ExportService] Starting standard HEVC recording")
            
        case .exrSequence:
             fatalError("Cannot start video recording for EXR sequence")
        }
        
        let writer = try AVAssetWriter(url: url, fileType: fileType)
        
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = true
        
        let sourceAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: sourcePixelFormat,
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
        
        guard input.isReadyForMoreMediaData else { return }
        
        // Write raw ARKit buffer directly (already correct orientation)
        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
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
        let quat = simd_quatf(pose.rotation3x3)
        
        let line = "\(timestamp), \(frame), \(position.x), \(position.y), \(position.z), \(quat.vector.x), \(quat.vector.y), \(quat.vector.z), \(quat.vector.w)\n"
        handle.write(line.data(using: .utf8)!)
    }
    
    func closeOdometryFile() {
        odometryFileHandle?.closeFile()
        odometryFileHandle = nil
        hasWrittenOdometryHeader = false
    }
    
    // MARK: - Depth Map Export (16-bit PNG, millimeters)
    
    func saveDepthMap16BitPNG(_ depthMap: CVPixelBuffer, to url: URL, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let bufferWrapper = UnsafeSendableWrapper(value: depthMap)
        writeQueue.async {
            let depthMap = bufferWrapper.value
            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
            
            let width = CVPixelBufferGetWidth(depthMap)
            let height = CVPixelBufferGetHeight(depthMap)
            
            guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
                completion?(.failure(ExportError.bufferAccessFailed))
                return
            }
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
                else {
                    completion?(.failure(ExportError.conversionFailed))
                    return
                }
                
                do {
                    try pngData.write(to: url)
                    completion?(.success(()))
                } catch {
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - EXR Frame Export
    
    func saveEXRFrame(_ pixelBuffer: CVPixelBuffer, to url: URL, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let bufferWrapper = UnsafeSendableWrapper(value: pixelBuffer)
        writeQueue.async {
            let pb = bufferWrapper.value
            
            // Create CIImage to handle YUV to RGB conversion correctly
            let ciImage = CIImage(cvPixelBuffer: pb)
            
            // Render to a 16-bit float CGImage (EXR natively uses half-float or full-float)
            // Linear sRGB (or Rec.2020) is preferred for EXR
            let colorSpace = CGColorSpace(name: CGColorSpace.extendedLinearSRGB) ?? CGColorSpaceCreateDeviceRGB()
            let context = CIContext(options: nil)
            
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent, format: .RGBAh, colorSpace: colorSpace) else {
                completion?(.failure(ExportError.conversionFailed))
                return
            }
            
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "com.ilm.openexr-image" as CFString, 1, nil) else {
                completion?(.failure(ExportError.fileWriteFailed))
                return
            }
            
            let options: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: 1.0
            ]
            
            CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
            if CGImageDestinationFinalize(destination) {
                print("[ExportService] Saved EXR to \(url.lastPathComponent)")
                completion?(.success(()))
            } else {
                completion?(.failure(ExportError.fileWriteFailed))
            }
        }
    }
    
    // MARK: - Confidence Map Export
    
    func saveConfidenceMap(_ confidenceMap: CVPixelBuffer, to url: URL, completion: ((Result<Void, Error>) -> Void)? = nil) {
        let bufferWrapper = UnsafeSendableWrapper(value: confidenceMap)
        writeQueue.async {
            let confidenceMap = bufferWrapper.value
            CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly) }
            
            let width = CVPixelBufferGetWidth(confidenceMap)
            let height = CVPixelBufferGetHeight(confidenceMap)
            
            guard let baseAddress = CVPixelBufferGetBaseAddress(confidenceMap) else {
                completion?(.failure(ExportError.bufferAccessFailed))
                return
            }
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
                else {
                    completion?(.failure(ExportError.conversionFailed))
                    return
                }
                
                do {
                    try pngData.write(to: url)
                    completion?(.success(()))
                } catch {
                    completion?(.failure(error))
                }
            }
        }
    }
    
    // MARK: - Mesh Export (OBJ)
    
    func exportMeshAsOBJ(anchors: [ARMeshAnchor], to url: URL) {
        guard !anchors.isEmpty else { return }
        
        writeQueue.async {
            var allVertices: [SIMD3<Float>] = []
            var allFaces: [[Int32]] = []
            var vertexOffset: Int32 = 0
            
            for anchor in anchors {
                let geometry = anchor.geometry
                let transform = anchor.transform
                let vertexCount = geometry.vertices.count
                
                // Get vertex positions and apply transform
                let vertexBuffer = geometry.vertices.buffer.contents()
                let vertexStride = geometry.vertices.stride
                
                for i in 0..<vertexCount {
                    let ptr = vertexBuffer.advanced(by: i * vertexStride)
                    let vertex = ptr.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                    
                    // Transform to world space
                    let worldPos = transform * SIMD4<Float>(vertex.x, vertex.y, vertex.z, 1.0)
                    allVertices.append(SIMD3<Float>(worldPos.x, worldPos.y, worldPos.z))
                }
                
                // Get face indices
                let faceCount = geometry.faces.count
                let indexBuffer = geometry.faces.buffer.contents()
                let bytesPerIndex = geometry.faces.bytesPerIndex
                let indicesPerFace = geometry.faces.indexCountPerPrimitive
                
                for i in 0..<faceCount {
                    var face: [Int32] = []
                    for j in 0..<indicesPerFace {
                        let offset = (i * indicesPerFace + j) * bytesPerIndex
                        let ptr = indexBuffer.advanced(by: offset)
                        let index: Int32
                        if bytesPerIndex == 4 {
                            index = Int32(ptr.assumingMemoryBound(to: UInt32.self).pointee)
                        } else {
                            index = Int32(ptr.assumingMemoryBound(to: UInt16.self).pointee)
                        }
                        face.append(index + vertexOffset)
                    }
                    allFaces.append(face)
                }
                
                vertexOffset += Int32(vertexCount)
            }
            
            // Write OBJ file
            var obj = "# ReScan Mesh Export\n"
            obj += "# Vertices: \(allVertices.count), Faces: \(allFaces.count)\n\n"
            
            for v in allVertices {
                obj += "v \(v.x) \(v.y) \(v.z)\n"
            }
            
            obj += "\n"
            
            for face in allFaces {
                // OBJ uses 1-based indexing
                let indices = face.map { String($0 + 1) }.joined(separator: " ")
                obj += "f \(indices)\n"
            }
            
            try? obj.write(to: url, atomically: true, encoding: .utf8)
            print("[ExportService] Mesh exported: \(allVertices.count) vertices, \(allFaces.count) faces")
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
