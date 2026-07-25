//
//  ContentView.swift
//  sonos-menu
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = SonosMenuViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HouseholdSelector(
                households: viewModel.households,
                selectedHouseholdID: $viewModel.selectedHouseholdID,
                onSelect: viewModel.selectHousehold
            )

            headerSection

            Divider()

            groupListSection

            Divider()

            roomListSection

            //if let error = viewModel.lastError {
            //    ErrorBanner(message: error)
            //}

            footerStatus
        }
        .padding()
        .frame(width: 320)
        .onAppear(perform: viewModel.onMenuAppear)
        .onDisappear(perform: viewModel.onMenuDisappear)
    }

    @ViewBuilder
    private var headerSection: some View {
        NowPlayingView(playback: viewModel.selectedGroupPlayback) {
            PlaybackControls(
                isPlaying: viewModel.selectedGroupPlayback.transportState.isPlaying,
                onPrevious: viewModel.previousTrack,
                onToggle: viewModel.togglePlayPause,
                onNext: viewModel.nextTrack
            )
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private var groupListSection: some View {
        GroupList(
            groups: viewModel.selectedHousehold?.groups ?? [],
            selectedGroupID: viewModel.selectedGroupID,
            onSelect: viewModel.selectGroup
        )
    }

    @ViewBuilder
    private var roomListSection: some View {
        RoomList(
            rooms: viewModel.allHouseholdRooms,
            isMember: viewModel.isRoomInSelectedGroup,
            onVolumeChange: viewModel.setVolume,
            onToggleMute: viewModel.toggleMute,
            onToggleMembership: viewModel.toggleRoomMembership
        )
    }

    @ViewBuilder
    private var footerStatus: some View {
        HStack {
            if viewModel.isScanning {
                ProgressView()
                    .controlSize(.small)
                Text("Scanning…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else if viewModel.households.isEmpty {
                Text("No devices found")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("Scan") {
                    viewModel.scanForDevices()
                }
                .font(.caption2)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Text("\(viewModel.households.flatMap(\.groups).count) group\(viewModel.households.flatMap(\.groups).count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                Button("Scan") {
                    viewModel.scanForDevices()
                }
                .font(.caption2)
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
    }
}

#Preview {
    ContentView()
}
