//
//  ArtworkTheme.swift
//  sonos-menu
//

import SwiftUI

struct ArtworkTheme: Sendable {
    let vibrant: Color
    let background: Color
    let secondaryBackground: Color
    let foreground: Color

    static let `default` = ArtworkTheme(
        vibrant: .accentColor,
        background: .black,
        secondaryBackground: Color(.sRGB, white: 0.15, opacity: 1),
        foreground: .white
    )
}
