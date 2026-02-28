// AdaptiveMeshRefinement.swift
// ReScan
//
// Adaptive mesh refinement service: tracks spatial observation density using a voxel grid
// and performs progressive triangle subdivision on regions with higher observation counts.
// This produces meshes with increased detail in areas that have been scanned more thoroughly.

import Foundation
import ARKit

// MARK: - Spatial Voxel Key

/// Hash key for a voxel cell in the spatial grid.
struct VoxelKey: Hashable {
    let x: Int
    let y: Int
    let z: Int
}

// MARK: - Spatial Cell

/// Tracks observation data for a single voxel cell.
struct SpatialCell {
    var observationCount: Int = 0
    var lastObservedTime: TimeInterval = 0
}

// MARK: - Mesh Statistics

/// Summary of the current mesh state, including refinement metrics.
struct MeshStatistics {
    var totalVertices: Int = 0
    var totalFaces: Int = 0
    var refinedRegions: Int = 0
    var totalObservations: Int = 0
}

// MARK: - Adaptive Mesh Refinement Service

final class AdaptiveMeshRefinement {

    // MARK: - Configuration

    /// Size of each voxel cell in meters.
    private let cellSize: Float

    /// Minimum number of observations before a region is considered for subdivision.
    private let subdivisionThreshold: Int

    /// Maximum number of recursive subdivision passes.
    private let maxSubdivisionLevel: Int

    // MARK: - Spatial Grid

    /// Voxel grid storing observation counts per cell.
    private var grid: [VoxelKey: SpatialCell] = [:]

    /// Lock for thread-safe access to the grid.
    private let lock = NSLock()

    // MARK: - Statistics

    private(set) var statistics = MeshStatistics()

    // MARK: - Init

    init(detailLevel: MeshDetailLevel = .medium) {
        switch detailLevel {
        case .low:
            cellSize = 0.10
            subdivisionThreshold = 6
            maxSubdivisionLevel = 1
        case .medium:
            cellSize = 0.05
            subdivisionThreshold = 4
            maxSubdivisionLevel = 2
        case .high:
            cellSize = 0.03
            subdivisionThreshold = 3
            maxSubdivisionLevel = 3
        }
    }

    // MARK: - Observation Tracking

    /// Records observations for all vertices in the given mesh anchors.
    /// Call this periodically (e.g. every AR frame) during capture.
    func recordObservations(anchors: [ARMeshAnchor], timestamp: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }

        for anchor in anchors {
            let geometry = anchor.geometry
            let transform = anchor.transform
            let vertexBuffer = geometry.vertices.buffer.contents()
            let vertexStride = geometry.vertices.stride
            let vertexCount = geometry.vertices.count

            for i in 0..<vertexCount {
                let ptr = vertexBuffer.advanced(by: i * vertexStride)
                let localPos = ptr.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                let worldPos = transform * SIMD4<Float>(localPos.x, localPos.y, localPos.z, 1.0)
                let key = voxelKey(for: SIMD3<Float>(worldPos.x, worldPos.y, worldPos.z))

                var cell = grid[key] ?? SpatialCell()
                cell.observationCount += 1
                cell.lastObservedTime = timestamp
                grid[key] = cell
            }
        }

