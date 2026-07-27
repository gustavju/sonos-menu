//
//  RoomList.swift
//  sonos-menu
//

import SwiftUI

struct RoomList: View {
    let rooms: [Room]
    let isMember: (Room) -> Bool
    let onVolumeChange: (Double, Room) -> Void
    let onToggleMute: (Room) -> Void
    let onToggleMembership: (Room) -> Void
    
    private let rowHeight: CGFloat = 44
    private let spacing: CGFloat = 4

    private var maxHeight: CGFloat {
        rowHeight * 3 + spacing // Show at most 3 rows
    }

    private var contentHeight: CGFloat {
        CGFloat(rooms.count) * rowHeight +
        CGFloat(max(rooms.count - 1, 0)) * spacing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rooms")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(rooms.sorted(by: ) { $0.name > $1.name }) { room in
                        RoomVolumeRow(
                            room: room,
                            isMember: isMember(room),
                            volume: Binding(
                                get: { Double(room.volume) },
                                set: { onVolumeChange($0, room) }
                            ),
                            onToggleMute: { onToggleMute(room) },
                            onToggleMembership: { onToggleMembership(room) }
                        )
                    }
                }
                .safeAreaPadding(.trailing)
            }
            .frame(height: min(contentHeight, maxHeight))
        }
    }
}

struct RoomVolumeRow: View {
    let room: Room
    let isMember: Bool
    @Binding var volume: Double
    let onToggleMute: () -> Void
    let onToggleMembership: () -> Void

    private var canToggleMembership: Bool {
        // Prevent removing the coordinator from the group; Sonos requires a group
        // to keep a coordinator.
        !(isMember && room.isCoordinator)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Button(action: onToggleMembership) {
                    HStack(spacing: 4) {
                        Image(systemName: isMember ? "checkmark.square.fill" : "square")
                            .foregroundStyle(isMember ? Color.accentColor : .secondary)
                        Text(room.name)
                            .font(.system(size: 13))
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canToggleMembership)

                if isMember && room.isCoordinator {
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
                    .disabled(!isMember)

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
            Room(id: "r1", name: "Living Room", deviceID: "d1", groupID: "g1", householdID: "hh1", volume: 35, isCoordinator: true),
            Room(id: "r2", name: "Kitchen", deviceID: "d2", groupID: "g2", householdID: "hh1", volume: 20),
            Room(id: "r3", name: "Bedroom", deviceID: "d3", groupID: "g3", householdID: "hh1", volume: 15)
        ],
        isMember: { $0.id == "r1" || $0.id == "r2" },
        onVolumeChange: { _, _ in },
        onToggleMute: { _ in },
        onToggleMembership: { _ in }
    )
    .padding()
}
