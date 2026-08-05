//
//  GroupList.swift
//  sonos-menu
//

import SwiftUI

struct GroupList: View {
    let groups: [SonosGroup]
    let selectedGroupID: String?
    let onSelect: (SonosGroup) -> Void
    let onVolumeChange: (Double, SonosGroup) -> Void
    
    private let rowHeight: CGFloat = 34
    private let selectedRowExtraHeight: CGFloat = 34
    private let spacing: CGFloat = 4

    private var selectedGroupIDs: Set<String> {
        Set(groups.filter { $0.id == selectedGroupID }.map(\.id))
    }

    private var maxHeight: CGFloat {
        rowHeight * 2 + selectedRowExtraHeight + spacing // Show at most 2 rows
    }

    private var contentHeight: CGFloat {
        let selectedCount = groups.filter { selectedGroupIDs.contains($0.id) }.count
        let extraHeight = CGFloat(selectedCount) * selectedRowExtraHeight
        return CGFloat(groups.count) * rowHeight +
        extraHeight +
        CGFloat(max(groups.count - 1, 0)) * spacing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Groups")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(groups.sorted { $0.rooms.count > $1.rooms.count }) { group in
                        GroupRow(
                            group: group,
                            isSelected: group.id == selectedGroupID,
                            onVolumeChange: { onVolumeChange($0, group) },
                            onTap: { onSelect(group) }
                        )
                    }
                }
                .safeAreaPadding(.trailing)
            }
            .frame(height: min(contentHeight, maxHeight))
        }
    }
}

struct GroupRow: View {
    let group: SonosGroup
    let isSelected: Bool
    let onVolumeChange: (Double) -> Void
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)

                VStack(alignment: .leading, spacing: 1) {
                    Text(group.displayName)
                        .font(.system(size: 13))

                    Text("\(group.memberCount) room\(group.memberCount == 1 ? "" : "s")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            if isSelected {
                GroupVolumeSlider(
                    volume: group.volume,
                    isEnabled: true,
                    onEditingFinished: onVolumeChange
                )
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    GroupList(
        groups: [
            SonosGroup(
                id: "group-1",
                name: "Living Room + Kitchen",
                coordinatorID: "room-1",
                householdID: "hh-1",
                rooms: [Room(id: "room-1", name: "Living Room", deviceID: "d1", groupID: "group-1", householdID: "hh-1")]
            )
        ],
        selectedGroupID: "group-1",
        onSelect: { _ in },
        onVolumeChange: { _, _ in }
    )
    .padding()
}
