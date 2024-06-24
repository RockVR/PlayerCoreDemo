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
    @ObservedObject private var model: Model
    @ObservedObject private var coordinator: MoonVideoPlayer.Coordinator
    @ObservedObject private var timeModel: ControllerTimeModel
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false
    @State private var urlString = ""

    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    init(model: Model, coordinator: MoonVideoPlayer.Coordinator) {
        self.model = model
        self.coordinator = coordinator
        self.timeModel = coordinator.timemodel
    }

    var body: some View {
        VStack {
            Button("seek") {
                coordinator.seek(time: 0)
            }
            
            Slider(value: Binding {
                Double(timeModel.currentTime)
            } set: { newValue, _ in
                timeModel.currentTime = Int(newValue)
            }, in: 0 ... Double(timeModel.totalTime)) { onEditingChanged in
                if onEditingChanged {
                    coordinator.playerLayer?.pause()
                } else {
                    coordinator.seek(time: TimeInterval(timeModel.currentTime))
                }
            }
//
//            let url = Bundle.main.url(forResource: "pi_output", withExtension: "mkv")!
            if !urlString.isEmpty {
                let url =  URL(string: urlString)!
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
        }
        .onAppear() {
            Task {
                let url = "https://m.youtube.com/watch?v=zhseic0xcr4"
                gotoTarget(urlString: url)
                let item = await parseUrlAndPlay()
                self.urlString = item!.url
            }
        }
        .padding()
    }
}

#Preview(windowStyle: .automatic) {
    ContentView(model: model, coordinator: MoonVideoPlayer.Coordinator())
}
