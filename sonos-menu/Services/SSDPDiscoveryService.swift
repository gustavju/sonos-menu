//
//  SSDPDiscoveryService.swift
//  sonos-menu
//

import Foundation
import Combine
import Darwin.C

final class SSDPDiscoveryService: ObservableObject {
    @Published private(set) var devices: [Device] = []
    @Published private(set) var isScanning = false
    @Published private(set) var lastError: String?

    /// Called on the MainActor when a discovery pass finishes, regardless of success.
    var onDiscoveryFinished: (@MainActor () -> Void)?

    private let ssdpMulticastHost = "239.255.255.250"
    private let ssdpMulticastPort: UInt16 = 1900
    private let searchTarget = "urn:schemas-upnp-org:device:ZonePlayer:1"
    private let socketTimeout: TimeInterval = 5
    private let session = URLSession.shared

    private var discoveryTask: Task<Void, Never>?
    private var refreshTimer: Timer?

    var discoveredDevices: [Device] { devices }

    /// Runs a single SSDP discovery pass. Call again only when the user explicitly refreshes.
    func startContinuousDiscovery(interval: TimeInterval = 15) {
        stopContinuousDiscovery()
        performDiscovery()
    }

    func stopContinuousDiscovery() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        discoveryTask?.cancel()
        discoveryTask = nil
    }

    func refresh() {
        performDiscovery()
    }

    private func performDiscovery() {
        guard !isScanning else { return }
        isScanning = true
        lastError = nil

        let existing = devices
        discoveryTask = Task { [weak self] in
            do {
                let found = try await self?.discover() ?? []
                await MainActor.run { [weak self] in
                    self?.devices = found.isEmpty ? existing : found
                    self?.isScanning = false
                    self?.onDiscoveryFinished?()
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.lastError = error.localizedDescription
                    self?.isScanning = false
                    self?.onDiscoveryFinished?()
                }
            }
        }
    }

    private func discover() async throws -> [Device] {
        let message = """
        M-SEARCH * HTTP/1.1\r
        HOST: \(ssdpMulticastHost):\(ssdpMulticastPort)\r
        MAN: "ssdp:discover"\r
        MX: 3\r
        ST: \(searchTarget)\r
        \r
        """

        guard let data = message.data(using: .utf8) else {
            throw DiscoveryError.encodingFailed
        }

        let socketFD = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard socketFD >= 0 else {
            throw DiscoveryError.socketFailed(errno: errno)
        }
        defer { close(socketFD) }

        var reuse = Int32(1)
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(socketFD, SOL_SOCKET, SO_REUSEPORT, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var bindAddr = sockaddr_in()
        bindAddr.sin_family = sa_family_t(AF_INET)
        bindAddr.sin_port = in_port_t(0).bigEndian
        bindAddr.sin_addr.s_addr = INADDR_ANY

        _ = withUnsafePointer(to: &bindAddr) { pointer -> Int32 in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { addr in
                bind(socketFD, addr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        var mcAddr = in_addr()
        inet_pton(AF_INET, ssdpMulticastHost, &mcAddr)

        var destAddr = sockaddr_in()
        destAddr.sin_family = sa_family_t(AF_INET)
        destAddr.sin_port = ssdpMulticastPort.bigEndian
        destAddr.sin_addr = mcAddr

        let sent = withUnsafePointer(to: &destAddr) { pointer -> Int in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { addr in
                data.withUnsafeBytes { buffer -> Int in
                    sendto(socketFD, buffer.baseAddress, buffer.count, 0, addr, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == data.count else {
            throw DiscoveryError.sendFailed(errno: errno)
        }

        var results: [String: Device] = [:]
        let deadline = Date().addingTimeInterval(socketTimeout)

        var discoveredHosts = Set<String>()

        while Date() < deadline && !Task.isCancelled {
            let content = try await receiveUDP(socket: socketFD, timeout: 1.0)
            guard let content else { continue }
            guard let text = String(data: content, encoding: .utf8) else { continue }

            guard let location = extractLocation(from: text),
                  let host = speakerHost(from: location),
                  !discoveredHosts.contains(host) else {
                continue
            }
            discoveredHosts.insert(host)

            guard let speaker = try? await fetchDescription(host: host) else {
                continue
            }
            results[speaker.host] = speaker
        }

        return Array(results.values)
    }

    private func receiveUDP(socket: Int32, timeout: TimeInterval) async throws -> Data? {
        var buffer = [UInt8](repeating: 0, count: 2048)
        var readFDs = fd_set()
        memset(&readFDs, 0, MemoryLayout<fd_set>.size)

        let fdBits = Int32(MemoryLayout<Int32>.size * 8)
        let index = Int(socket) / Int(fdBits)
        let bit = Int(socket) % Int(fdBits)
        let mask = Int32(bitPattern: 1 << UInt(bit))
        withUnsafeMutablePointer(to: &readFDs) { pointer in
            pointer.withMemoryRebound(to: Int32.self, capacity: MemoryLayout<fd_set>.size / MemoryLayout<Int32>.size) { bits in
                bits[index] |= mask
            }
        }

        var tv = timeval(tv_sec: Int(timeout), tv_usec: Int32((timeout - floor(timeout)) * 1_000_000))
        let ready = select(socket + 1, &readFDs, nil, nil, &tv)
        guard ready > 0 else { return nil }

        let received = buffer.withUnsafeMutableBytes { rawBuffer -> ssize_t in
            recv(socket, rawBuffer.baseAddress, rawBuffer.count, 0)
        }
        guard received > 0 else { return nil }

        return Data(buffer.prefix(Int(received)))
    }

    private func extractLocation(from response: String) -> String? {
        let lines = response.split(separator: "\r\n")
        for line in lines {
            let lower = line.lowercased()
            if lower.hasPrefix("location:") {
                let value = line.dropFirst("location:".count).trimmingCharacters(in: .whitespaces)
                return value
            }
        }
        return nil
    }

    private func speakerHost(from location: String) -> String? {
        guard let url = URL(string: location),
              let host = url.host else { return nil }
        return host
    }

    private func fetchDescription(host: String) async throws -> Device? {
        let url = URL(string: "http://\(host):1400/xml/device_description.xml")!
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              var device = parseDeviceDescription(data: data, host: host) else {
            throw DiscoveryError.badResponse
        }

        // Augment with household ID and boot sequence needed for group management.
        let controller = SonosController(session: session)
        if let (householdID, bootSeq) = try? await controller.fetchDeviceInfo(from: device) {
            device = Device(
                id: device.id,
                name: device.name,
                host: device.host,
                port: device.port,
                model: device.model,
                householdID: householdID,
                bootSeq: bootSeq
            )
        }

        return device
    }

    private func parseDeviceDescription(data: Data, host: String) -> Device? {
        guard let xml = try? XMLDocument(data: data, options: []),
              let root = xml.rootElement() else { return nil }

        let deviceNode = (try? root.nodes(forXPath: "//device"))?.first as? XMLElement
        let friendlyName = (try? deviceNode?.nodes(forXPath: "friendlyName").first?.stringValue) ?? host
        let modelName = try? deviceNode?.nodes(forXPath: "modelName").first?.stringValue
        let rawUDN = (try? deviceNode?.nodes(forXPath: "UDN").first?.stringValue) ?? "uuid:\(host)"
        let udn = rawUDN.lowercased().hasPrefix("uuid:") ? String(rawUDN.dropFirst(5)) : rawUDN

        return Device(
            id: udn,
            name: friendlyName,
            host: host,
            model: modelName,
            householdID: "",
            bootSeq: 0
        )
    }
}

enum DiscoveryError: Error {
    case encodingFailed
    case badResponse
    case cancelled
    case socketFailed(errno: Int32)
    case sendFailed(errno: Int32)
}

extension DiscoveryError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Failed to encode SSDP request."
        case .badResponse: return "Speaker returned an unexpected response."
        case .cancelled: return "Discovery was cancelled."
        case .socketFailed(let code): return "SSDP socket failed (errno \(code))."
        case .sendFailed(let code): return "SSDP send failed (errno \(code))."
        }
    }
}
