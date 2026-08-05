//
//  ArtworkThemeCache.swift
//  sonos-menu
//
import Foundation

actor ArtworkThemeCache {

    private var cache: [URL: ArtworkTheme] = [:]

    func theme(for url: URL) -> ArtworkTheme? {
        cache[url]
    }

    func store(_ theme: ArtworkTheme, for url: URL) {
        cache[url] = theme
    }

    func clear() {
        cache.removeAll()
    }
}
