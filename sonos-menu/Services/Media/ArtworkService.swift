//
//  ArtworkService.swift
//  sonos-menu
//

import AppKit

final class ArtworkService {

    private let cache = ArtworkThemeCache()
    private let extractor = ArtworkThemeExtractor()

    func theme(artworkURL: URL?) async -> ArtworkTheme {

        if let artworkURL,
           let cached = await cache.theme(for: artworkURL) {
            return cached
        }
        
        var theme: ArtworkTheme = ArtworkTheme.default
        do {
            let (data, _) = try await URLSession.shared.data(from: artworkURL!)
            guard let image = NSImage(data: data) else { return theme }
            
            theme = extractor.extract(from: image)
            
        } catch {
            
        }
        
        if let artworkURL {
            await cache.store(theme, for: artworkURL)
        }

        return theme
    }
}
