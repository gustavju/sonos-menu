//
//  RoomList.swift
//  sonos-menu
//

import SwiftUI

struct RoomList: View {
    let rooms: [Room]
    let onVolumeChange: (Double, Room) -> Void
    let onToggleMute: (Room) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rooms")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(rooms) { room in
                        RoomVolumeRow(
                            room: room,
                            volume: Binding(
                                get: { Double(room.volume) },
                                set: { onVolumeChange($0, room) }
                            ),
                            onToggleMute: { onToggleMute(room) }
                        )
                    }
                }
            }
            .frame(minHeight: 80, maxHeight: 220)
        }
    }
}

struct RoomVolumeRow: View {
    let room: Room
    @Binding var volume: Double
    let onToggleMute: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(room.name)
                    .font(.system(size: 13))

                if room.isCoordinator {
                    Text("coordinator")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                }

                Spacer()

                Button(action: onToggleMute) {
                    Image(systemName: room.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack {
                Slider(value: $volume, in: 0...100)

                Text("\(Int(volume))")
                    .font(.caption)
                    .monospacedDigit()
                    .frame(minWidth: 22, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    RoomList(
        rooms: [
            Room(id: "r1", name: "Living Room", deviceID: "d1", groupID: "g1", householdID: "hh1", volume: 35),
            Room(id: "r2", name: "Kitchen", deviceID: "d2", groupID: "g1", householdID: "hh1", volume: 20)
        ],
        onVolumeChange: { _, _ in },
        onToggleMute: { _ in }
    )
    .padding()
}
