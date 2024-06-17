//
//  ContentView.swift
//  InnoDemo
//
//  Created by Gary on 2024/6/11.
//

import SwiftUI
import RealityKit
import RealityKitContent
import PlayerCore

struct ContentView: View {
    @ObservedObject private var _model = model
    @State private var coordinator = MoonVideoPlayer.Coordinator()
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false

    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    var body: some View {
        VStack {
            Button("seek") {
                coordinator.seek(time: 0)
            }
            
            let url = Bundle.main.url(forResource: "pi_output", withExtension: "mkv")!
            
            MoonVideoPlayer(coordinator: coordinator, url: url, options: model.options)
                .onStateChanged { playerLayer, state in
                    if state == .readyToPlay {
                        playerLayer.play()
                    }
                }
                .onBufferChanged { bufferedCount, consumeTime in
                    print("bufferedCount \(bufferedCount), consumeTime \(consumeTime)")
                }
            
            ImmersiveView()
        }
        .padding()
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
}
