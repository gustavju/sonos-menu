//
//  SonosRepository.swift
//  sonos-menu
//
//  Owns discovery, periodic refresh, command targeting, and domain-model snapshot.
//  View models observe the published snapshot and drive the UI from Household/Group/Room.
//

import Foundation
import Combine

struct HouseholdSnapshot: Sendable {
    var households: [Household] = []
    /// True while SSDP discovery is actively scanning.
    var isScanning: Bool = false
    var lastError: String?
    var lastRefresh: Date?
}

/// Called on the MainActor whenever the repository finishes a refresh that changes
/// the available groups, so the view model can adjust its selection.
@MainActor
protocol SonosRepositoryDelegate: AnyObject {
    func sonosRepository(_ repository: SonosRepository, didUpdateGroups groups: [SonosGroup])
}

/// Internal actor that holds the mutable caches used during refresh.
/// Keeping these off the main actor lets `refresh()` perform network work
/// without holding the UI thread.
private actor RefreshStore {
    /// Maps a stable topology key to the latest parsed topology.
    private var topologyStore: [String: ZoneGroupTopology] = [:]
    /// Maps device ID to the latest known or synthesized device.
    private var deviceStore: [String: Device] = [:]

    func merge(_ devices: [Device]) {
        for device in devices {
            deviceStore[device.id] = device
        }
    }

    func allDevices() -> [Device] { Array(deviceStore.values) }

    func device(for id: String) -> Device? { deviceStore[id] }

    func synthesize(from topology: ZoneGroupTopology) {
        for (memberID, host) in topology.memberLocations where deviceStore[memberID] == nil {
            deviceStore[memberID] = .topologyHost(id: memberID, host: host)
        }
    }

    func store(_ topology: ZoneGroupTopology) {
        if !topology.groups.isEmpty {
            let key = topology.groups.map(\.id).sorted().joined(separator: "-")
            topologyStore[key] = topology
        }
    }

    func topology(containingGroupID groupID: String) -> ZoneGroupTopology? {
        topologyStore.first { $0.value.groups.contains(where: { $0.id == groupID }) }?.value
    }

    /// Coordinator ID first, then any member ID with a known host.
    func bestDevice(for group: TopologyGroup, locations: [String: String]) -> Device? {
        if let coordinatorHost = locations[group.coordinatorID] {
            return deviceStore[group.coordinatorID]
                ?? .topologyHost(id: group.coordinatorID, host: coordinatorHost)
        }

        for memberID in group.memberIDs {
            guard let host = locations[memberID] else { continue }
            return deviceStore[memberID] ?? .topologyHost(id: memberID, host: host)
        }

        return deviceStore.values
            .filter { group.memberIDs.contains($0.id) }
            .sorted { ($0.id == group.coordinatorID) ? true : ($1.id != group.coordinatorID) }
            .first
    }

    func coordinatorDevice(forGroupID groupID: String) -> Device? {
        guard let topology = topology(containingGroupID: groupID) else { return nil }
        guard let topologyGroup = topology.groups.first(where: { $0.id == groupID }) else { return nil }

        let coordinatorID = topologyGroup.coordinatorID
        if let cached = deviceStore[coordinatorID] { return cached }
        if let host = topology.memberLocations[coordinatorID] {
            return .topologyHost(id: coordinatorID, host: host)
        }
        return bestDevice(for: topologyGroup, locations: topology.memberLocations)
    }

    func commandDevice(forGroupID groupID: String) -> Device? {
        guard let topology = topology(containingGroupID: groupID) else { return nil }
        guard let topologyGroup = topology.groups.first(where: { $0.id == groupID }) else { return nil }
        return bestDevice(for: topologyGroup, locations: topology.memberLocations)
    }
}

@MainActor
@Observable
final class SonosRepository {
    var snapshot = HouseholdSnapshot()
    weak var delegate: SonosRepositoryDelegate?

    /// External infrastructure. Override for tests by passing concrete instances.
    private let discovery: SSDPDiscoveryService
    private nonisolated let controller: any SonosControlling
    private nonisolated let store = RefreshStore()

    private var refreshTask: Task<Void, Never>?
    private var discoveryObservationTask: Task<Void, Never>?

    private var isRefreshing = false
    private var hasReceivedDiscoveryResult = false
    /// Set by `discoveryFinished()` when a result arrives while a refresh is
    /// already in progress, so the repository immediately retries afterwards
    /// with the newly discovered devices.
    private var pendingDiscoveryRefresh = false
    private var hasCompletedInitialDiscovery = false
    /// Prevents an older status request from overwriting the result of a newer
    /// next/previous command when the user presses transport controls quickly.
    private var trackChangeRequestID = 0
    
