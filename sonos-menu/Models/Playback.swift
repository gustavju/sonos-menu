//
//  Playback.swift
//  sonos-menu
//
//  Playback state for a Sonos group. Track metadata, transport state, and
//  playback mode controls are owned by the group, not individual rooms.
//

import Foundation

struct Playback: Codable, Hashable, Sendable {
    enum TransportState: String, Codable, Sendable {
        case playing = "PLAYING"
        case pausedPlayback = "PAUSED_PLAYBACK"
        case stopped = "STOPPED"
        case transitioning = "TRANSITIONING"
        case unknown = "UNKNOWN"

        var isPlaying: Bool {
            self == .playing || self == .transitioning
        }
    }

    var title: String
    var artist: String
    var album: String
    var artURL: URL?
    var transportState: TransportState

    /// Future: surface the group's queue and support queue navigation.
    var queuePosition: Int?
    var queueLength: Int?

    var shuffle: ShuffleMode
    var `repeat`: RepeatMode

    nonisolated init(
        title: String = "",
        artist: String = "",
        album: String = "",
        artURL: URL? = nil,
        transportState: TransportState = .unknown,
        queuePosition: Int? = nil,
        queueLength: Int? = nil,
        shuffle: ShuffleMode = .off,
        repeat: RepeatMode = .off
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artURL = artURL
        self.transportState = transportState
        self.queuePosition = queuePosition
        self.queueLength = queueLength
        self.shuffle = shuffle
        self.repeat = `repeat`
    }

    mutating func setTransportState(_ state: TransportState) {
        self.transportState = state
    }
}
