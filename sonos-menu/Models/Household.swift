//
//  Household.swift
//  sonos-menu
//
//  A Sonos household is the root container for all groups and rooms. The model
//  supports multiple households; the UI can render a selector when more than one
//  is discovered.
//

import Foundation

struct Household: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var groups: [Group]

    /// All rooms known in this household, regardless of current group membership.
    /// Useful for future grouping/ungrouping and move operations.
    var rooms: [Room]

    init(
        id: String,
        groups: [Group] = [],
        rooms: [Room] = []
    ) {
        self.id = id
        self.groups = groups
        self.rooms = rooms
    }
}
