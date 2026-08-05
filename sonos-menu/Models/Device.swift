//
//  Device.swift
//  sonos-menu
//
//  A network-addressable Sonos player. This is the low-level SOAP target,
//  not a user-facing room or UI entity.
//

import Foundation

struct Device: Identifiable, Codable, Hashable, Sendable {
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case host
        case port
        case model
        case householdID
        case bootSeq
    }

    let id: String
    let name: String
    let host: String
    let port: Int
    let model: String?
    let householdID: String
    let bootSeq: Int

    nonisolated init(
        id: String,
        name: String,
        host: String,
        port: Int = 1400,
        model: String? = nil,
        householdID: String,
        bootSeq: Int
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.model = model
        self.householdID = householdID
        self.bootSeq = bootSeq
    }

    nonisolated var baseURL: URL {
        URL(string: "http://\(host):\(port)")!
    }

    /// Creates a minimal device from topology data when discovery hasn't matched the host yet.
    nonisolated static func topologyHost(id: String, host: String) -> Device {
        Device(
            id: id,
            name: id,
            host: host,
            householdID: "",
            bootSeq: 0
        )
    }
}
