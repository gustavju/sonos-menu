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

    @State private var previousPressID = 0
    @State private var nextPressID = 0
    @State private var playPressID = 0
    @State private var previousOffset: CGFloat = 0
    @State private var nextOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 28) {
            Button(action: previousTapped) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 18, weight: .medium))
                    .offset(x: previousOffset)
                    .symbolEffect(.bounce, value: previousPressID)
            }
            .buttonStyle(TransportButtonStyle())

            playButton

            Button(action: nextTapped) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 18, weight: .medium))
                    .offset(x: nextOffset)
                    .symbolEffect(.bounce, value: nextPressID)
            }
            .buttonStyle(TransportButtonStyle())
        }
    }

    private var playButton: some View {
        Button(action: playTapped) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 28, weight: .medium))
                .frame(width: 34, height: 34)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.pulse, value: playPressID)
                .animation(.easeInOut(duration: 0.2), value: isPlaying)
        }
        .buttonStyle(TransportButtonStyle())
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

    private func previousTapped() {
        previousPressID += 1
        nudge(offset: $previousOffset, direction: -1)
        onPrevious()
    }

    private func nextTapped() {
        nextPressID += 1
        nudge(offset: $nextOffset, direction: 1)
        onNext()
    }

    private func playTapped() {
        playPressID += 1
        onToggle()
    }

    private func nudge(offset: Binding<CGFloat>, direction: CGFloat) {
        withAnimation(.easeOut(duration: 0.08)) {
            offset.wrappedValue = direction * 5
        }

        withAnimation(.spring(response: 0.2, dampingFraction: 0.75).delay(0.08)) {
            offset.wrappedValue = 0
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

private struct TransportButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .opacity(configuration.isPressed ? 0.68 : 1)
            .animation(.spring(response: 0.16, dampingFraction: 0.72), value: configuration.isPressed)
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
