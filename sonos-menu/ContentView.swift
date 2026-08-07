//
//  ContentView.swift
//  sonos-menu
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel: SonosMenuViewModel
    @State private var artworkTheme: ArtworkTheme = .default
    
    private let artworkService = ArtworkService()
    
    init(repository: SonosRepository) {
        _viewModel = State(
            initialValue: SonosMenuViewModel(repository: repository)
        )
    }
    
    var body: some View {
        content
            .task(id: viewModel.selectedGroupPlayback.artURL) {
                await loadArtworkTheme()
                await viewModel.getFavorites()
            }
            .onAppear(perform: viewModel.onMenuAppear)
            .onDisappear(perform: viewModel.onMenuDisappear)
    }
    
    @ViewBuilder
    private var content: some View {
        
        ZStack {

            if viewModel.allHouseholdRooms.isEmpty {
                DiscoveryLoadingView(status: "Checking between the cushions...")
                    .frame(width: 320, height: 320)
            }

            if !viewModel.allHouseholdRooms.isEmpty {
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
                    FavoritesList(
                        favorites: viewModel.allFavorites,
                        onSelect: viewModel.playFavorite
                    )
                    footerStatus
                }
                .padding()
                .frame(width: 320)
                .background(background)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            
        }
        .animation(.easeInOut(duration: 0.35), value: viewModel.allHouseholdRooms.isEmpty)
    }
    
    @ViewBuilder
    private var background: some View {
        RadialGradient(
            colors: [
                artworkTheme.vibrant.opacity(0.75),
                artworkTheme.background
            ],
            center: .topLeading,
            startRadius: 20,
            endRadius: 450
        )
    }
    
    @MainActor
    private func loadArtworkTheme() async {
        
        guard let url = viewModel.selectedGroupPlayback.artURL else {
            artworkTheme = .default
            return
        }
        
        let newTheme = await artworkService.theme(artworkURL: url)
        withAnimation(.easeInOut(duration: 0.8)) {
            artworkTheme = newTheme
        }
    }
    
    
    @ViewBuilder
    private var headerSection: some View {
        NowPlayingView(playback: viewModel.selectedGroupPlayback) {
            PlaybackControls(
                isPlaying: viewModel.selectedGroupPlayback.transportState.isPlaying,
                shuffle: viewModel.selectedGroupPlayback.shuffle,
                repeat: viewModel.selectedGroupPlayback.repeat,
                onPrevious: viewModel.previousTrack,
                onToggle: viewModel.togglePlayPause,
                onNext: viewModel.nextTrack,
                onToggleShuffle: viewModel.toggleShuffle,
                onCycleRepeat: viewModel.cycleRepeat
            )
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
    
    @ViewBuilder
    private var groupListSection: some View {
        GroupList(
            groups: viewModel.selectedHousehold?.groups ?? [],
            selectedGroupID: viewModel.selectedGroupID,
            onSelect: viewModel.selectGroup,
            onVolumeChange: { volume, _ in viewModel.setGroupVolume(volume) }
        )
    }
    
    @ViewBuilder
    private var roomListSection: some View {
        RoomList(
            rooms: viewModel.allHouseholdRooms,
            isMember: viewModel.isRoomInSelectedGroup,
            onVolumeChange: viewModel.setRoomVolumeDebounced,
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
            
            Spacer()
            
            Button(action: viewModel.quitApp) {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    ContentView(repository: SonosRepository(
        discovery: SSDPDiscoveryService(),
        controller: SonosController()
    ))
}
