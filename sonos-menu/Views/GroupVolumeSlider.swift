//
//  GroupVolumeSlider.swift
//  sonos-menu
//

import SwiftUI

struct GroupVolumeSlider: View {
    let volume: Int
    let isEnabled: Bool
    let onEditingFinished: (Double) -> Void

    @State private var localVolume: Double = 0

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            Slider(
                value: $localVolume,
                in: 0...100,
                onEditingChanged: { editing in
                    if !editing {
                        onEditingFinished(localVolume)
                    }
                }
            )

            Text("\(Int(localVolume))")
                .font(.caption)
                .monospacedDigit()
                .frame(minWidth: 22, alignment: .trailing)
        }
        .disabled(!isEnabled)
        .onAppear { localVolume = Double(volume) }
        .onChange(of: volume) { _, newVolume in
            localVolume = Double(newVolume)
        }
    }
}

#Preview {
    GroupVolumeSlider(volume: 42, isEnabled: true) { _ in }
        .padding()
}