    init(
        discovery: SSDPDiscoveryService,
        controller: any SonosControlling
    ) {
        self.discovery = discovery
        self.controller = controller

        discoveryObservationTask = Task { [weak self] in
            // `discovery.$devices` publishes on the main actor because `devices`
            // is `@Published` on a `@MainActor` service. We simply react by
            // scheduling a background refresh; the heavy work never runs here.
            for await _ in discovery.$devices.values {
                guard let self else { return }
                await self.discoveryFinished()
            }
        }
    }

    // MARK: - Lifecycle

    var menuIsOpen: Bool = false

    func startRefreshing() {
        guard refreshTask == nil else { return }
        menuIsOpen = true

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

    // MARK: - Discovery-to-refresh

    private func discoveryFinished() async {
        print("SSDP discovery finished, discovered \(discovery.discoveredDevices.count) devices")
        snapshot.isScanning = discovery.isScanning

        guard !hasCompletedInitialDiscovery else { return }

        hasReceivedDiscoveryResult = true

        if isRefreshing {
            pendingDiscoveryRefresh = true
        } else {
            await refresh()
        }
    }

    // MARK: - Sync

    /// Schedules a complete refresh. All network work is performed off the main
    /// actor; only the final `snapshot` update publishes back here.
    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true

        snapshot.isScanning = discovery.isScanning
        let discovered = discovery.discoveredDevices

        // Detach to the cooperative pool/background so the main actor isn't held
        // during topology, playback, and volume fetches.
        Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            let (newHouseholds, error) = await self.performBackgroundRefresh(discovered: discovered)

            await MainActor.run { [weak self] in
                guard let self else { return }

                if let error {
                    self.snapshot.lastError = error
                } else {
                    self.snapshot.lastError = nil
                }

                if !newHouseholds.isEmpty {
                    let groupsChanged = !newHouseholds.elementsEqual(
                        self.snapshot.households,
                        by: { $0.groups.map(\.id) == $1.groups.map(\.id) }
                    )
                    self.snapshot.households = newHouseholds

                    if groupsChanged {
                        let allGroups = newHouseholds.flatMap(\.groups)
                        self.delegate?.sonosRepository(self, didUpdateGroups: allGroups)
                    }
                }

                if self.hasReceivedDiscoveryResult {
                    self.hasCompletedInitialDiscovery = true
                }
                self.snapshot.lastRefresh = Date()
                self.isRefreshing = false
                self.snapshot.isScanning = self.discovery.isScanning

                if self.pendingDiscoveryRefresh {
                    self.pendingDiscoveryRefresh = false
                    Task { await self.refresh() }
                }
            }
        }
    }

    nonisolated private func performBackgroundRefresh(
        discovered: [Device]
    ) async -> (households: [Household], error: String?) {
        await store.merge(discovered)

        let topology: ZoneGroupTopology
        do {
            topology = try await fetchLatestTopology(discovered: discovered)
        } catch {
            return ([], error.localizedDescription)
        }

        await store.store(topology)
        await store.synthesize(from: topology)

        async let playbackResponses = fetchPlayback(for: topology)
        async let volumes = fetchVolumes(for: topology)
        async let groupVolumes = fetchGroupVolumes(for: topology)

        let households = HouseholdMapper.map(
            topology: topology,
            devices: await store.allDevices(),
            playbackResponses: await playbackResponses,
            volumes: await volumes,
            mutes: [:],
            groupVolumes: await groupVolumes
        )

        return (households, nil)
    }

    nonisolated private func fetchLatestTopology(
        discovered: [Device]
    ) async throws -> ZoneGroupTopology {
        // Prefer cached topologies first.
        for topology in await storeAllTopologies() {
            for group in topology.groups {
                if let device = await store.bestDevice(for: group, locations: topology.memberLocations) {
                    if let fresh = try? await controller.fetchTopology(from: device) {
                        return fresh
                    }
                }
            }
        }

        // Then any known device.
        for device in await store.allDevices() {
            if let fresh = try? await controller.fetchTopology(from: device) {
                return fresh
            }
        }

        // Fallback to a freshly discovered device.
        for device in discovered {
            if let fresh = try? await controller.fetchTopology(from: device) {
                await store.merge([device])
                return fresh
            }
        }

        throw SonosError.badResponse
    }

    nonisolated private func storeAllTopologies() async -> [ZoneGroupTopology] {
        await store.allTopologies()
    }
    
    func fetchFavorites(for group: SonosGroup) async -> [DIDLItem] {
        var didlItems: [DIDLItem] = []
        guard let device = await self.store.commandDevice(forGroupID: group.id) else { return didlItems }
        do {
            didlItems = try await self.controller.browseContentDirectory(
                on: device,
                objectID: "FV:2",
                browseFlag: "BrowseDirectChildren",
                startingIndex: 0,
                requestedCount: 100
            )
        } catch {
            await MainActor.run { [weak self] in
                self?.snapshot.lastError = error.localizedDescription
            }
        }
        return didlItems
    }

    nonisolated private func fetchPlayback(for topology: ZoneGroupTopology) async -> [String: Playback] {
        await withTaskGroup(of: (String, Playback)?.self) { group in
            for topologyGroup in topology.groups {
                group.addTask { [weak self] in
                    guard let self,
                          let device = await self.store.bestDevice(
                              for: topologyGroup,
                              locations: topology.memberLocations
                          ) else { return nil }
                    do {
                        let playback = try await self.controller.fetchNowPlaying(on: device)
                        return (topologyGroup.id, playback)
                    } catch {
                        return nil
                    }
                }
            }

            var results: [String: Playback] = [:]
            for await result in group {
                if let (groupID, playback) = result {
                    results[groupID] = playback
                }
            }
            return results
        }
    }

    nonisolated private func fetchVolumes(for topology: ZoneGroupTopology) async -> [String: Int] {
        await withTaskGroup(of: (String, Int)?.self) { group in
            let memberIDs = Set(topology.groups.flatMap(\.memberIDs))
            for memberID in memberIDs {
                guard let device = await self.store.device(for: memberID) else { continue }
                group.addTask { [weak self] in
                    guard let self else { return nil }
                    guard let volume = try? await self.controller.getVolume(on: device) else { return nil }
                    return (memberID, volume)
                }
            }

            var results: [String: Int] = [:]
            for await result in group {
                if let (memberID, volume) = result { results[memberID] = volume }
            }
            return results
        }
    }

    nonisolated private func fetchGroupVolumes(for topology: ZoneGroupTopology) async -> [String: Int] {
        await withTaskGroup(of: (String, Int)?.self) { group in
            for topologyGroup in topology.groups {
                group.addTask { [weak self] in
                    guard let self,
                          let device = await self.store.bestDevice(
                              for: topologyGroup,
                              locations: topology.memberLocations
                          ) else { return nil }
                    do {
                        let volume = try await self.controller.getGroupVolume(on: device, groupID: topologyGroup.id)
                        return (topologyGroup.id, volume)
                    } catch {
                        return nil
                    }
                }
            }

            var results: [String: Int] = [:]
            for await result in group {
                if let (groupID, volume) = result { results[groupID] = volume }
            }
            return results
        }
    }

    // MARK: - User actions

    func togglePlayPause(for group: SonosGroup) {
        let isPlaying = group.playback.transportState.isPlaying
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self,
                  let device = await self.store.commandDevice(forGroupID: group.id) else { return }
            do {
                if isPlaying {
                    try await self.controller.pause(on: device)
                } else {
                    try await self.controller.play(on: device)
                }
                await self.refresh()
            } catch {
                await MainActor.run { [weak self] in
                    self?.snapshot.lastError = error.localizedDescription
                }
            }
        }
    }

    func playFavorite(_ favorite: DIDLItem, on group: SonosGroup) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self,
                  let device = await self.store.commandDevice(forGroupID: group.id) else { return }
            do {
                try await self.controller.playFavorite(favorite, on: device)
                await self.refresh()
            } catch {
                await MainActor.run { [weak self] in
                    self?.snapshot.lastError = error.localizedDescription
                }
            }
        }
    }

    func setPlayMode(shuffle: ShuffleMode, repeat repeatMode: RepeatMode, for group: SonosGroup) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self,
                  let device = await self.store.commandDevice(forGroupID: group.id) else { return }
            do {
                try await self.controller.setPlayMode(shuffle: shuffle, repeat: repeatMode, on: device)
                await self.refresh()
            } catch {
                await MainActor.run { [weak self] in
                    self?.snapshot.lastError = error.localizedDescription
                }
            }
        }
    }

    func nextTrack(for group: SonosGroup) {
        trackChangeRequestID += 1
        let requestID = trackChangeRequestID

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self,
                  let device = await self.store.commandDevice(forGroupID: group.id) else { return }
            do {
                try await self.controller.nextTrack(on: device)
            } catch {
                await MainActor.run { [weak self] in
                    self?.snapshot.lastError = error.localizedDescription
                }
                return
            }

            await self.fetchPlaybackAfterTrackChange(
                on: device,
                groupID: group.id,
                requestID: requestID
            )
        }
    }

    func previousTrack(for group: SonosGroup) {
        trackChangeRequestID += 1
        let requestID = trackChangeRequestID

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self,
                  let device = await self.store.commandDevice(forGroupID: group.id) else { return }
            do {
                try await self.controller.previousTrack(on: device)
            } catch {
                await MainActor.run { [weak self] in
                    self?.snapshot.lastError = error.localizedDescription
                }
                return
            }

            await self.fetchPlaybackAfterTrackChange(
                on: device,
                groupID: group.id,
                requestID: requestID
            )
        }
    }

    private func fetchPlaybackAfterTrackChange(
        on device: Device,
        groupID: String,
        requestID: Int
    ) async {
        // Sonos accepts the transport command before its metadata endpoint has
        // necessarily advanced. A short delay avoids rendering the old track
        // while still updating far sooner than the ten-second polling cycle.
        try? await Task.sleep(for: .milliseconds(300))

        guard let playback = try? await controller.fetchNowPlaying(on: device) else { return }
        applyPlayback(playback, toGroupID: groupID, requestID: requestID)
    }

    private func applyPlayback(_ playback: Playback, toGroupID groupID: String, requestID: Int) {
        guard requestID == trackChangeRequestID,
              let householdIndex = snapshot.households.firstIndex(where: { household in
                  household.groups.contains(where: { $0.id == groupID })
              }),
              let groupIndex = snapshot.households[householdIndex].groups.firstIndex(where: { $0.id == groupID })
        else { return }

        snapshot.households[householdIndex].groups[groupIndex].playback = playback
        snapshot.lastRefresh = Date()
    }

    /// room.volume is updated optimistically by the caller before this method runs.
    func setVolume(_ volume: Int, for room: Room) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self,
                  let device = await self.store.device(for: room.deviceID) else { return }
            do {
                try await self.controller.setVolume(volume, on: device)
                await self.refresh()
            } catch {
                await MainActor.run { [weak self] in
                    self?.snapshot.lastError = error.localizedDescription
                }
            }
        }
    }

    func toggleMute(_ muted: Bool, for room: Room) {
        // Sonos doesn't expose a simple SetMute on a RenderingControl instance for the master
        // channel in the same straightforward way as SetVolume across all devices. We model it
        // as volume 0 / restore for now until a dedicated SetMute implementation is added.
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self,
                  let device = await self.store.device(for: room.deviceID) else { return }
            do {
                try await self.controller.setVolume(muted ? 0 : max(room.volume, 10), on: device)
                await self.refresh()
            } catch {
                await MainActor.run { [weak self] in
                    self?.snapshot.lastError = error.localizedDescription
                }
            }
        }
    }

    func addRoom(_ room: Room, to group: SonosGroup) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self,
                  let memberDevice = await self.store.device(for: room.deviceID),
                  let coordinatorDevice = await self.store.coordinatorDevice(forGroupID: group.id) else { return }
            do {
                try await self.controller.joinGroup(member: memberDevice, coordinatorID: coordinatorDevice.id)
                try? await Task.sleep(for: .milliseconds(750))
                await self.refresh()
            } catch {
                await MainActor.run { [weak self] in
                    self?.snapshot.lastError = error.localizedDescription
                }
            }
        }
    }

    func removeRoom(_ room: Room, from group: SonosGroup) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self,
                  let memberDevice = await self.store.device(for: room.deviceID) else { return }
            do {
                try await self.controller.leaveGroup(member: memberDevice)
                try? await Task.sleep(for: .milliseconds(750))
                await self.refresh()
            } catch {
                await MainActor.run { [weak self] in
                    self?.snapshot.lastError = error.localizedDescription
                }
            }
        }
    }

    func setGroupVolume(_ volume: Int, for group: SonosGroup) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self,
                  let device = await self.store.commandDevice(forGroupID: group.id) else { return }
            do {
                try await self.controller.setGroupVolume(volume, on: device, groupID: group.id)
                await self.refresh()
            } catch {
                await MainActor.run { [weak self] in
                    self?.snapshot.lastError = error.localizedDescription
                }
            }
        }
    }
}

private extension RefreshStore {
    func allTopologies() -> [ZoneGroupTopology] {
        Array(topologyStore.values)
    }
}
