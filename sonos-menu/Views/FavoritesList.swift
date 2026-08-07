//
//  FavoritesList.swift
//  sonos-menu
//

import SwiftUI
internal import System

struct FavoritesList: View {
    let favorites: [DIDLItem]
    let onSelect: (DIDLItem) -> Void
    @State private var isExpanded: Bool = true
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if !favorites.isEmpty {
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8)
                        ],
                        spacing: 8
                    ) {
                        ForEach(favorites) { fav in
                            FavoriteTile(
                                favorite: fav,
                                onSelect: onSelect
                            )
                        }
                    }
                }
                .frame(maxHeight: 190)
                Divider()
            }
        } label: {
            HStack {
                Text("Favorites")
                Spacer()
                Text("\(favorites.count)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

struct FavoriteTile: View {
    let favorite: DIDLItem
    let onSelect: (DIDLItem) -> Void
    @State private var isHovered = false

    private let artworkSize: CGFloat = 56
    
    var body: some View {
        Button(action: { onSelect(favorite) }) {
            HStack(spacing: 9) {
                artwork
                    .frame(width: artworkSize, height: artworkSize)

                Text(favorite.title.isEmpty ? "Untitled favorite" : favorite.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(6)
            .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
            .background(.quaternary.opacity(isHovered ? 0.8 : 0.45), in: RoundedRectangle(cornerRadius: 9))
            .overlay {
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(.primary.opacity(isHovered ? 0.16 : 0), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .accessibilityLabel("Play \(favorite.title)")
        .help("Play \(favorite.title)")
    }

    @ViewBuilder
    private var artwork: some View {
        ZStack {
            artworkContent

            if isHovered {
                Circle()
                    .fill(.black.opacity(0.58))
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: "play.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .offset(x: 1)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.85)))
            }
        }
    }

    @ViewBuilder
    private var artworkContent: some View {
        if let artURL = favorite.albumArtURI {
            AsyncImage(url: artURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()

                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 7))

                case .failure(let error):
                    Text(error.localizedDescription)

                @unknown default:
                    EmptyView()
                }
            }
        } else {
            placeholder
        }
    }
    
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 7)
            .fill(.quaternary)
            .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
    }
}


#Preview {
    FavoritesList(
        favorites: [
            DIDLItem(
                id: "FV:2/4",
                parentId: "FV:2",
                title: "Discovery",
                classType: "object.itemobject.item.sonos-favorite",
                uri: "x-rincon-cpcontainer:1004006cspotify%3Aalbum%3A2noRn2Aes5aoNVsU6iWThc?sid=9&flags=108&sn=2",
                albumArtURI: URL(filePath: "https://i.scdn.co/image/ab67616d0000b2731e81bff9807a9e629fce5ade"),
                creator: nil
                ),
            DIDLItem(
                id: "FV:2/3",
                parentId: "FV:2",
                title: "Everything Knuckle Puck",
                classType: "object.itemobject.item.sonos-favorite",
                uri: "x-rincon-cpcontainer:1006206cspotify%3Aplaylist%3A7gW4R8dO1whc2HWtAckeiG?sid=9&flags=8300&sn=2",
                albumArtURI: URL(filePath: "https://image-cdn-ak.spotifycdn.com/image/ab67706c0000da840105af09f19e88378ea24737"),
                creator: nil
            ),

            DIDLItem(
            id: "FV:2/2",
            parentId: "FV:2",
            title: "Särlan i pumpan",
            classType: "object.itemobject.item.sonos-favorite",
            uri: "x-rincon-cpcontainer:1006286cspotify%3Aplaylist%3A0rMhRKKfkhGJW3jnefSLZo?sid=9&flags=10348&sn=2",
            albumArtURI: URL(filePath: "https://mosaic.scdn.co/640/ab67616d00001e024400af0debecb047939c9254ab67616d00001e02641c76b29698131584d68ba5ab67616d00001e02b033087945225272e885808cab67616d00001e02f7d9953294506d5fed135854"),
            creator: nil
            )
            
    ], onSelect: { _ in })
}
