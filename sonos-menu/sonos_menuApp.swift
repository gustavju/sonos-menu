//
//  sonos_menuApp.swift
//  sonos-menu
//

import SwiftUI

@main
struct sonos_menuApp: App {
    @State private var repository = SonosRepository(
        discovery: SSDPDiscoveryService(),
        controller: SonosController()
    )

    var body: some Scene {
        MenuBarExtra("Sonos", systemImage: "speaker.wave.2.fill") {
            ContentView(repository: repository)
        }
        .menuBarExtraStyle(.window)
    }
}
