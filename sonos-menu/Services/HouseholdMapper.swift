//
//  HouseholdMapper.swift
//  sonos-menu
//
//  Pure transformation logic that builds the domain object graph (Household/Group/Room)
//  from raw discovery devices, topology data, playback state, and optional volume responses.
//

import Foundation

enum HouseholdMapError: Error {
    case missingDevice(id: String)
    case missingHouseholdID
}

enum HouseholdMapper {
    /// Build the domain snapshot from the latest gathered data.
    /// - Parameters:
    ///   - topology: raw group topology parsed from a coordinator.
    ///   - devices: known devices from discovery. Missing ones are synthesized from topology locations.
    ///   - playbackResponses: fetched playback keyed by group ID.
    ///   - volumes: room volume keyed by room/device ID.
    ///   - mutes: room mute keyed by room/device ID.
    nonisolated static func map(
        topology: ZoneGroupTopology,
        devices: [Device],
        playbackResponses: [String: Playback] = [:],
        volumes: [String: Int] = [:],
        mutes: [String: Bool] = [:],
        groupVolumes: [String: Int] = [:]
    ) -> [Household] {
        var deviceByID: [String: Device] = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })

        // Synthesize devices from topology member locations if discovery hasn't found them yet.
        for (memberID, host) in topology.memberLocations {
            if let _ = deviceByID[memberID] { continue }
            deviceByID[memberID] = .topologyHost(id: memberID, host: host)
        }

        // Group raw topology groups by household ID. When topology is missing the household ID
        // (e.g. a fetched topology response doesn't expose it), derive from devices if possible.
        var householdGroups: [String: [TopologyGroup]] = [:]
        for group in topology.groups {
            let householdID = group.householdID
                ?? householdID(for: group, devices: deviceByID)
                ?? "unknown"
            householdGroups[householdID, default: []].append(group)
        }

        return householdGroups.map { (householdID, groups) -> Household in
            let mappedGroups = groups.map { group -> SonosGroup in
                let rooms: [Room] = group.memberIDs.compactMap { memberID in
                    guard let device = deviceByID[memberID] else { return nil }
                    let roomName = topology.memberNames[memberID]
                        ?? Self.parseRoomName(from: device.name)
                        ?? device.name

                    return Room(
                        id: memberID,
                        name: roomName,
                        deviceID: device.id,
                        groupID: group.id,
                        householdID: householdID,
                        volume: volumes[memberID] ?? 0,
                        isMuted: mutes[memberID] ?? false,
                        isCoordinator: memberID == group.coordinatorID
                    )
                }
                .sorted { $0.name < $1.name }

                return SonosGroup(
                    id: group.id,
                    name: group.name,
                    coordinatorID: group.coordinatorID,
                    householdID: householdID,
                    rooms: rooms,
                    playback: playbackResponses[group.id] ?? Playback(),
                    volume: groupVolumes[group.id] ?? 0
                )
            }
            .sorted { $0.name < $1.name }

            let allRooms = mappedGroups.flatMap { $0.rooms }

            return Household(
                id: householdID,
                groups: mappedGroups,
                rooms: allRooms
            )
        }
        .sorted { $0.id < $1.id }
    }

    nonisolated private static func householdID(
        for group: TopologyGroup,
        devices: [String: Device]
    ) -> String? {
        for memberID in group.memberIDs {
            if let householdID = devices[memberID]?.householdID, !householdID.isEmpty {
                return householdID
            }
        }
        return nil
    }

    /// Best-effort extraction of a human room name from the Sonos `friendlyName`.
    /// Returns `nil` when the string looks technical so callers can fall back.
    nonisolated private static func parseRoomName(from friendlyName: String) -> String? {
        let withoutIP = friendlyName.replacingOccurrences(
            of: #"^\d+\.\d+\.\d+\.\d+\s*-\s*"#,
            with: "",
            options: .regularExpression
        )
        let withoutSonos = withoutIP.replacingOccurrences(
            of: #"^Sonos\\s+"#,
            with: "",
            options: .regularExpression
        )
        let trimmed = withoutSonos.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        // If the remaining text is just a model number like "Play:5", "One SL", etc.,
        // prefer falling back to the raw name rather than showing a product name as a room.
        let startsWithModel = ["Play:", "One", "Five", "Move", "Roam", "Arc", "Beam", "Ray", "Era"]
            .contains { trimmed.hasPrefix($0) }
        return startsWithModel ? nil : trimmed
    }
}