        // Update statistics
        statistics.totalObservations = grid.values.reduce(0) { $0 + $1.observationCount }
        statistics.refinedRegions = grid.values.filter { $0.observationCount >= subdivisionThreshold }.count
    }

    // MARK: - Refined Mesh Export

    /// Builds a refined mesh from the given anchors by applying adaptive subdivision
    /// to triangles whose vertices fall in high-observation regions.
    ///
    /// Returns arrays of world-space vertices and triangle face indices ready for OBJ export.
    func buildRefinedMesh(from anchors: [ARMeshAnchor]) -> (vertices: [SIMD3<Float>], faces: [[Int32]]) {
        lock.lock()
        let gridSnapshot = grid
        lock.unlock()

        var allVertices: [SIMD3<Float>] = []
        var allFaces: [[Int32]] = []
        var vertexOffset: Int32 = 0

        for anchor in anchors {
            let geometry = anchor.geometry
            let transform = anchor.transform
            let vertexCount = geometry.vertices.count

            // Extract world-space vertices
            let vertexBuffer = geometry.vertices.buffer.contents()
            let vertexStride = geometry.vertices.stride
            var anchorVertices: [SIMD3<Float>] = []
            anchorVertices.reserveCapacity(vertexCount)

            for i in 0..<vertexCount {
                let ptr = vertexBuffer.advanced(by: i * vertexStride)
                let local = ptr.assumingMemoryBound(to: SIMD3<Float>.self).pointee
                let world = transform * SIMD4<Float>(local.x, local.y, local.z, 1.0)
                anchorVertices.append(SIMD3<Float>(world.x, world.y, world.z))
            }

            // Extract face indices
            let faceCount = geometry.faces.count
            let indexBuffer = geometry.faces.buffer.contents()
            let bytesPerIndex = geometry.faces.bytesPerIndex
            let indicesPerFace = geometry.faces.indexCountPerPrimitive

            for i in 0..<faceCount {
                var indices: [Int] = []
                for j in 0..<indicesPerFace {
                    let offset = (i * indicesPerFace + j) * bytesPerIndex
                    let ptr = indexBuffer.advanced(by: offset)
                    let idx: Int
                    if bytesPerIndex == 4 {
                        idx = Int(ptr.assumingMemoryBound(to: UInt32.self).pointee)
                    } else {
                        idx = Int(ptr.assumingMemoryBound(to: UInt16.self).pointee)
                    }
                    indices.append(idx)
                }

                guard indices.count == 3 else { continue }

                let v0 = anchorVertices[indices[0]]
                let v1 = anchorVertices[indices[1]]
                let v2 = anchorVertices[indices[2]]

                // Determine subdivision level based on observation density
                let level = subdivisionLevel(for: v0, v1, v2, grid: gridSnapshot)

                if level > 0 {
                    // Subdivide triangle and append
                    let (subVerts, subFaces) = subdivideTriangle(v0, v1, v2, level: level, baseIndex: vertexOffset)
                    allVertices.append(contentsOf: subVerts)
                    allFaces.append(contentsOf: subFaces)
                    vertexOffset += Int32(subVerts.count)
                } else {
                    // Keep original triangle
                    let base = vertexOffset
                    allVertices.append(contentsOf: [v0, v1, v2])
                    allFaces.append([base, base + 1, base + 2])
                    vertexOffset += 3
                }
            }
        }

        statistics.totalVertices = allVertices.count
        statistics.totalFaces = allFaces.count

        return (allVertices, allFaces)
    }

    // MARK: - Reset

    /// Clears all observation data and resets statistics.
    func reset() {
        lock.lock()
        grid.removeAll()
        statistics = MeshStatistics()
        lock.unlock()
    }

    // MARK: - Private Helpers

    /// Converts a world-space position to a voxel grid key.
    private func voxelKey(for position: SIMD3<Float>) -> VoxelKey {
        VoxelKey(
            x: Int(floor(position.x / cellSize)),
            y: Int(floor(position.y / cellSize)),
            z: Int(floor(position.z / cellSize))
        )
    }

    /// Determines how many times to subdivide a triangle based on the average observation
    /// count of its vertices' voxel cells.
    private func subdivisionLevel(
        for v0: SIMD3<Float>,
        _ v1: SIMD3<Float>,
        _ v2: SIMD3<Float>,
        grid: [VoxelKey: SpatialCell]
    ) -> Int {
        let obs0 = grid[voxelKey(for: v0)]?.observationCount ?? 0
        let obs1 = grid[voxelKey(for: v1)]?.observationCount ?? 0
        let obs2 = grid[voxelKey(for: v2)]?.observationCount ?? 0
        let avgObs = (obs0 + obs1 + obs2) / 3

        if avgObs < subdivisionThreshold {
            return 0
        }

        // Scale subdivision level with observation density, capped at max
        let level = min(maxSubdivisionLevel, 1 + (avgObs - subdivisionThreshold) / subdivisionThreshold)
        return max(0, level)
    }

    /// Performs midpoint subdivision of a triangle, recursively up to `level` times.
    ///
    /// Each level splits one triangle into 4 by inserting midpoints on each edge:
    /// ```
    ///       v0
    ///      / \
    ///    m01 - m02
    ///    / \ | / \
    ///  v1 - m12 - v2
    /// ```
    ///
    /// Returns the new vertices and face index arrays (using `baseIndex` as offset).
    private func subdivideTriangle(
        _ v0: SIMD3<Float>,
        _ v1: SIMD3<Float>,
        _ v2: SIMD3<Float>,
        level: Int,
        baseIndex: Int32
    ) -> (vertices: [SIMD3<Float>], faces: [[Int32]]) {
        if level <= 0 {
            return ([v0, v1, v2], [[baseIndex, baseIndex + 1, baseIndex + 2]])
        }

        // Single-level subdivision into 4 triangles
        let m01 = (v0 + v1) * 0.5
        let m12 = (v1 + v2) * 0.5
        let m02 = (v0 + v2) * 0.5

        if level == 1 {
            // 6 vertices, 4 faces
            let verts = [v0, v1, v2, m01, m12, m02]
            let b = baseIndex
            let faces: [[Int32]] = [
                [b + 0, b + 3, b + 5],  // v0, m01, m02
                [b + 3, b + 1, b + 4],  // m01, v1, m12
                [b + 5, b + 4, b + 2],  // m02, m12, v2
                [b + 3, b + 4, b + 5],  // m01, m12, m02 (center)
            ]
            return (verts, faces)
        }

        // Recursive subdivision: subdivide each of the 4 sub-triangles
        var allVerts: [SIMD3<Float>] = []
        var allFaces: [[Int32]] = []
        var currentBase = baseIndex

        let subTriangles: [(SIMD3<Float>, SIMD3<Float>, SIMD3<Float>)] = [
            (v0, m01, m02),
            (m01, v1, m12),
            (m02, m12, v2),
            (m01, m12, m02),
        ]

        for (a, b, c) in subTriangles {
            let (sv, sf) = subdivideTriangle(a, b, c, level: level - 1, baseIndex: currentBase)
            allVerts.append(contentsOf: sv)
            allFaces.append(contentsOf: sf)
            currentBase += Int32(sv.count)
        }

        return (allVerts, allFaces)
    }
}
