//
//  SonosGroup.swift
//  sonos-menu
//
//  A Sonos group is the primary playback domain entity. It owns playback state
//  and contains one or more rooms, with one room designated as coordinator.
//

import Foundation

struct SonosGroup: Identifiable, Codable, Hashable, Sendable {
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
    /// Aggregate volume level for the whole group.
    var volume: Int

    init(
        id: String,
        name: String,
        coordinatorID: String,
        householdID: String,
        rooms: [Room] = [],
        playback: Playback = Playback(),
        volume: Int = 0
    ) {
        self.id = id
        self.name = name
        self.coordinatorID = coordinatorID
        self.householdID = householdID
        self.rooms = rooms
        self.playback = playback
        self.volume = volume
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
        
        let orderedRooms = rooms
            .filter { !$0.name.isEmpty }
            .sorted { lhs, rhs in
                if lhs.isCoordinator != rhs.isCoordinator {
                    return lhs.isCoordinator
                }
                return lhs.name < rhs.name
            }
        
        switch orderedRooms.count {
            case 0: return "Group"
            case 1: return orderedRooms.first!.name
            case 2: return "\(orderedRooms.first!.name) + \(orderedRooms[1].name)"
            default: return "\(orderedRooms.first!.name) + \(orderedRooms.count - 1) more"
        }
    }
}
