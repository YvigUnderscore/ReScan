// COLMAPExporter.swift
// DIETCapture
//
// Exports camera poses and intrinsics in COLMAP-compatible text format.

import Foundation
import simd

final class COLMAPExporter {
    
    // MARK: - cameras.txt
    
    /// Generate cameras.txt content.
    /// Format: CAMERA_ID MODEL WIDTH HEIGHT PARAMS
    /// Using PINHOLE model: fx fy cx cy
    static func generateCamerasTxt(
        intrinsics: simd_float3x3,
        imageWidth: Int,
        imageHeight: Int,
        cameraId: Int = 1
    ) -> String {
        var result = "# Camera list with one line of data per camera:\n"
        result += "# CAMERA_ID, MODEL, WIDTH, HEIGHT, PARAMS[]\n"
        result += "# Number of cameras: 1\n"
        
        let fx = intrinsics.columns.0.x
        let fy = intrinsics.columns.1.y
        let cx = intrinsics.columns.2.x
        let cy = intrinsics.columns.2.y
        
        result += "\(cameraId) PINHOLE \(imageWidth) \(imageHeight) \(fx) \(fy) \(cx) \(cy)\n"
        
        return result
    }
    
    // MARK: - images.txt
    
    /// Generate images.txt content.
    /// Format: IMAGE_ID QW QX QY QZ TX TY TZ CAMERA_ID NAME
    ///         (empty line for 2D points, left blank)
    static func generateImagesTxt(
        frames: [CaptureFrameMetadata],
        imageExtension: String = "heif",
        cameraId: Int = 1
    ) -> String {
        var result = "# Image list with two lines of data per image:\n"
        result += "# IMAGE_ID, QW, QX, QY, QZ, TX, TY, TZ, CAMERA_ID, NAME\n"
        result += "# POINTS2D[] as (X, Y, POINT3D_ID)\n"
        result += "# Number of images: \(frames.count)\n"
        
        for frame in frames {
            // Reconstruct the 4x4 matrix
            let pose = matrixFromArray(frame.cameraPose)
            
            // COLMAP uses world-to-camera, ARKit gives camera-to-world
            // We need to invert
            let worldToCamera = simd_inverse(pose)
            
            // Extract rotation as quaternion
            let rotation = simd_quatf(worldToCamera)
            
            // Extract translation
            let tx = worldToCamera.columns.3.x
            let ty = worldToCamera.columns.3.y
            let tz = worldToCamera.columns.3.z
            
            let imageId = frame.frameIndex + 1  // COLMAP uses 1-based IDs
            let name = "frame_\(String(format: "%06d", frame.frameIndex)).\(imageExtension)"
            
            result += "\(imageId) \(rotation.real) \(rotation.imag.x) \(rotation.imag.y) \(rotation.imag.z) \(tx) \(ty) \(tz) \(cameraId) \(name)\n"
            result += "\n"  // Empty line for 2D points
        }
        
        return result
    }
    
    // MARK: - points3D.txt (empty placeholder)
    
    static func generatePoints3DTxt() -> String {
        return "# 3D point list with one line of data per point:\n# POINT3D_ID, X, Y, Z, R, G, B, ERROR, TRACK[] as (IMAGE_ID, POINT2D_IDX)\n# Number of points: 0\n"
    }
    
    // MARK: - Export All
    
    static func exportAll(
        frames: [CaptureFrameMetadata],
        intrinsics: simd_float3x3,
        imageWidth: Int,
        imageHeight: Int,
        imageExtension: String = "heif",
        to directory: URL
    ) throws {
        let camerasTxt = generateCamerasTxt(
            intrinsics: intrinsics,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )
        try camerasTxt.write(
            to: directory.appendingPathComponent("cameras.txt"),
            atomically: true,
            encoding: .utf8
        )
        
        let imagesTxt = generateImagesTxt(
            frames: frames,
            imageExtension: imageExtension
        )
        try imagesTxt.write(
            to: directory.appendingPathComponent("images.txt"),
            atomically: true,
            encoding: .utf8
        )
        
        let points3DTxt = generatePoints3DTxt()
        try points3DTxt.write(
            to: directory.appendingPathComponent("points3D.txt"),
            atomically: true,
            encoding: .utf8
        )
    }
    
    // MARK: - Helpers
    
    private static func matrixFromArray(_ array: [[Float]]) -> simd_float4x4 {
        guard array.count == 4, array.allSatisfy({ $0.count == 4 }) else {
            return matrix_identity_float4x4
        }
        return simd_float4x4(
            simd_float4(array[0][0], array[0][1], array[0][2], array[0][3]),
            simd_float4(array[1][0], array[1][1], array[1][2], array[1][3]),
            simd_float4(array[2][0], array[2][1], array[2][2], array[2][3]),
            simd_float4(array[3][0], array[3][1], array[3][2], array[3][3])
        )
    }
}
