//
//  sonos_menuApp.swift
//  sonos-menu
//

import SwiftUI

@main
struct sonos_menuApp: App {
    var body: some Scene {
        MenuBarExtra("Sonos", systemImage: "speaker.wave.2.fill") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
