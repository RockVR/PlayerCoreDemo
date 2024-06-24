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

class currentPlayItem: Equatable {
    let title: String
    var originalUrl: String
    var url: String {
        get {
            return _url
        }
        set(newURL) {
            _url = newURL
        }
    }
    
    var isMultiview: Bool = false
    var comment: String = ""
    private var _url: String = ""
    
    init(title: String, originalUrl: String, url: String, isMultiview: Bool = false) {
        self.title = title
        self.originalUrl = originalUrl
        self._url = url
        self.isMultiview = isMultiview
    }
    
    static func == (lhs: currentPlayItem, rhs: currentPlayItem) -> Bool {
        return lhs.originalUrl == rhs.originalUrl
    }
}
