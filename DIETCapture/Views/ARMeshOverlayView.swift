// ARMeshOverlayView.swift
// ReScan
//
// Overlay view using ARSCNView to render the ARKit Scene Reconstruction mesh
// for real-time coverage visualization.

import SwiftUI
import ARKit
import SceneKit

struct ARMeshOverlayView: UIViewRepresentable {
    enum CameraBehavior {
        case followDevice
        case fixedOverview
    }

    let session: ARSession
    var cameraBehavior: CameraBehavior = .followDevice
    var fieldOfView: CGFloat = 60
    
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView(frame: .zero)
        arView.session = session
        // ARSCNView renders the live camera feed as its scene background automatically,
        // giving us RGB + mesh in a single view without a separate SwiftUI preview layer.
        arView.backgroundColor = .black
        
        arView.delegate = context.coordinator
        
        // Setup lighting
        arView.autoenablesDefaultLighting = true
        context.coordinator.configure(view: arView, cameraBehavior: cameraBehavior, fieldOfView: fieldOfView)
        
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.configure(view: uiView, cameraBehavior: cameraBehavior, fieldOfView: fieldOfView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, ARSCNViewDelegate {
        private let cameraNode = SCNNode()

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

        func configure(view: ARSCNView, cameraBehavior: CameraBehavior, fieldOfView: CGFloat) {
            switch cameraBehavior {
            case .followDevice:
                view.pointOfView = nil
                view.scene.background.contents = UIColor.clear

            case .fixedOverview:
                if cameraNode.camera == nil {
                    let camera = SCNCamera()
                    camera.zNear = 0.01
                    camera.zFar = 100
                    cameraNode.camera = camera
                }
                if cameraNode.parent == nil {
                    view.scene.rootNode.addChildNode(cameraNode)
                }

                cameraNode.camera?.fieldOfView = max(20, min(110, fieldOfView))
                cameraNode.position = SCNVector3(0, 1.6, 2.4)
                cameraNode.look(at: SCNVector3(0, 0, 0))
                view.pointOfView = cameraNode
                view.scene.background.contents = UIColor.black
            }
        }
        
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
