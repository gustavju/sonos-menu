//
//  GroupList.swift
//  sonos-menu
//

import SwiftUI

struct GroupList: View {
    let groups: [Group]
    let selectedGroupID: String?
    let onSelect: (Group) -> Void
    
    private let rowHeight: CGFloat = 34
    private let spacing: CGFloat = 4

    private var maxHeight: CGFloat {
        rowHeight * 2 + spacing // Show at most 2 rows
    }

    private var contentHeight: CGFloat {
        CGFloat(groups.count) * rowHeight +
        CGFloat(max(groups.count - 1, 0)) * spacing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Groups")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(groups.sorted { $0.rooms.count > $1.rooms.count }) { group in
                        GroupRow(
                            group: group,
                            isSelected: group.id == selectedGroupID,
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
    let group: Group
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
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
        .padding(.vertical, 2)
    }
}

#Preview {
    GroupList(
        groups: [
            Group(
                id: "group-1",
                name: "Living Room + Kitchen",
                coordinatorID: "room-1",
                householdID: "hh-1",
                rooms: [Room(id: "room-1", name: "Living Room", deviceID: "d1", groupID: "group-1", householdID: "hh-1")]
            )
        ],
        selectedGroupID: "group-1",
        onSelect: { _ in }
    )
    .padding()
}
