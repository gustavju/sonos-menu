//
//  PlaybackControls.swift
//  sonos-menu
//

import SwiftUI

struct PlaybackControls: View {
    let isPlaying: Bool
    let onPrevious: () -> Void
    let onToggle: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 28) {
            Button(action: onPrevious) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 18, weight: .medium))
            }
            .buttonStyle(.plain)

            Button(action: onToggle) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .medium))
            }
            .buttonStyle(.plain)

            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 18, weight: .medium))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    PlaybackControls(
        isPlaying: false,
        onPrevious: {},
        onToggle: {},
        onNext: {}
    )
    .padding()
}
