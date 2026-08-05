//
//  DiscoveryLoadingView.swift
//  sonos-menu
//
//  Created by Gustav Junedahl on 2026-08-05.
//

import SwiftUI

struct DiscoveryLoadingView: View {

    let status: String

    @State private var breathe = false

    var body: some View {

        VStack(spacing: 22) {

            ZStack {

                PulseRings()

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 78, height: 78)
                    .shadow(radius: 12)

                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 34, weight: .medium))
                    .symbolEffect(.variableColor.iterative)
            }
            .scaleEffect(breathe ? 1.02 : 0.98)
            .animation(
                .easeInOut(duration: 2)
                    .repeatForever(autoreverses: true),
                value: breathe
            )

            VStack(spacing: 6) {

                Text("Finding your Sonos system")
                    .font(.headline)

                Text(status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }

            ProgressView()
                .controlSize(.small)
                .frame(width: 180)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
        .onAppear {
            breathe = true
        }
    }
}

private struct PulseRings: View {

    var body: some View {

        TimelineView(.animation) { timeline in

            let t = timeline.date.timeIntervalSinceReferenceDate

            ZStack {

                PulseRing(progress: repeatingProgress(time: t + 0.0))
                PulseRing(progress: repeatingProgress(time: t + 0.7))
                PulseRing(progress: repeatingProgress(time: t + 1.4))
            }
        }
    }

    private func repeatingProgress(time: TimeInterval) -> Double {
        let duration = 2.1
        return (time.truncatingRemainder(dividingBy: duration)) / duration
    }
}

private struct PulseRing: View {

    let progress: Double

    var body: some View {

        Circle()
            .stroke(
                Color.accentColor.opacity(1 - progress),
                lineWidth: 2
            )
            .frame(width: 74, height: 74)
            .scaleEffect(1 + progress * 1.6)
            .opacity(1 - progress)
    }
}
