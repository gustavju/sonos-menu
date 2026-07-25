//
//  Group.swift
//  sonos-menu
//
//  A Sonos group is the primary playback domain entity. It owns playback state
//  and contains one or more rooms, with one room designated as coordinator.
//

import Foundation

struct Group: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    /// Identifier of the coordinator room.
    let coordinatorID: String
    /// Identifier of the household this group belongs to.
    let householdID: String

    /// Rooms that are members of this group.
    var rooms: [Room]
    /// Playback state is owned by the group and driven by its coordinator.
    var playback: Playback

    init(
        id: String,
        name: String,
        coordinatorID: String,
        householdID: String,
        rooms: [Room] = [],
        playback: Playback = Playback()
    ) {
        self.id = id
        self.name = name
        self.coordinatorID = coordinatorID
        self.householdID = householdID
        self.rooms = rooms
        self.playback = playback
    }

    var coordinator: Room? {
        rooms.first { $0.id == coordinatorID }
    }

    var memberCount: Int {
        rooms.count
    }

    var displayName: String {
        let isTechnical = name.lowercased().hasPrefix("uuid:") || name.lowercased().hasPrefix("rincon_")
        if !name.isEmpty, !isTechnical {
            return name
        }
        let names = rooms.map(\.name).filter { !$0.isEmpty }.sorted()
        switch names.count {
        case 0: return "Group"
        case 1: return names[0]
        case 2: return "\(names[0]) + \(names[1])"
        default: return "\(names[0]) + \(names.count - 1) more"
        }
    }
}
