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
    
    /// Track time progress
    let relTime: TimeInterval
    let duration: TimeInterval

    /// UTC timestamp when this playback snapshot was fetched. Used by the UI to
    /// add a local elapsed offset between 10-second speaker refreshes.
    let fetchedAt: Date?
        
    func effectiveProgress(now: Date) -> Double {
        guard duration > 0 else { return 0.0 }
        let liveRelTime = liveRelTime(now: now)
        return min(liveRelTime / duration, 1.0)
    }

    func liveRelTime(now: Date) -> TimeInterval {
        guard transportState.isPlaying else { return relTime }
        let offset = fetchedAt.map { now.timeIntervalSince($0) } ?? 0
        return min(relTime + offset, duration)
    }

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
        relTime: String = "",
        duration: String = "",
        queuePosition: Int? = nil,
        queueLength: Int? = nil,
        shuffle: ShuffleMode = .off,
        repeat: RepeatMode = .off,
        fetchedAt: Date? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.artURL = artURL
        self.transportState = transportState
        self.relTime = TimeInterval.fromSonosTimeString(relTime)
        self.duration = TimeInterval.fromSonosTimeString(duration)
        self.queuePosition = queuePosition
        self.queueLength = queueLength
        self.shuffle = shuffle
        self.repeat = `repeat`
        self.fetchedAt = fetchedAt
    }

    mutating func setTransportState(_ state: TransportState) {
        self.transportState = state
    }
    
}

extension TimeInterval {
    static func fromSonosTimeString(_ timeString: String) -> TimeInterval {
        let components = timeString.split(separator: ":").compactMap { Double($0) }
        
        switch components.count {
        case 3: // HH:MM:SS
            return (components[0] * 3600) + (components[1] * 60) + components[2]
        case 2: // MM:SS (fallback edge case)
            return (components[0] * 60) + components[1]
        case 1: // Just seconds
            return components[0]
        default:
            return 0.0
        }
    }
}

extension TimeInterval {
    var toTrackDisplayString: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = self >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: self) ?? "0:00"
    }
}
