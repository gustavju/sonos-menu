//
//  SonosControlling.swift
//  sonos-menu
//
//  Protocol for the low-level SOAP control layer. Inputs are network `Device`s
//  and plain identifiers. Domain objects live in the repository layer above.
//

import Foundation

protocol SonosControlling: Sendable {
    func fetchTopology(from device: Device) async throws -> ZoneGroupTopology
    func play(on device: Device) async throws
    func pause(on device: Device) async throws
    func nextTrack(on device: Device) async throws
    func previousTrack(on device: Device) async throws
    func playFavorite(_ favorite: DIDLItem, on device: Device) async throws
    func setPlayMode(shuffle: ShuffleMode, repeat: RepeatMode, on device: Device) async throws
    func setVolume(_ volume: Int, on device: Device) async throws
    func setGroupVolume(_ volume: Int, on device: Device, groupID: String) async throws
    func getGroupVolume(on device: Device, groupID: String) async throws -> Int
    func getVolume(on device: Device) async throws -> Int
    func fetchDeviceInfo(from device: Device) async throws -> (householdID: String, bootSeq: Int)
    func joinGroup(member: Device, coordinatorID: String) async throws
    func leaveGroup(member: Device) async throws
    func fetchNowPlaying(on device: Device) async throws -> Playback
    func browseContentDirectory(on device: Device, objectID: String, browseFlag: String, startingIndex: Int, requestedCount: Int) async throws -> [DIDLItem]
}
