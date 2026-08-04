//
//  NowPlayingView.swift
//  sonos-menu
//

import SwiftUI

struct NowPlayingView<BottomContent: View>: View {
    let playback: Playback
    @ViewBuilder let bottomContent: () -> BottomContent

    /// Matches the cover art size to the combined height of the track info and bottom content.
    @State private var contentHeight: CGFloat = 80

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            artwork
                .frame(width: contentHeight, height: contentHeight)

            VStack(alignment: .leading, spacing: 10) {
                trackInfo
                trackDurationBar
                bottomContent()
            }
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { contentHeight = geometry.size.height }
                        .onChange(of: geometry.size.height) { _, newHeight in
                            contentHeight = newHeight
                        }
                }
            )

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var trackInfo: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(playback.title.isEmpty ? "Not Playing" : playback.title)
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)

            Text(playback.artist.isEmpty ? "" : playback.artist)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(playback.album.isEmpty ? "" : playback.album)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
    
    @ViewBuilder
    private var trackDurationBar: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { context in
            VStack(spacing: 3) {
                GeometryReader { proxy in
                    let progress = playback.effectiveProgress(now: context.date)

                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.tertiary)

                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: proxy.size.width * progress)
                    }
                }
                .frame(height: 3)

                HStack {
                    Text(playback.liveRelTime(now: context.date).toTrackDisplayString)

                    Spacer()

                    Text(playback.duration.toTrackDisplayString)
                }
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let artURL = playback.artURL {
            AsyncImage(url: artURL) { phase in
                switch phase {
                case .empty:
                    placeholder
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                case .failure:
                    placeholder
                @unknown default:
                    EmptyView()
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(.quaternary)
            .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
    }
}

#Preview {
    NowPlayingView(
        playback: Playback(
            title: "Preview Track",
            artist: "Preview Artist",
            album: "Preview Album",
            transportState: .pausedPlayback
        ),
        bottomContent: { EmptyView() }
    )
    .padding()
    .frame(width: 320)
}
