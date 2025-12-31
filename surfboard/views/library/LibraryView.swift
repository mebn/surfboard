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

    @State private var mediaItems: [String: MediaItem] = [:]
    @State private var isLoading = true
    
    var body: some View {
        VStack(alignment: .leading) {
            Section(title) {
                ScrollView(.horizontal) {
                    HStack(spacing: 40) {
                        ForEach(items) { item in
                            if let mediaItem = mediaItems[item.id] {
                                MediaCard(item: mediaItem)
                                    .containerRelativeFrame(.horizontal, count: 6, spacing: 40)
                            } else if isLoading {
                                ProgressView()
                                    .containerRelativeFrame(.horizontal, count: 6, spacing: 40)
                            }
                        }
                    }
                }
            }
        }
        .scrollClipDisabled()
        .buttonStyle(.borderless)
        .task {
            await loadMediaItems()
        }
    }

    private func loadMediaItems() async {
        let addonManager = AddonManager.shared
        
        await withTaskGroup(of: (String, MediaItem?).self) { group in
            for item in items {
                group.addTask {
                    do {
                        let mediaItem = try await addonManager.fetchMeta(type: item.type, id: item.id)
                        return (item.id, mediaItem)
                    } catch {
                        print("Failed to fetch meta for \(item.id): \(error)")
                        return (item.id, nil)
                    }
                }
            }
            
            for await (id, mediaItem) in group {
                if let mediaItem = mediaItem {
                    mediaItems[id] = mediaItem
                }
            }
        }
        
        isLoading = false
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: FavoriteItem.self, inMemory: true)
}
