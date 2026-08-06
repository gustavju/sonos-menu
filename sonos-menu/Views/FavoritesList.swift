//
//  FavoritesList.swift
//  sonos-menu
//

import SwiftUI
internal import System

struct FavoritesList: View {
    let favorites: [DIDLItem]
    @State private var isExpanded: Bool = false
    
    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            if !favorites.isEmpty {
                ScrollView([.horizontal]) {
                    LazyHStack(alignment: .center, spacing: 2) {
                        ForEach(favorites) { fav in
                            FavoriteItem(
                                favorite: fav
                            )
                        }
                    }
                }
                .frame(height: 100)
                Divider()
            }
        } label: {
            Text("Favorites")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

    
    
struct FavoriteItem: View {
    let favorite: DIDLItem
    let contentHeight: CGFloat = 65
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            artwork
                .frame(width: contentHeight, height: contentHeight)
            
            Text(favorite.title.isEmpty ? "" : favorite.title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)            
            
        }
        //.onTapGesture(perform: onTap)
        .frame(width: contentHeight, height: 60)
    }

    @ViewBuilder
    private var artwork: some View {
        if let artURL = favorite.albumArtURI {
            AsyncImage(url: artURL) { phase in
                switch phase {
                case .empty:
                    ProgressView()

                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

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
        RoundedRectangle(cornerRadius: 6)
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
            
    ])
}
