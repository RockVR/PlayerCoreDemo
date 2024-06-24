//
//  InnoDemoApp.swift
//  InnoDemo
//
//  Created by Gary on 2024/6/11.
//

import SwiftUI
import PlayerCore

var model = Model()

@main
struct InnoDemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView(model: model, coordinator: MoonVideoPlayer.Coordinator())
        }

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }.immersionStyle(selection: .constant(.full), in: .full)
    }
}
