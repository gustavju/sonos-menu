//
//  PlaybackMode.swift
//  sonos-menu
//
//  Shuffle and repeat modes for group playback.
//

import Foundation

enum ShuffleMode: String, Codable, Hashable, Sendable, CaseIterable {
    case off = "OFF"
    case on = "ON"
}

enum RepeatMode: String, Codable, Hashable, Sendable, CaseIterable {
    case off = "OFF"
    case all = "ALL"
    case one = "ONE"
}
