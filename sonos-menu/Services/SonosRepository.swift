//
//  SonosRepository.swift
//  sonos-menu
//
//  Owns discovery, periodic refresh, command targeting, and domain-model snapshot.
//  View models observe the published snapshot and drive the UI from Household/Group/Room.
//

import Foundation

struct HouseholdSnapshot: Sendable {
    var households: [Household] = []
    var isScanning: Bool = false
    var lastError: String?
    var lastRefresh: Date?
}

@MainActor
@Observable
final class SonosRepository {
    var snapshot = HouseholdSnapshot()

    /// External infrastructure. Override for tests by passing concrete instances.
    private let discovery: SSDPDiscoveryService
    private let controller: any SonosControlling

    private var refreshTask: Task<Void, Never>?

    /// In-memory cache of latest topology details needed for SOAP command targeting.
    /// Maps group ID to the latest topology and discovered-or-synthesized devices.
    private var topologyStore: [String: ZoneGroupTopology] = [:]
    private var deviceStore: [String: Device] = [:]

    var devices: [Device] { Array(deviceStore.values) }

    init(
        discovery: SSDPDiscoveryService,
        controller: any SonosControlling
    ) {
        self.discovery = discovery
        self.controller = controller
    }

    // MARK: - Lifecycle

    var menuIsOpen: Bool = false

