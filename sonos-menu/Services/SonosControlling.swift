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
    func setVolume(_ volume: Int, on device: Device) async throws
    func setGroupVolume(_ volume: Int, on device: Device, groupID: String) async throws
    func getGroupVolume(on device: Device, groupID: String) async throws -> Int
    func getVolume(on device: Device) async throws -> Int
    func fetchDeviceInfo(from device: Device) async throws -> (householdID: String, bootSeq: Int)
    func addMember(_ memberID: String, fromHost: String, to device: Device, groupID: String, bootSeq: Int) async throws
    func removeMember(_ memberID: String, from device: Device, groupID: String, bootSeq: Int) async throws
    func fetchNowPlaying(on device: Device) async throws -> Playback
}
