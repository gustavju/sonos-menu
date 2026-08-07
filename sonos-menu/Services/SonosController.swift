//
//  SonosController.swift
//  sonos-menu
//

import Foundation

actor SonosController: SonosControlling {
    private enum Service {
        case deviceProperties
        case groupManagement
        case groupRenderingControl
        case avTransport
        case renderingControl
        case contentDirectory
        case zoneGroupTopology

        var urn: String {
            switch self {
            case .deviceProperties:
                return "urn:upnp-org:serviceId:DeviceProperties"
            case .groupManagement:
                return "urn:upnp-org:serviceId:GroupManagement"
            case .groupRenderingControl:
                return "urn:upnp-org:serviceId:GroupRenderingControl"
            case .avTransport:
                return "urn:upnp-org:serviceId:AVTransport"
            case .renderingControl:
                return "urn:upnp-org:serviceId:RenderingControl"
            case .contentDirectory:
                return "urn:upnp-org:serviceId:ContentDirectory"
            case .zoneGroupTopology:
                return "urn:upnp-org:serviceId:ZoneGroupTopology"
            }
        }

        var type: String {
            switch self {
            case .deviceProperties:
                return "urn:schemas-upnp-org:service:DeviceProperties:1"
            case .groupManagement:
                return "urn:schemas-upnp-org:service:GroupManagement:1"
            case .groupRenderingControl:
                return "urn:schemas-upnp-org:service:GroupRenderingControl:1"
            case .avTransport:
                return "urn:schemas-upnp-org:service:AVTransport:1"
            case .renderingControl:
                return "urn:schemas-upnp-org:service:RenderingControl:1"
            case .contentDirectory:
                return "urn:schemas-upnp-org:service:ContentDirectory:1"
            case .zoneGroupTopology:
                return "urn:schemas-upnp-org:service:ZoneGroupTopology:1"
            }
        }

        var controlPath: String {
            switch self {
            case .deviceProperties:
                return "/DeviceProperties/Control"
            case .groupManagement:
                return "/GroupManagement/Control"
            case .groupRenderingControl:
                return "/MediaRenderer/GroupRenderingControl/Control"
            case .avTransport:
                return "/MediaRenderer/AVTransport/Control"
            case .renderingControl:
                return "/MediaRenderer/RenderingControl/Control"
            case .contentDirectory:
                return "/MediaServer/ContentDirectory/Control"
            case .zoneGroupTopology:
                return "/ZoneGroupTopology/Control"
            }
        }
    }

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Topology

    func fetchTopology(from device: Device) async throws -> ZoneGroupTopology {
        let body = soapEnvelope(
            service: .zoneGroupTopology,
            action: "GetZoneGroupState"
        )

        let data = try await post(body: body, to: device, service: .zoneGroupTopology)
        if let text = String(data: data, encoding: .utf8) {
            print("ZoneGroupState XML:\n\(text)")
        }
        return parseZoneGroupState(data)
    }

    // MARK: - Transport

    func play(on device: Device) async throws {
        let body = soapEnvelope(
            service: .avTransport,
            action: "Play",
            args: ["InstanceID": "0", "Speed": "1"]
        )
        _ = try await post(body: body, to: device, service: .avTransport)
    }

    func pause(on device: Device) async throws {
        let body = soapEnvelope(
            service: .avTransport,
            action: "Pause",
            args: ["InstanceID": "0"]
        )
        _ = try await post(body: body, to: device, service: .avTransport)
    }

    func nextTrack(on device: Device) async throws {
        let body = soapEnvelope(
            service: .avTransport,
            action: "Next",
            args: ["InstanceID": "0"]
        )
        _ = try await post(body: body, to: device, service: .avTransport)
    }

    func previousTrack(on device: Device) async throws {
        let body = soapEnvelope(
            service: .avTransport,
            action: "Previous",
            args: ["InstanceID": "0"]
        )
        _ = try await post(body: body, to: device, service: .avTransport)
    }

    /// Adds a Sonos favorite to the group's queue and begins playback there.
    ///
    /// Sonos service containers (such as Spotify albums and playlists) reject
    /// `SetAVTransportURI` with UPnP error 714. They must be added to the
    /// coordinator's queue instead.
    func playFavorite(_ favorite: DIDLItem, on device: Device) async throws {
        let metadata = favorite.resourceMetadata ?? favoriteMetadata(for: favorite)

        let addResponse = try await post(
            body: soapEnvelope(
                service: .avTransport,
                action: "AddURIToQueue",
                args: [
                    "InstanceID": "0",
                    "EnqueuedURI": favorite.uri,
                    "EnqueuedURIMetaData": metadata,
                    "DesiredFirstTrackNumberEnqueued": "0",
                    "EnqueueAsNext": "0"
                ]
            ),
            to: device,
            service: .avTransport
        )
        let firstTrackNumber = try parseFirstTrackNumber(from: addResponse)

        _ = try await post(
            body: soapEnvelope(
                service: .avTransport,
                action: "SetAVTransportURI",
                args: [
                    "InstanceID": "0",
                    "CurrentURI": "x-rincon-queue:\(device.id)#0",
                    "CurrentURIMetaData": ""
                ]
            ),
            to: device,
            service: .avTransport
        )

        _ = try await post(
            body: soapEnvelope(
                service: .avTransport,
                action: "Seek",
                args: [
                    "InstanceID": "0",
                    "Unit": "TRACK_NR",
                    "Target": String(firstTrackNumber)
                ]
            ),
            to: device,
            service: .avTransport
        )

        try await play(on: device)
    }

    func fetchNowPlaying(on device: Device) async throws -> Playback {
        let positionData = try await post(
            body: soapEnvelope(service: .avTransport, action: "GetPositionInfo", args: ["InstanceID": "0"]),
            to: device,
            service: .avTransport
        )
        if let text = String(data: positionData, encoding: .utf8) {
            print("GetPositionInfo XML:\n\(text)")
        }

        var info = parsePositionInfo(positionData, device: device)

        let transportData = try? await post(
            body: soapEnvelope(service: .avTransport, action: "GetTransportInfo", args: ["InstanceID": "0"]),
            to: device,
            service: .avTransport
        )
        if let data = transportData,
           let xml = try? XMLDocument(data: data, options: []),
           let state = (try? xml.nodes(forXPath: "//CurrentTransportState"))?.first?.stringValue,
           let parsed = Playback.TransportState(rawValue: state) {
            info.transportState = parsed
            print("TransportState: \(state)")
        }

        return info
    }
    
    func browseContentDirectory(
        on device: Device,
        objectID: String = "FV:2",
        browseFlag: String = "BrowseDirectChildren",
        startingIndex: Int = 0,
        requestedCount: Int = 100
    ) async throws -> [DIDLItem] {
        let browseData = try await post(
            body: soapEnvelope(service: .contentDirectory, action: "Browse", args: [
                "ObjectID": objectID,
                "BrowseFlag": browseFlag,
                "Filter": "*",
                "StartingIndex": String(startingIndex),
                "RequestedCount": String(requestedCount),
                "SortCriteria": ""
            ]),
            to: device,
            service: .contentDirectory
        )
        
        if let text = String(data: browseData, encoding: .utf8) {
            print("Browsdata XML:\n\(text)")
        }
        
        let response: BrowseResult = parseBrowseResponse(browseData)
        
        
        
        let items = parseDIDLItems(response.resultXML, device: device)
        
        
        return items
    }

    // MARK: - Volume

    func setVolume(_ volume: Int, on device: Device) async throws {
        let body = soapEnvelope(
            service: .renderingControl,
            action: "SetVolume",
            args: [
                "InstanceID": "0",
                "Channel": "Master",
                "DesiredVolume": String(clamping: volume, to: 0...100) ?? "0"
            ]
        )
        _ = try await post(body: body, to: device, service: .renderingControl)
    }

    func setGroupVolume(_ volume: Int, on device: Device, groupID: String) async throws {
        let body = soapEnvelope(
            service: .groupRenderingControl,
            action: "SetGroupVolume",
            args: [
                "InstanceID": "0",
                "GroupID": groupID,
                "DesiredVolume": String(clamping: volume, to: 0...100) ?? "0"
            ]
        )
        _ = try await post(body: body, to: device, service: .groupRenderingControl)
    }

    func getGroupVolume(on device: Device, groupID: String) async throws -> Int {
        let body = soapEnvelope(
            service: .groupRenderingControl,
            action: "GetGroupVolume",
            args: [
                "InstanceID": "0",
                "GroupID": groupID
            ]
        )
        let data = try await post(body: body, to: device, service: .groupRenderingControl)
        guard let text = String(data: data, encoding: .utf8) else {
            throw SonosError.parseFailed
        }
        return parseGroupVolumeResponse(text) ?? 0
    }

    private func parseGroupVolumeResponse(_ text: String) -> Int? {
        guard let start = text.range(of: "<CurrentVolume>")?.upperBound,
              let end = text[start...].range(of: "</CurrentVolume>")?.lowerBound else { return nil }
        return Int(text[start..<end])
    }

    // MARK: - Grouping

    func joinGroup(member: Device, coordinatorID: String) async throws {
        let body = soapEnvelope(
            service: .avTransport,
            action: "SetAVTransportURI",
            args: [
                "InstanceID": "0",
                "CurrentURI": "x-rincon:\(coordinatorID)",
                "CurrentURIMetaData": ""
            ]
        )
        _ = try await post(body: body, to: member, service: .avTransport)
    }

    func leaveGroup(member: Device) async throws {
        let body = soapEnvelope(
            service: .avTransport,
            action: "BecomeCoordinatorOfStandaloneGroup",
            args: [
                "InstanceID": "0"
            ]
        )
        _ = try await post(body: body, to: member, service: .avTransport)
    }

    func fetchDeviceInfo(from device: Device) async throws -> (householdID: String, bootSeq: Int) {
        let body = soapEnvelope(service: .deviceProperties, action: "GetHouseholdID")
        let householdData = try await post(body: body, to: device, service: .deviceProperties)
        guard let householdText = String(data: householdData, encoding: .utf8),
              let hStart = householdText.range(of: "<CurrentHouseholdID>")?.upperBound,
              let hEnd = householdText[hStart...].range(of: "</CurrentHouseholdID>")?.lowerBound else {
            throw SonosError.parseFailed
        }
        let householdID = String(householdText[hStart..<hEnd])

        let bootBody = soapEnvelope(service: .deviceProperties, action: "GetZoneInfo")
        let bootData = try await post(body: bootBody, to: device, service: .deviceProperties)
        guard let bootText = String(data: bootData, encoding: .utf8),
              let bStart = bootText.range(of: "<BootSeq>")?.upperBound,
              let bEnd = bootText[bStart...].range(of: "</BootSeq>")?.lowerBound else {
            throw SonosError.parseFailed
        }
        let bootSeq = Int(bootText[bStart..<bEnd]) ?? 0

        return (householdID, bootSeq)
    }

    func getVolume(on device: Device) async throws -> Int {
        let body = soapEnvelope(
            service: .renderingControl,
            action: "GetVolume",
            args: [
                "InstanceID": "0",
                "Channel": "Master"
            ]
        )
        let data = try await post(body: body, to: device, service: .renderingControl)
        guard let text = String(data: data, encoding: .utf8),
              let value = parseVolumeResponse(text) else {
            throw SonosError.parseFailed
        }
        return value
    }

    private func parseVolumeResponse(_ text: String) -> Int? {
        guard let start = text.range(of: "<CurrentVolume>")?.upperBound,
              let end = text[start...].range(of: "</CurrentVolume>")?.lowerBound else { return nil }
        return Int(text[start..<end])
    }

    // MARK: - Helpers

    private func post(body: String, to device: Device, service: Service) async throws -> Data {
        let action = extractAction(from: body)
        print("SOAP request: \(service.controlPath)#\(action) -> \(device.host):1400")
        guard let url = URL(string: "http://\(device.host):1400\(service.controlPath)") else {
            throw SonosError.badURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type")
        request.setValue("\"\(service.type)#\(extractAction(from: body))\"", forHTTPHeaderField: "SOAPACTION")
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SonosError.badResponse
        }
        let responseText = String(data: data, encoding: .utf8) ?? ""
        guard (200..<300).contains(http.statusCode) else {
            print("SOAP fault/HTTP error from \(device.host): status=\(http.statusCode) body=\(responseText)")
            if !responseText.isEmpty {
                throw SonosError.soapFault(detail: responseText)
            }
            throw SonosError.httpStatus(code: http.statusCode)
        }
        return data
    }

    private func extractAction(from envelope: String) -> String {
        // Simple extraction of the inner action element name.
        guard let startRange = envelope.range(of: "<u:", options: .backwards),
              let endRange = envelope[startRange.upperBound...].range(of: ">") else {
            return ""
        }
        return String(envelope[startRange.upperBound..<endRange.lowerBound])
            .components(separatedBy: " ")
            .first ?? ""
    }

    private func soapEnvelope(service: Service, action: String, args: [String: String] = [:]) -> String {
        let encodedArgs = args.map { key, value in
            "<\(key)>\(value.xmlEscaped)</\(key)>"
        }.joined()

        return """
        <?xml version="1.0" encoding="utf-8"?>
        <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
          <s:Body>
            <u:\(action) xmlns:u="\(service.type)">\(encodedArgs)</u:\(action)>
          </s:Body>
        </s:Envelope>
        """
    }

    private func favoriteMetadata(for favorite: DIDLItem) -> String {
        let creator = favorite.creator.map { "<dc:creator>\($0.xmlEscaped)</dc:creator>" } ?? ""
        let albumArt = favorite.albumArtURI.map { "<upnp:albumArtURI>\($0.absoluteString.xmlEscaped)</upnp:albumArtURI>" } ?? ""
        let protocolInfo = favorite.resourceProtocolInfo
            ?? "x-rincon-cpcontainer:*:*:*"

        return """
        <DIDL-Lite xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:upnp="urn:schemas-upnp-org:metadata-1-0/upnp/" xmlns="urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/">
        <item id="\(favorite.id.xmlEscaped)" parentID="\(favorite.parentId.xmlEscaped)" restricted="true"><dc:title>\(favorite.title.xmlEscaped)</dc:title>\(creator)<upnp:class>\(favorite.classType.xmlEscaped)</upnp:class>\(albumArt)<res protocolInfo="\(protocolInfo.xmlEscaped)">\(favorite.uri.xmlEscaped)</res></item>
        </DIDL-Lite>
        """
    }

    private func parseFirstTrackNumber(from data: Data) throws -> Int {
        guard let xml = try? XMLDocument(data: data, options: []),
              let value = (try? xml.nodes(forXPath: "//*[local-name()='FirstTrackNumberEnqueued']"))?.first?.stringValue,
              let trackNumber = Int(value) else {
            throw SonosError.parseFailed
        }
        return trackNumber
    }

    // MARK: - Parsers
    
    private func parseBrowseResponse(_ data: Data) -> BrowseResult {
        guard let xml = try? XMLDocument(data: data, options: []),
              let root = xml.rootElement(),
              let resultNode = (try? root.nodes(forXPath: "//*[local-name()='Result']"))?.first as? XMLElement,
              let resultXML = resultNode.stringValue,
              let numberReturnedNode = (try? root.nodes(forXPath: "//*[local-name()='NumberReturned']"))?.first as? XMLElement,
              let totalMatchesNode = (try? root.nodes(forXPath: "//*[local-name()='TotalMatches']"))?.first as? XMLElement,
              let updateIDNode = (try? root.nodes(forXPath: "//*[local-name()='UpdateID']"))?.first as? XMLElement else {
            print("parseBrowseResponse: could not parse SOAP response")
            return BrowseResult(resultXML: "", numberReturned: 0, totalMatches: 0, updateID: "")
        }

        let numberReturned = Int(numberReturnedNode.stringValue ?? "") ?? 0
        let totalMatches = Int(totalMatchesNode.stringValue ?? "") ?? 0
        let updateID = updateIDNode.stringValue ?? ""

        return BrowseResult(resultXML: resultXML, numberReturned: numberReturned, totalMatches: totalMatches, updateID: updateID)
    }
    
    private func parseDIDLItems(_ resultXML: String, device: Device) -> [DIDLItem] {
        guard let data = resultXML.data(using: .utf8),
              let xml = try? XMLDocument(data: data, options: []),
              let root = xml.rootElement() else {
            print("parseDIDLItems: could not parse DIDL-Lite XML")
            return []
        }

        let itemNodes = (try? root.nodes(forXPath: "//*[local-name()='item']"))?.compactMap { $0 as? XMLElement } ?? []

        return itemNodes.compactMap { item -> DIDLItem? in
            guard let id = item.attribute(forName: "id")?.stringValue,
                  let parentID = item.attribute(forName: "parentID")?.stringValue else { return nil }

            var artURL: URL?
            let title = (try? item.nodes(forXPath: "./*[local-name()='title']"))?.first?.stringValue ?? ""
            let classType = (try? item.nodes(forXPath: "./*[local-name()='class']"))?.first?.stringValue ?? ""
            let resource = (try? item.nodes(forXPath: "./*[local-name()='res']"))?.first as? XMLElement
            let uri = resource?.stringValue ?? ""
            let resourceProtocolInfo = resource?.attribute(forName: "protocolInfo")?.stringValue
            let resourceMetadata = (try? item.nodes(forXPath: "./*[local-name()='resMD']"))?.first?.stringValue
            if let albumArtURI = (try? item.nodes(forXPath: "./*[local-name()='albumArtURI']"))?.first?.stringValue {
                artURL = URL(string: albumArtURI)
            }
            
            let creator = (try? item.nodes(forXPath: "./*[local-name()='creator']"))?.first?.stringValue

            return DIDLItem(
                id: id,
                parentId: parentID,
                title: title,
                classType: classType,
                uri: uri,
                resourceProtocolInfo: resourceProtocolInfo,
                resourceMetadata: resourceMetadata,
                albumArtURI: artURL,
                creator: creator
            )
        }
    }

    
    private func parseZoneGroupState(_ data: Data) -> ZoneGroupTopology {
        guard let xml = try? XMLDocument(data: data, options: []),
              let root = xml.rootElement(),
              let escaped = (try? root.nodes(forXPath: "//ZoneGroupState"))?.first?.stringValue,
              let innerData = escaped.data(using: .utf8),
              let innerXML = try? XMLDocument(data: innerData, options: []),
              let innerRoot = innerXML.rootElement(),
              let zoneGroups = (try? innerRoot.nodes(forXPath: "//ZoneGroups"))?.first as? XMLElement else {
            print("parseZoneGroupState: could not parse escaped ZoneGroupState XML")
            return ZoneGroupTopology(groups: [], memberLocations: [:], memberBootSeqs: [:], memberNames: [:])
        }

        var topology = ZoneGroupTopology(rawZoneGroupState: escaped)

        topology.groups = zoneGroups.children?.compactMap { element -> TopologyGroup? in
            guard let group = element as? XMLElement,
                  let groupID = group.attribute(forName: "ID")?.stringValue,
                  let coordinatorID = group.attribute(forName: "Coordinator")?.stringValue else { return nil }

            let memberIDs: [String] = group.children?.compactMap { child -> String? in
                guard let member = child as? XMLElement,
                      let uuid = member.attribute(forName: "UUID")?.stringValue else { return nil }
                if let location = member.attribute(forName: "Location")?.stringValue,
                   let host = URL(string: location)?.host {
                    topology.memberLocations[uuid] = host
                }
                if let bootSeqString = member.attribute(forName: "BootSeq")?.stringValue,
                   let bootSeq = Int(bootSeqString) {
                    topology.memberBootSeqs[uuid] = bootSeq
                }
                if let zoneName = member.attribute(forName: "ZoneName")?.stringValue, !zoneName.isEmpty {
                    topology.memberNames[uuid] = zoneName
                }
                return uuid
            } ?? []

            let name = group.attribute(forName: "Name")?.stringValue ?? ""
            print("Parsed group: id=\(groupID) coordinator=\(coordinatorID) members=\(memberIDs.joined(separator: ", "))")
            return TopologyGroup(
                id: groupID,
                coordinatorID: coordinatorID,
                memberIDs: memberIDs,
                name: name,
                householdID: nil
            )
        } ?? []

        return topology
    }

    private func parsePositionInfo(_ data: Data, device: Device) -> Playback {
        guard let xml = try? XMLDocument(data: data, options: []),
              let root = xml.rootElement() else { return Playback() }
        
        let relTime = (try? root.nodes(forXPath: "//RelTime"))?.first?.stringValue ?? "00:00:00"
        let trackDuration = (try? root.nodes(forXPath: "//TrackDuration"))?.first?.stringValue ?? "00:00:00"

        let track = (try? root.nodes(forXPath: "//TrackMetaData"))?.first?.stringValue ?? ""

        var title = ""
        var artist = ""
        var album = ""
        var artURL: URL?

        if let trackData = track.data(using: .utf8),
           let trackXML = try? XMLDocument(data: trackData, options: []) {
            trackXML.documentContentKind = .xml

            let didlURI = "urn:schemas-upnp-org:metadata-1-0/DIDL-Lite/"
            let upnpURI = "urn:schemas-upnp-org:metadata-1-0/upnp/"
            let dcURI = "http://purl.org/dc/elements/1.1/"

            trackXML.rootElement()?.addNamespace(XMLNode.namespace(withName: "d", stringValue: didlURI) as! XMLNode)
            trackXML.rootElement()?.addNamespace(XMLNode.namespace(withName: "u", stringValue: upnpURI) as! XMLNode)
            trackXML.rootElement()?.addNamespace(XMLNode.namespace(withName: "dc", stringValue: dcURI) as! XMLNode)

            title = (try? trackXML.nodes(forXPath: "//d:item/dc:title"))?.first?.stringValue ??
                    (try? trackXML.nodes(forXPath: "//title"))?.first?.stringValue ?? ""
            artist = (try? trackXML.nodes(forXPath: "//d:item/dc:creator"))?.first?.stringValue ??
                     (try? trackXML.nodes(forXPath: "//creator"))?.first?.stringValue ?? ""
            album = (try? trackXML.nodes(forXPath: "//d:item/u:album"))?.first?.stringValue ??
                    (try? trackXML.nodes(forXPath: "//album"))?.first?.stringValue ?? ""

            if let rawArtURL = (try? trackXML.nodes(forXPath: "//d:item/u:albumArtURI"))?.first?.stringValue ??
                                (try? trackXML.nodes(forXPath: "//albumArtURI"))?.first?.stringValue {
                artURL = URL(string: rawArtURL) ?? URL(string: rawArtURL, relativeTo: device.baseURL)
            }
        }

        let transportState = (try? root.nodes(forXPath: "//TransportState"))?
            .first?
            .stringValue
            .flatMap { Playback.TransportState(rawValue: $0) } ?? .unknown

        print("parsePositionInfo: title='\(title)' artist='\(artist)' album='\(album)' artURL='\(artURL?.absoluteString ?? "")' state='\(transportState)' relTime='\(relTime)' trackDuration='\(trackDuration)'")
        
        return Playback(
            title: title,
            artist: artist,
            album: album,
            artURL: artURL,
            transportState: transportState,
            relTime: relTime,
            duration: trackDuration,
            fetchedAt: Date()
        )
    }
}

extension String {
    nonisolated var uuidPrefixed: String {
        self.lowercased().hasPrefix("uuid:") ? self : "uuid:\(self)"
    }

    nonisolated var uuidUnprefixed: String {
        self.lowercased().hasPrefix("uuid:") ? String(self.dropFirst(5)) : self
    }

    nonisolated var strippedUUIDPrefix: String {
        self.lowercased().hasPrefix("uuid:") ? String(self.dropFirst(5)) : self
    }

    nonisolated var xmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    nonisolated init?(clamping value: Int, to range: ClosedRange<Int>) {
        self = String(Swift.min(Swift.max(value, range.lowerBound), range.upperBound))
    }
}
