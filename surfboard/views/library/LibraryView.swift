//
//  LibraryView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavoriteItem.addedAt, order: .reverse) private var favorites: [FavoriteItem]
    
    private var favoriteMovies: [FavoriteItem] {
        favorites.filter { $0.isMovie }
    }
    
    private var favoriteTVShows: [FavoriteItem] {
        favorites.filter { $0.isSeries }
    }
    
    var body: some View {
        Group {
            if favorites.isEmpty {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "star",
                    description: Text("Movies and TV shows you favorite will appear here")
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 40) {
                        if !favoriteMovies.isEmpty {
                            FavoriteSection(title: "Favorite Movies", items: favoriteMovies)
                        }
                        
                        if !favoriteTVShows.isEmpty {
                            FavoriteSection(title: "Favorite TV Shows", items: favoriteTVShows)
                        }
                    }
                }
            }
        }
    }
}

struct FavoriteSection: View {
    let title: String
    let items: [FavoriteItem]
    
    var body: some View {
        VStack(alignment: .leading) {
            Section(title) {
                ScrollView(.horizontal) {
                    HStack(spacing: 40) {
                        ForEach(items) { item in
                            if let mediaItem = item.mediaItem {
                                MediaCard(item: mediaItem)
                                    .containerRelativeFrame(.horizontal, count: 6, spacing: 40)
                            }
                        }
                    }
                }
            }
        }
        .scrollClipDisabled()
        .buttonStyle(.borderless)
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: FavoriteItem.self, inMemory: true)
}
