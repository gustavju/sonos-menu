//
//  SonosMenuViewModel.swift
//  sonos-menu
//
//  UI-specific state and action forwarding. Domain refresh and command targeting now live
//  in SonosRepository.
//

import SwiftUI

@MainActor
@Observable
final class SonosMenuViewModel: SonosRepositoryDelegate {
    private let repository: SonosRepository

    var households: [Household] { repository.snapshot.households }
    var isScanning: Bool { repository.snapshot.isScanning }
    var lastError: String? { repository.snapshot.lastError }

    var selectedHouseholdID: String?
    var selectedGroupID: String?

    var selectedHousehold: Household? {
        guard let selectedHouseholdID else {
            return households.first
        }
        return households.first { $0.id == selectedHouseholdID }
    }

    var selectedGroup: Group? {
        guard let household = selectedHousehold else { return nil }
        guard let selectedGroupID else {
            return household.groups.first
        }
        return household.groups.first { $0.id == selectedGroupID }
    }

    var selectedGroupRooms: [Room] {
        selectedGroup?.rooms.sorted { $0.name < $1.name } ?? []
    }

    var allHouseholdRooms: [Room] {
        selectedHousehold?.rooms.sorted { $0.name < $1.name } ?? []
    }

    var selectedGroupPlayback: Playback {
        selectedGroup?.playback ?? Playback()
    }

    func isRoomInSelectedGroup(_ room: Room) -> Bool {
        selectedGroup?.rooms.contains(where: { $0.id == room.id }) ?? false
    }

    init(repository: SonosRepository? = nil) {
        self.repository = repository ?? SonosRepository(
            discovery: SSDPDiscoveryService(),
            controller: SonosController()
        )
        self.repository.delegate = self
    }

    // MARK: - Lifecycle

    func onMenuAppear() {
        repository.startRefreshing()
    }

    func onMenuDisappear() {
        repository.stopRefreshing()
    }

    func refresh() {
        repository.refreshNow()
    }

    func scanForDevices() {
        repository.scanForDevices()
    }

    func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    func selectHousehold(_ household: Household?) {
        selectedHouseholdID = household?.id
        selectedGroupID = nil
    }

    func selectGroup(_ group: Group?) {
        selectedGroupID = group?.id
    }

    // MARK: - SonosRepositoryDelegate

    func sonosRepository(_ repository: SonosRepository, didUpdateGroups groups: [Group]) {
        guard selectedGroupID == nil else { return }

        let playingGroups = groups.filter { $0.playback.transportState.isPlaying }
        if playingGroups.count == 1, let onlyPlaying = playingGroups.first {
            selectedHouseholdID = onlyPlaying.householdID
            selectedGroupID = onlyPlaying.id
        }
    }

    // MARK: - Actions

    func togglePlayPause() {
        guard let group = selectedGroup else { return }
        repository.togglePlayPause(for: group)
    }

    func nextTrack() {
        guard let group = selectedGroup else { return }
        repository.nextTrack(for: group)
    }

    func previousTrack() {
        guard let group = selectedGroup else { return }
        repository.previousTrack(for: group)
    }

    func setVolume(_ volume: Double, for room: Room) {
        var updatedRoom = room
        updatedRoom.volume = Int(volume)
        repository.setVolume(updatedRoom.volume, for: updatedRoom)
    }

    func toggleMute(for room: Room) {
        repository.toggleMute(!room.isMuted, for: room)
    }

    func toggleRoomMembership(_ room: Room) {
        guard let selectedGroup else { return }
        // Pin the current selection so that removing a room — which creates a new
        // single-room group on the device — doesn't cause the UI to jump to that
        // new group on the next refresh.
        selectedGroupID = selectedGroup.id
        let isMember = selectedGroup.rooms.contains(where: { $0.id == room.id })
        if isMember {
            repository.removeRoom(room, from: selectedGroup)
        } else {
            repository.addRoom(room, to: selectedGroup)
        }
    }
}
