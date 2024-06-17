//
//  ImmersiveView.swift
//  InnoDemo
//
//  Created by Gary on 2024/6/11.
//

import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    @ObservedObject var appModel = model
    
    var body: some View {
        RealityView { content in
            // Init TextureResource
            let img = UIImage.dummyImage(width: 1, height: 1).cgImage
            do {
                appModel.textureResource = try .generate(from: img!, withName: "input", options: .init(semantic: .color))
            } catch {
                print(error)
            }
            
            if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
                if let root = scene.findEntity(named: "Root") {
                    print(root.children)
                    if let mesh = root.findEntity(named: "Cube") as? ModelEntity {
                        
                        let width: Float = 1.6
                        let height: Float = 0.9
                        let depth: Float = 0.1
                        
                        let rectangularMesh = MeshResource.generateBox(size: [width, height, depth])
                        mesh.model = ModelComponent(mesh: rectangularMesh, materials: mesh.model!.materials)
                        
//                        mesh.position = [0, 0, -1]
                        
                        if var mat = mesh.model?.materials.first as? ShaderGraphMaterial {
                            do {
                                let uvTransform = simd_float4x4(float4(-1, 0, 0, 0),
                                                                float4(0, 1, 0, 0),
                                                                float4(0, 0, 1, 0),
                                                                float4(0, 0, 0, 1))
                                
                                try mat.setParameter(name: "monoInput", value: .textureResource(appModel.textureResource!))
                                try mat.setParameter(name: "monoInput_UVTransform", value: .float4x4(uvTransform))
                            } catch {
                                print(error)
                            }
                            
                            if appModel.material == nil {
                                appModel.material = mat
                            }
                            
                            mesh.model?.materials = [mat]
                        }
                        
                        content.add(mesh)
                    }
                    
                }
            }
        }
    }
}

extension UIImage {
    static func dummyImage(width: Double, height: Double) -> UIImage {
        let rect = CGRect(origin: .zero, size: CGSize(width: width, height: height))
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, 0.0)
        UIColor.black.setFill()
        UIRectFill(rect)
        let image = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return image
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
}
