//
//  PlaybackControls.swift
//  sonos-menu
//

import SwiftUI

struct PlaybackControls: View {
    let isPlaying: Bool
    let shuffle: ShuffleMode
    let `repeat`: RepeatMode
    let onPrevious: () -> Void
    let onToggle: () -> Void
    let onNext: () -> Void
    let onToggleShuffle: () -> Void
    let onCycleRepeat: () -> Void

    var body: some View {
        HStack(spacing: 28) {
            Button(action: onPrevious) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 18, weight: .medium))
            }
            .buttonStyle(.plain)

            playButton

            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 18, weight: .medium))
            }
            .buttonStyle(.plain)
        }
    }

    private var playButton: some View {
        Button(action: onToggle) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 28, weight: .medium))
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .topLeading) {
            modeButton(
                symbol: "shuffle",
                isActive: shuffle == .on,
                action: onToggleShuffle,
                label: shuffle == .on ? "Turn shuffle off" : "Turn shuffle on"
            )
            .scaleEffect(0.8)
            .offset(x: -24, y: -19)
        }
        .overlay(alignment: .topTrailing) {
            modeButton(
                symbol: `repeat` == .one ? "repeat.1" : "repeat",
                isActive: `repeat` != .off,
                action: onCycleRepeat,
                label: repeatLabel
            )
            .scaleEffect(0.8)
            .offset(x: 24, y: -19)
        }
    }

    private var repeatLabel: String {
        switch `repeat` {
        case .off: "Repeat off"
        case .all: "Repeat all"
        case .one: "Repeat one"
        }
    }

    private func modeButton(
        symbol: String,
        isActive: Bool,
        action: @escaping () -> Void,
        label: String
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .frame(width: 24, height: 24)
                .background(isActive ? Color.accentColor.opacity(0.14) : Color.clear, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}

#Preview {
    PlaybackControls(
        isPlaying: false,
        shuffle: .off,
        repeat: .off,
        onPrevious: {},
        onToggle: {},
        onNext: {},
        onToggleShuffle: {},
        onCycleRepeat: {}
    )
    .padding()
}
