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
                        if var mat = mesh.model?.materials.first as? ShaderGraphMaterial {
                            do {
                                try mat.setParameter(name: "monoInput", value: .textureResource(appModel.textureResource!))
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
