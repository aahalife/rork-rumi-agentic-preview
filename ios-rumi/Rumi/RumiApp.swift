//
//  RumiApp.swift
//  Rumi
//
//  Created by Rork on October 23, 2026.
//

import SwiftUI

@main
struct RumiApp: App {
    init() {
        FontRegistrar.registerAll()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