    func startRefreshing() {
        guard refreshTask == nil else { return }
        menuIsOpen = true

        // Only auto-scan on open when we have no cached devices. Otherwise the user
        // controls discovery explicitly via scanForDevices().
        if deviceStore.isEmpty {
            discovery.refresh()
        }

        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refresh()
                try? await Task.sleep(for: .seconds(10))
            }
        }
    }

    func stopRefreshing() {
        refreshTask?.cancel()
        refreshTask = nil
        menuIsOpen = false
    }

    func refreshNow() {
        Task { await refresh() }
    }

    /// Manually trigger SSDP discovery. Use this for a user-initiated scan.
    func scanForDevices() {
        discovery.refresh()
    }

    // MARK: - Sync

    @MainActor
    private func refresh() async {
        snapshot.isScanning = discovery.isScanning
        if let discoveryError = discovery.lastError, snapshot.lastError == nil {
            snapshot.lastError = discoveryError
        }

        let discovered = discovery.discoveredDevices
        if !discovered.isEmpty {
            mergeDiscoveredDevices(discovered)
        }

        // Try to fetch topology from any command target if we already know groups, or from any device.
        let topology: ZoneGroupTopology
        do {
            topology = try await fetchLatestTopology()
        } catch {
            snapshot.lastError = error.localizedDescription
            return
        }

        if !topology.groups.isEmpty {
            topologyStore[topology.groups.map { $0.id }.sorted().joined(separator: "-")] = topology
        }

        // Ensure every topology member has a Device entry so setVolume/getVolume can target it.
        synthesizeDevices(from: topology)

        // Default playback fetch only for now; later we may fetch per-group concurrently.
        let playbackResponses = await fetchPlayback(for: topology)

        var volumes: [String: Int] = [:]
        let mutes: [String: Bool] = [:]
        for group in topology.groups {
            for memberID in group.memberIDs {
                guard let device = deviceStore[memberID] else { continue }
                if let volume = try? await controller.getVolume(on: device) {
                    volumes[memberID] = volume
                }
            }
        }

        let newHouseholds = HouseholdMapper.map(
            topology: topology,
            devices: Array(deviceStore.values),
            playbackResponses: playbackResponses,
            volumes: volumes,
            mutes: mutes
        )

        snapshot.households = newHouseholds
        snapshot.lastRefresh = Date()
    }

    @MainActor
    private func fetchLatestTopology() async throws -> ZoneGroupTopology {
        // Prefer a known coordinator from a previously selected group or any discovered device.
        for (_, topology) in topologyStore {
            for group in topology.groups {
                if let device = await bestDevice(for: group, devices: deviceStore, locations: topology.memberLocations) {
                    if let fresh = try? await controller.fetchTopology(from: device) {
                        return fresh
                    }
                }
            }
        }

        for device in deviceStore.values {
            if let fresh = try? await controller.fetchTopology(from: device) {
                return fresh
            }
        }

        // Fallback to any newly discovered device, even before it has been merged into stores.
        for device in discovery.discoveredDevices {
            if let fresh = try? await controller.fetchTopology(from: device) {
                mergeDiscoveredDevices([device])
                return fresh
            }
        }

        throw SonosError.badResponse
    }

    private func fetchPlayback(for topology: ZoneGroupTopology) async -> [String: Playback] {
        var results: [String: Playback] = [:]
        await withTaskGroup(of: (String, Playback)?.self) { group in
            for topologyGroup in topology.groups {
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    let device = await self.bestDevice(
                        for: topologyGroup,
                        devices: self.deviceStore,
                        locations: topology.memberLocations
                    )
                    guard let device else { return nil }
                    do {
                        let playback = try await self.controller.fetchNowPlaying(on: device)
                        return (topologyGroup.id, playback)
                    } catch {
                        return nil
                    }
                }
            }

            for await result in group {
                if let (groupID, playback) = result {
                    results[groupID] = playback
                }
            }
        }
        return results
    }

    @MainActor
    private func mergeDiscoveredDevices(_ discovered: [Device]) {
        for device in discovered {
            deviceStore[device.id] = device
        }
    }

    @MainActor
    private func synthesizeDevices(from topology: ZoneGroupTopology) {
        for (memberID, host) in topology.memberLocations {
            guard deviceStore[memberID] == nil else { continue }
            deviceStore[memberID] = Device.topologyHost(id: memberID, host: host)
        }
    }

    // MARK: - Command targeting

    /// The coordinator is the canonical target, but devices sometimes report a coordinator
    /// that isn't reachable via HTTP. Fall back to any reachable group member.
    private func bestDevice(
        for topologyGroup: TopologyGroup,
        devices: [String: Device],
        locations: [String: String]
    ) async -> Device? {
        if let coordinatorHost = locations[topologyGroup.coordinatorID] {
            let device = devices[topologyGroup.coordinatorID]
                ?? Device.topologyHost(id: topologyGroup.coordinatorID, host: coordinatorHost)
            if await isReachable(device) {
                return device
            }
        }

        for memberID in topologyGroup.memberIDs {
            guard let host = locations[memberID] else { continue }
            let device = devices[memberID] ?? Device.topologyHost(id: memberID, host: host)
            if await isReachable(device) {
                return device
            }
        }

        // Last resort: any discovered device in the same group, sorted coordinator first.
        let candidates = devices.values
            .filter { topologyGroup.memberIDs.contains($0.id) }
            .sorted { ($0.id == topologyGroup.coordinatorID) ? true : ($1.id != topologyGroup.coordinatorID) }
        for device in candidates {
            if await isReachable(device) { return device }
        }

        return nil
    }

    private func isReachable(_ device: Device) async -> Bool {
        guard let url = URL(string: "http://\(device.host):1400/xml/device_description.xml") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 1
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            if !ok { print("isReachable: \(device.host) not OK") }
            return ok
        } catch {
            return false
        }
    }

    // MARK: - User actions

    func togglePlayPause(for group: Group) {
        Task {
            guard let device = await commandDevice(for: group) else { return }
            let isPlaying = group.playback.transportState.isPlaying
            do {
                if isPlaying {
                    try await controller.pause(on: device)
                } else {
                    try await controller.play(on: device)
                }
                await refresh()
            } catch {
                snapshot.lastError = error.localizedDescription
            }
        }
    }

    func nextTrack(for group: Group) {
        Task {
            guard let device = await commandDevice(for: group) else { return }
            do {
                try await controller.nextTrack(on: device)
                await refresh()
            } catch {
                snapshot.lastError = error.localizedDescription
            }
        }
    }

    func previousTrack(for group: Group) {
        Task {
            guard let device = await commandDevice(for: group) else { return }
            do {
                try await controller.previousTrack(on: device)
                await refresh()
            } catch {
                snapshot.lastError = error.localizedDescription
            }
        }
    }

    /// room.volume is updated optimistically by the caller before this method runs.
    func setVolume(_ volume: Int, for room: Room) {
        Task {
            guard let device = deviceStore[room.deviceID] else { return }
            do {
                try await controller.setVolume(volume, on: device)
                await refresh()
            } catch {
                snapshot.lastError = error.localizedDescription
            }
        }
    }

    func toggleMute(_ muted: Bool, for room: Room) {
        // Sonos doesn't expose a simple SetMute on a RenderingControl instance for the master
        // channel in the same straightforward way as SetVolume across all devices. We model it
        // as volume 0 / restore for now until a dedicated SetMute implementation is added.
        Task {
            guard let device = deviceStore[room.deviceID] else { return }
            do {
                try await controller.setVolume(muted ? 0 : max(room.volume, 10), on: device)
                await refresh()
            } catch {
                snapshot.lastError = error.localizedDescription
            }
        }
    }

    func addRoom(_ room: Room, to group: Group) {
        Task {
            guard let memberDevice = deviceStore[room.deviceID],
                  let coordinatorDevice = await coordinatorDevice(for: group) else { return }
            do {
                try await controller.joinGroup(member: memberDevice, coordinatorID: coordinatorDevice.id)
                try? await Task.sleep(for: .milliseconds(750))
                await refresh()
            } catch {
                snapshot.lastError = error.localizedDescription
            }
        }
    }

    func removeRoom(_ room: Room, from group: Group) {
        Task {
            guard let memberDevice = deviceStore[room.deviceID] else { return }
            do {
                try await controller.leaveGroup(member: memberDevice)
                try? await Task.sleep(for: .milliseconds(750))
                await refresh()
            } catch {
                snapshot.lastError = error.localizedDescription
            }
        }
    }

    func setGroupVolume(_ volume: Int, for group: Group) {
        Task {
            guard let device = await commandDevice(for: group) else { return }
            do {
                try await controller.setGroupVolume(volume, on: device, groupID: group.id)
                await refresh()
            } catch {
                snapshot.lastError = error.localizedDescription
            }
        }
    }

    /// Returns the coordinator device for a group. Used when joining a room,
    /// where the joining speaker's AVTransport URI is set to `x-rincon:<coordinatorID>`.
    private func coordinatorDevice(for group: Group) async -> Device? {
        guard let topology = topologyFor(group: group) else { return nil }
        guard let topologyGroup = topology.groups.first(where: { $0.id == group.id }) else { return nil }

        let coordinatorID = topologyGroup.coordinatorID
        if let cached = deviceStore[coordinatorID], await isReachable(cached) {
            return cached
        }

        if let host = topology.memberLocations[coordinatorID] {
            let synthesized = Device.topologyHost(id: coordinatorID, host: host)
            if await isReachable(synthesized) {
                return synthesized
            }
        }

        return await bestDevice(
            for: topologyGroup,
            devices: deviceStore,
            locations: topology.memberLocations
        )
    }

    private func commandDevice(for group: Group) async -> Device? {
        guard let topology = topologyFor(group: group) else { return nil }
        guard let topologyGroup = topology.groups.first(where: { $0.id == group.id }) else { return nil }
        return await bestDevice(
            for: topologyGroup,
            devices: deviceStore,
            locations: topology.memberLocations
        )
    }

    private func topologyFor(group: Group) -> ZoneGroupTopology? {
        topologyStore.first { $0.value.groups.contains(where: { $0.id == group.id }) }?.value
    }
}
