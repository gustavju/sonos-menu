//
//  Topology.swift
//  sonos-menu
//
//  Internal data-transfer representation of Sonos zone group topology.
//  These types are used by the SOAP layer and the mapper; they are not exposed
//  directly to the UI, which uses Household/Group/Room instead.
//

import Foundation

protocol TopologySnapshot: Sendable {
    var groups: [TopologyGroup] { get }
    var memberLocations: [String: String] { get }
    var memberBootSeqs: [String: Int] { get }
    var memberNames: [String: String] { get }
    var rawZoneGroupState: String? { get }
}

struct TopologyGroup: Identifiable, Hashable, Sendable {
    let id: String
    let coordinatorID: String
    let memberIDs: [String]
    let name: String
    let householdID: String?

    nonisolated init(
        id: String,
        coordinatorID: String,
        memberIDs: [String],
        name: String,
        householdID: String?
    ) {
        self.id = id
        self.coordinatorID = coordinatorID
        self.memberIDs = memberIDs
        self.name = name
        self.householdID = householdID
    }
}

struct ZoneGroupTopology: TopologySnapshot, Hashable, Sendable {
    var groups: [TopologyGroup] = []
    var memberLocations: [String: String] = [:]
    var memberBootSeqs: [String: Int] = [:]
    var memberNames: [String: String] = [:]
    var rawZoneGroupState: String?

    nonisolated init(
        groups: [TopologyGroup] = [],
        memberLocations: [String: String] = [:],
        memberBootSeqs: [String: Int] = [:],
        memberNames: [String: String] = [:],
        rawZoneGroupState: String? = nil
    ) {
        self.groups = groups
        self.memberLocations = memberLocations
        self.memberBootSeqs = memberBootSeqs
        self.memberNames = memberNames
        self.rawZoneGroupState = rawZoneGroupState
    }
}
