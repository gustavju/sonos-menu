//
//  Room.swift
//  sonos-menu
//
//  A user-facing Sonos room/player. Volume and mute belong to the room.
//

import Foundation

struct Room: Identifiable, Codable, Hashable, Sendable {
    /// Same identifier as the underlying device.
    let id: String

    /// The room name reported by the device ("Kitchen", "Living Room", etc.).
    let name: String

    /// Identifier of the underlying `Device`.
    let deviceID: String

    /// Identifier of the group this room currently belongs to.
    let groupID: String

    /// Identifier of the household this room belongs to.
    let householdID: String

    var volume: Int
    var isMuted: Bool
    let isCoordinator: Bool

    nonisolated init(
        id: String,
        name: String,
        deviceID: String,
        groupID: String,
        householdID: String,
        volume: Int = 0,
        isMuted: Bool = false,
        isCoordinator: Bool = false
    ) {
        self.id = id
        self.name = name
        self.deviceID = deviceID
        self.groupID = groupID
        self.householdID = householdID
        self.volume = volume
        self.isMuted = isMuted
        self.isCoordinator = isCoordinator
    }
}
