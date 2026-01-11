//
//  LibraryView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MediaRecord.favoritedAt, order: .reverse) private var allRecords: [MediaRecord]
    @StateObject private var metadataCache = MediaMetadataCache.shared

    @State private var favoriteMovies: [(record: MediaRecord, metadata: MediaItem)] = []
    @State private var favoriteTVShows: [(record: MediaRecord, metadata: MediaItem)] = []
    @State private var isLoading = true

    /// Filter to only favorited records
    private var favoriteRecords: [MediaRecord] {
        allRecords.filter { $0.isFavorite }
    }

    var body: some View {
        Group {
            if favoriteRecords.isEmpty {
                ContentUnavailableView(
                    "No Favorites",
                    systemImage: "star",
                    description: Text("Movies and TV shows you favorite will appear here")
                )
            } else if isLoading {
                ProgressView()
                    .task {
                        await loadMetadata()
                    }
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
        .onChange(of: favoriteRecords.count) {
            Task {
                await loadMetadata()
            }
        }
    }

    private func loadMetadata() async {
        isLoading = true

        // Prefetch all metadata in parallel
        await metadataCache.prefetch(items: favoriteRecords.map { ($0.id, $0.type) })

        // Load metadata for each record
        var movies: [(record: MediaRecord, metadata: MediaItem)] = []
        var tvShows: [(record: MediaRecord, metadata: MediaItem)] = []

        for record in favoriteRecords {
            do {
                let metadata = try await metadataCache.get(id: record.id, type: record.type)
                if record.type == "movie" {
                    movies.append((record: record, metadata: metadata))
                } else {
                    tvShows.append((record: record, metadata: metadata))
                }
            } catch {
                print("Failed to load metadata for \(record.id): \(error)")
            }
        }

        favoriteMovies = movies
        favoriteTVShows = tvShows
        isLoading = false
    }
}

struct FavoriteSection: View {
    let title: String
    let items: [(record: MediaRecord, metadata: MediaItem)]

    private func progressFor(_ record: MediaRecord) -> EpisodeProgress? {
        record.progressForEpisode(episodeId: nil)
    }

    private func subtitleFor(_ item: MediaItem) -> String? {
        var parts: [String] = []
        if let rating = item.imdbRating, !rating.isEmpty {
            parts.append(rating)
        }
        if let year = item.year, !year.isEmpty {
            parts.append(year)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    var body: some View {
        VStack(alignment: .leading) {
            Section(title) {
                ScrollView(.horizontal) {
                    HStack(spacing: 40) {
                        ForEach(items, id: \.record.id) { item in
                            MediaCard(
                                imageURL: item.metadata.posterURL,
                                title: item.metadata.name,
                                destination: .singleMedia(itemId: item.metadata.id, itemType: item.metadata.type),
                                orientation: .portrait,
                                subtitle: subtitleFor(item.metadata),
                                progress: progressFor(item.record),
                                onDelete: progressFor(item.record) != nil ? {
                                    item.record.clearProgress(episodeId: nil)
                                } : nil
                            )
                            .containerRelativeFrame(.horizontal, count: 6, spacing: 40)
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
        .modelContainer(for: MediaRecord.self, inMemory: true)
}
