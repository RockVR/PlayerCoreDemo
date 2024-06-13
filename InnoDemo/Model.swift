//
//  Model.swift
//  InnoDemo
//
//  Created by player on 2024/6/13.
//

import Foundation
import RealityKit
import PlayerCore

class Model: ObservableObject {
    @Published var options: MoonOptions = MoonOptions()
    
    @Published public var material: ShaderGraphMaterial? = nil {
        willSet {
            options.videoMaterial = newValue
        }
    }
    
    @Published public var textureResource: TextureResource? = nil {
        willSet {
            options.textureResource = newValue
        }
    }
    
    init() {
        options.useDisplayLayer = false
    }
}
