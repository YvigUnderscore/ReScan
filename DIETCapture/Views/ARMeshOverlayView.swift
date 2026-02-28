// ARMeshOverlayView.swift
// ReScan
//
// Overlay view using ARSCNView to render the ARKit Scene Reconstruction mesh
// for real-time coverage visualization.

import SwiftUI
import ARKit
import SceneKit

struct ARMeshOverlayView: UIViewRepresentable {
    let session: ARSession
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        arView.session = session
        // ARSCNView renders the live camera feed as its scene background automatically,
        // giving us RGB + mesh in a single view without a separate SwiftUI preview layer.
        arView.backgroundColor = .black
        
        arView.delegate = context.coordinator
        
        // Setup lighting
        arView.autoenablesDefaultLighting = true
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        // No-op
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        // Semi-transparent colored material for the mesh
        private lazy var meshMaterial: SCNMaterial = {
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.cyan.withAlphaComponent(0.6)
            material.isDoubleSided = true
            return material
        }()
        
        // Outline material (wireframe)
        private lazy var wireframeMaterial: SCNMaterial = {
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.white
            material.fillMode = .lines
            return material
        }()
        
        // MARK: - ARSCNViewDelegate
        
        func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
            guard let meshAnchor = anchor as? ARMeshAnchor else { return nil }
            
            // Create geometry from ARMeshAnchor
            let geometry = SCNGeometry(meshAnchor: meshAnchor)
            
            // Apply materials: colored faces + wireframe outline
            geometry.materials = [meshMaterial, wireframeMaterial]
            
            // Create node
            let node = SCNNode(geometry: geometry)
            return node
        }
        
        func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
            guard let meshAnchor = anchor as? ARMeshAnchor else { return }
            
            // Update geometry when the mesh changes
            let newGeometry = SCNGeometry(meshAnchor: meshAnchor)
            newGeometry.materials = [meshMaterial, wireframeMaterial]
            node.geometry = newGeometry
        }
    }
}

// MARK: - Helper to convert ARMeshAnchor to SCNGeometry
extension SCNGeometry {
    convenience init(meshAnchor: ARMeshAnchor) {
        let vertices = meshAnchor.geometry.vertices
        let faces = meshAnchor.geometry.faces
        
        let vertexSource = SCNGeometrySource(
            buffer: vertices.buffer,
            vertexFormat: vertices.format,
            semantic: .vertex,
            vertexCount: vertices.count,
            dataOffset: vertices.offset,
            dataStride: vertices.stride
        )
        
        let faceData = Data(
            bytesNoCopy: faces.buffer.contents(),
            count: faces.buffer.length,
            deallocator: .none
        )
        
        let geometryElement = SCNGeometryElement(
            data: faceData,
            primitiveType: .triangles,
            primitiveCount: faces.count,
            bytesPerIndex: faces.bytesPerIndex
        )
        
        self.init(sources: [vertexSource], elements: [geometryElement])
    }
}
