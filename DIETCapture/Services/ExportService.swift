// ExportService.swift
// DIETCapture
//
// File I/O: saves depth maps, confidence, point clouds, mesh, and metadata to disk.

import Foundation
import AVFoundation
import ARKit
import UIKit
import CoreImage
import ModelIO
import MetalKit

struct UnsafeSendableWrapper<T>: @unchecked Sendable {
    let value: T
}

final class ExportService {
    
    // MARK: - Queues
    
    private let exportQueue = DispatchQueue(label: "com.dietcapture.export", qos: .utility, attributes: .concurrent)
    private let writeQueue = DispatchQueue(label: "com.dietcapture.export.write", qos: .utility)
    
    // MARK: - RGB Export
    
    func saveRGBImage(_ data: Data, to url: URL, completion: ((Error?) -> Void)? = nil) {
        writeQueue.async {
            do {
                try data.write(to: url)
                completion?(nil)
            } catch {
                completion?(error)
            }
        }
    }
    
    func saveRGBFromPixelBuffer(
        _ pixelBuffer: CVPixelBuffer,
        to url: URL,
        format: PhotoFormat = .heif,
        completion: ((Error?) -> Void)? = nil
    ) {
        writeQueue.async {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let context = CIContext()
            
            do {
                switch format {
                case .heif:
                    try context.writeHEIFRepresentation(
                        of: ciImage,
                        to: url,
                        format: .RGBA8,
                        colorSpace: CGColorSpaceCreateDeviceRGB()
                    )
                case .jpeg:
                    guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent),
                          let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.95)
                    else {
                        completion?(ExportError.conversionFailed)
                        return
                    }
                    try data.write(to: url)
                case .proRAW:
                    // ProRAW is handled directly by AVCapturePhotoOutput
                    try context.writeHEIFRepresentation(
                        of: ciImage,
                        to: url,
                        format: .RGBA8,
                        colorSpace: CGColorSpaceCreateDeviceRGB()
                    )
                }
                completion?(nil)
            } catch {
                completion?(error)
            }
        }
    }
    
    // MARK: - Depth Map Export
    
    func saveDepthMap16BitPNG(_ depthMap: CVPixelBuffer, to url: URL, completion: ((Error?) -> Void)? = nil) {
        let bufferWrapper = UnsafeSendableWrapper(value: depthMap)
        writeQueue.async {
            let depthMap = bufferWrapper.value
            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
            
            let width = CVPixelBufferGetWidth(depthMap)
            let height = CVPixelBufferGetHeight(depthMap)
            
            guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
                completion?(ExportError.bufferAccessFailed)
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
            
            // Create 16-bit grayscale PNG
            let bitsPerComponent = 16
            // bitsPerPixel unused
            let bytesPerRow = width * 2
            let colorSpace = CGColorSpaceCreateDeviceGray()
            
            uint16Data.withUnsafeMutableBytes { rawBuffer in
                guard let context = CGContext(
                    data: rawBuffer.baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: bitsPerComponent,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                ) else {
                    completion?(ExportError.conversionFailed)
                    return
                }
                
                guard let cgImage = context.makeImage() else {
                    completion?(ExportError.conversionFailed)
                    return
                }
                
                let uiImage = UIImage(cgImage: cgImage)
                guard let pngData = uiImage.pngData() else {
                    completion?(ExportError.conversionFailed)
                    return
                }
                
                do {
                    try pngData.write(to: url)
                    completion?(nil)
                } catch {
                    completion?(error)
                }
            }
        }
    }
    
    func saveDepthMap32BitTIFF(_ depthMap: CVPixelBuffer, to url: URL, completion: ((Error?) -> Void)? = nil) {
        let bufferWrapper = UnsafeSendableWrapper(value: depthMap)
        writeQueue.async {
            let depthMap = bufferWrapper.value
            let ciImage = CIImage(cvPixelBuffer: depthMap)
            let context = CIContext()
            
            do {
                try context.writeTIFFRepresentation(
                    of: ciImage,
                    to: url,
                    format: .Rf,
                    colorSpace: CGColorSpaceCreateDeviceGray()
                )
                completion?(nil)
            } catch {
                completion?(error)
            }
        }
    }
    
    /// Minimal OpenEXR writer for single-channel float32 depth maps.
    func saveDepthMapEXR(_ depthMap: CVPixelBuffer, to url: URL, completion: ((Error?) -> Void)? = nil) {
        let bufferWrapper = UnsafeSendableWrapper(value: depthMap)
        writeQueue.async {
            let depthMap = bufferWrapper.value
            CVPixelBufferLockBaseAddress(depthMap, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }
            
            let width = CVPixelBufferGetWidth(depthMap)
            let height = CVPixelBufferGetHeight(depthMap)
            
            guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else {
                completion?(ExportError.bufferAccessFailed)
                return
            }
            
            let floatPointer = baseAddress.assumingMemoryBound(to: Float32.self)
            
            // Convert Float32 to Float16 for EXR HALF format
            var halfData = [UInt16](repeating: 0, count: width * height)
            for i in 0..<(width * height) {
                halfData[i] = Self.floatToHalf(floatPointer[i])
            }
            
            // Build minimal EXR file
            do {
                let exrData = try Self.buildEXRFile(
                    width: width,
                    height: height,
                    channelName: "Z",
                    halfPixelData: halfData
                )
                try exrData.write(to: url)
                completion?(nil)
            } catch {
                completion?(error)
            }
        }
    }
    
    // MARK: - Confidence Map Export
    
    func saveConfidenceMap(_ confidenceMap: CVPixelBuffer, to url: URL, completion: ((Error?) -> Void)? = nil) {
        let bufferWrapper = UnsafeSendableWrapper(value: confidenceMap)
        writeQueue.async {
            let confidenceMap = bufferWrapper.value
            CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly) }
            
            let width = CVPixelBufferGetWidth(confidenceMap)
            let height = CVPixelBufferGetHeight(confidenceMap)
            
            guard let baseAddress = CVPixelBufferGetBaseAddress(confidenceMap) else {
                completion?(ExportError.bufferAccessFailed)
                return
            }
            
            let pointer = baseAddress.assumingMemoryBound(to: UInt8.self)
            
            // Scale 0,1,2 → 0, 127, 255 for visibility
            var scaledData = [UInt8](repeating: 0, count: width * height)
            for i in 0..<(width * height) {
                switch pointer[i] {
                case 0: scaledData[i] = 0     // Low
                case 1: scaledData[i] = 127   // Medium
                case 2: scaledData[i] = 255   // High
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
                    completion?(ExportError.conversionFailed)
                    return
                }
                
                do {
                    try pngData.write(to: url)
                    completion?(nil)
                } catch {
                    completion?(error)
                }
            }
        }
    }
    
    // MARK: - Point Cloud Export (PLY)
    
    func savePointCloudPLY(
        points: [(position: simd_float3, color: simd_float3)],
        to url: URL,
        completion: ((Error?) -> Void)? = nil
    ) {
        writeQueue.async {
            var ply = "ply\n"
            ply += "format ascii 1.0\n"
            ply += "element vertex \(points.count)\n"
            ply += "property float x\n"
            ply += "property float y\n"
            ply += "property float z\n"
            ply += "property uchar red\n"
            ply += "property uchar green\n"
            ply += "property uchar blue\n"
            ply += "end_header\n"
            
            for point in points {
                let r = UInt8(max(0, min(255, point.color.x * 255)))
                let g = UInt8(max(0, min(255, point.color.y * 255)))
                let b = UInt8(max(0, min(255, point.color.z * 255)))
                ply += "\(point.position.x) \(point.position.y) \(point.position.z) \(r) \(g) \(b)\n"
            }
            
            do {
                try ply.write(to: url, atomically: true, encoding: .utf8)
                completion?(nil)
            } catch {
                completion?(error)
            }
        }
    }
    
    // MARK: - Mesh Export (OBJ)
    
    func saveMeshOBJ(meshAnchors: [ARMeshAnchor], to url: URL, completion: ((Error?) -> Void)? = nil) {
        writeQueue.async {
            var obj = "# DIET SfM Capture - ARKit Mesh\n"
            var vertexOffset = 0
            
            for anchor in meshAnchors {
                let geometry = anchor.geometry
                let vertices = geometry.vertices
                let faces = geometry.faces
                let transform = anchor.transform
                
                // Vertices
                for i in 0..<vertices.count {
                    let vertex = geometry.vertex(at: UInt32(i))
                    let localPos = simd_float4(vertex.0, vertex.1, vertex.2, 1.0)
                    let worldPos = transform * localPos
                    obj += "v \(worldPos.x) \(worldPos.y) \(worldPos.z)\n"
                }
                
                // Faces
                let indexCount = faces.count * 3
                for i in stride(from: 0, to: indexCount, by: 3) {
                    let i0 = geometry.faceIndex(at: UInt32(i)) + UInt32(vertexOffset) + 1
                    let i1 = geometry.faceIndex(at: UInt32(i + 1)) + UInt32(vertexOffset) + 1
                    let i2 = geometry.faceIndex(at: UInt32(i + 2)) + UInt32(vertexOffset) + 1
                    obj += "f \(i0) \(i1) \(i2)\n"
                }
                
                vertexOffset += vertices.count
            }
            
            do {
                try obj.write(to: url, atomically: true, encoding: .utf8)
                completion?(nil)
            } catch {
                completion?(error)
            }
        }
    }
    
    // MARK: - Pose Export
    
    func savePose(_ transform: simd_float4x4, to url: URL, completion: ((Error?) -> Void)? = nil) {
        writeQueue.async {
            let cols = transform.columns
            let text = """
            \(cols.0.x) \(cols.0.y) \(cols.0.z) \(cols.0.w)
            \(cols.1.x) \(cols.1.y) \(cols.1.z) \(cols.1.w)
            \(cols.2.x) \(cols.2.y) \(cols.2.z) \(cols.2.w)
            \(cols.3.x) \(cols.3.y) \(cols.3.z) \(cols.3.w)
            """
            
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                completion?(nil)
            } catch {
                completion?(error)
            }
        }
    }
    
    // MARK: - Intrinsics Export
    
    func saveIntrinsics(_ intrinsics: simd_float3x3, frameIndex: Int, to url: URL, completion: ((Error?) -> Void)? = nil) {
        writeQueue.async {
            let cols = intrinsics.columns
            let data: [String: Any] = [
                "frame_index": frameIndex,
                "fx": cols.0.x,
                "fy": cols.1.y,
                "cx": cols.2.x,
                "cy": cols.2.y,
                "matrix": [
                    [cols.0.x, cols.0.y, cols.0.z],
                    [cols.1.x, cols.1.y, cols.1.z],
                    [cols.2.x, cols.2.y, cols.2.z]
                ]
            ]
            
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: data, options: .prettyPrinted)
                try jsonData.write(to: url)
                completion?(nil)
            } catch {
                completion?(error)
            }
        }
    }
    
    // MARK: - Float16 Conversion for EXR
    
    static func floatToHalf(_ value: Float) -> UInt16 {
        let bits = value.bitPattern
        let sign = (bits >> 31) & 0x1
        let exponent = Int((bits >> 23) & 0xFF) - 127
        let mantissa = bits & 0x7FFFFF
        
        if exponent > 15 {
            // Overflow → infinity
            return UInt16((sign << 15) | 0x7C00)
        } else if exponent < -14 {
            // Underflow → zero or denormal
            if exponent < -24 {
                return UInt16(sign << 15)
            }
            let m = (mantissa | 0x800000) >> (14 - exponent + 23)  // Fixed: should be (-1 - exponent + 13)
            return UInt16((sign << 15) | m)
        } else {
            let halfExponent = UInt16(exponent + 15)
            let halfMantissa = UInt16(mantissa >> 13)
            return UInt16(sign << 15) | (halfExponent << 10) | halfMantissa
        }
    }
    
    // MARK: - Minimal EXR File Builder
    
    static func buildEXRFile(width: Int, height: Int, channelName: String, halfPixelData: [UInt16]) throws -> Data {
        var data = Data()
        
        // Magic number
        data.append(contentsOf: [0x76, 0x2F, 0x31, 0x01])  // EXR magic
        
        // Version
        var version: UInt32 = 2
        data.append(Data(bytes: &version, count: 4))
        
        // Header attributes
        func writeAttribute(name: String, type: String, value: Data) {
            data.append(name.data(using: .utf8)!)
            data.append(0)  // null terminator
            data.append(type.data(using: .utf8)!)
            data.append(0)
            var size = Int32(value.count)
            data.append(Data(bytes: &size, count: 4))
            data.append(value)
        }
        
        // channels attribute
        var channelsData = Data()
        channelsData.append(channelName.data(using: .utf8)!)
        channelsData.append(0)
        var pixelType: Int32 = 1  // HALF
        channelsData.append(Data(bytes: &pixelType, count: 4))
        var pLinear: UInt8 = 0
        channelsData.append(Data(bytes: &pLinear, count: 1))
        var reserved = [UInt8](repeating: 0, count: 3)
        channelsData.append(Data(bytes: &reserved, count: 3))
        var xSampling: Int32 = 1
        channelsData.append(Data(bytes: &xSampling, count: 4))
        var ySampling: Int32 = 1
        channelsData.append(Data(bytes: &ySampling, count: 4))
        channelsData.append(0)  // end of channel list
        writeAttribute(name: "channels", type: "chlist", value: channelsData)
        
        // compression: none
        var compressionData = Data()
        var compression: UInt8 = 0  // NO_COMPRESSION
        compressionData.append(Data(bytes: &compression, count: 1))
        writeAttribute(name: "compression", type: "compression", value: compressionData)
        
        // dataWindow
        var dataWindow = Data()
        var xMin: Int32 = 0, yMin: Int32 = 0
        var xMax = Int32(width - 1), yMax = Int32(height - 1)
        dataWindow.append(Data(bytes: &xMin, count: 4))
        dataWindow.append(Data(bytes: &yMin, count: 4))
        dataWindow.append(Data(bytes: &xMax, count: 4))
        dataWindow.append(Data(bytes: &yMax, count: 4))
        writeAttribute(name: "dataWindow", type: "box2i", value: dataWindow)
        
        // displayWindow (same)
        writeAttribute(name: "displayWindow", type: "box2i", value: dataWindow)
        
        // lineOrder
        var lineOrderData = Data()
        var lineOrder: UInt8 = 0  // INCREASING_Y
        lineOrderData.append(Data(bytes: &lineOrder, count: 1))
        writeAttribute(name: "lineOrder", type: "lineOrder", value: lineOrderData)
        
        // pixelAspectRatio
        var parData = Data()
        var par: Float = 1.0
        parData.append(Data(bytes: &par, count: 4))
        writeAttribute(name: "pixelAspectRatio", type: "float", value: parData)
        
        // screenWindowCenter
        var swcData = Data()
        var swcX: Float = 0, swcY: Float = 0
        swcData.append(Data(bytes: &swcX, count: 4))
        swcData.append(Data(bytes: &swcY, count: 4))
        writeAttribute(name: "screenWindowCenter", type: "v2f", value: swcData)
        
        // screenWindowWidth
        var swwData = Data()
        var sww: Float = 1.0
        swwData.append(Data(bytes: &sww, count: 4))
        writeAttribute(name: "screenWindowWidth", type: "float", value: swwData)
        
        // End of header
        data.append(0)
        
        // Scanline offset table
        let bytesPerScanline = width * 2  // HALF = 2 bytes
        let scanlineDataSize = 4 + 4 + bytesPerScanline  // y-coord + pixel-data-size + data
        let offsetTableStart = data.count
        let offsetTableSize = height * 8  // 64-bit offsets
        let firstScanlineOffset = UInt64(offsetTableStart + offsetTableSize)
        
        for y in 0..<height {
            var offset = firstScanlineOffset + UInt64(y * scanlineDataSize)
            data.append(Data(bytes: &offset, count: 8))
        }
        
        // Scanline data
        for y in 0..<height {
            var yCoord = Int32(y)
            data.append(Data(bytes: &yCoord, count: 4))
            var dataSize = Int32(bytesPerScanline)
            data.append(Data(bytes: &dataSize, count: 4))
            
            let rowStart = y * width
            for x in 0..<width {
                var halfValue = halfPixelData[rowStart + x]
                data.append(Data(bytes: &halfValue, count: 2))
            }
        }
        
        return data
    }
}

// MARK: - ARMeshGeometry Extensions

extension ARMeshGeometry {
    func vertex(at index: UInt32) -> (Float, Float, Float) {
        let vertexPointer = vertices.buffer.contents().advanced(by: vertices.offset + Int(index) * vertices.stride)
        let vertex = vertexPointer.assumingMemoryBound(to: SIMD3<Float>.self).pointee
        return (vertex.x, vertex.y, vertex.z)
    }
    
    func faceIndex(at index: UInt32) -> UInt32 {
        let indexPointer = faces.buffer.contents().advanced(by: faces.indexCountPerPrimitive * Int(index) * MemoryLayout<UInt32>.size)
        return indexPointer.assumingMemoryBound(to: UInt32.self).pointee
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
