//
//  BrowseResponse.swift
//  sonos-menu
//

struct BrowseResult: Codable, Hashable, Sendable {
    let resultXML: String
    let numberReturned: Int
    let totalMatches: Int
    let updateID: String
    
    nonisolated init(
        resultXML: String,
        numberReturned: Int,
        totalMatches: Int,
        updateID: String
    ) {
        self.resultXML = resultXML
        self.numberReturned = numberReturned
        self.totalMatches = totalMatches
        self.updateID = updateID
    }
}

struct DIDLItem: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let parentId: String
    let title: String
    let classType: String // e.g. "object.item.audioItem.musicTrack"
    let uri: String
    let albumArtURI: String?
    let creator: String?

    nonisolated init(
        id: String,
        parentId: String,
        title: String,
        classType: String,
        uri: String,
        albumArtURI: String?,
        creator: String?
    ) {
        self.id = id
        self.parentId = parentId
        self.title = title
        self.classType = classType
        self.uri = uri
        self.albumArtURI = albumArtURI
        self.creator = creator
    }
}
