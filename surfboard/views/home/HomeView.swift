//
//  HomeView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftData
import SwiftUI

struct HomeView: View {
    @StateObject private var addonManager = AddonManager.shared

    @State private var popularMovies: [MediaItem] = []
    @State private var popularTVShows: [MediaItem] = []
    @State private var isLoading = true

    var body: some View {
        if isLoading {
            ProgressView().task {
                await loadContent()
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 40) {
                    ContinueWatchingSection()
                    MediaSection(title: "Popular Movies", items: popularMovies)
                    MediaSection(title: "Popular TV Shows", items: popularTVShows)
                }
            }
        }
    }

    private func loadContent() async {
        // Ensure addons are loaded
        if !addonManager.isLoaded {
            await addonManager.loadAddons()
        }

        do {
            // Fetch movie catalogs
            let movieResults = try await addonManager.fetchCatalogs(type: "movie")
            if let firstMovieCatalog = movieResults.first {
                popularMovies = firstMovieCatalog.items
            }

            // Fetch series catalogs
            let seriesResults = try await addonManager.fetchCatalogs(type: "series")
            if let firstSeriesCatalog = seriesResults.first {
                popularTVShows = firstSeriesCatalog.items
            }
        } catch {
            print("Error loading content: \(error)")
        }

        isLoading = false
    }
}

struct MediaSection: View {
    let title: String
    let items: [MediaItem]

    @Query private var allRecords: [MediaRecord]

    private func recordFor(_ item: MediaItem) -> MediaRecord? {
        allRecords.first { $0.id == item.id }
    }

    private func progressFor(_ item: MediaItem) -> EpisodeProgress? {
        recordFor(item)?.progressForEpisode(episodeId: nil)
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
                    HStack(alignment: .top, spacing: 40) {
                        ForEach(items) { item in
                            MediaCard(
                                imageURL: item.posterURL,
                                title: item.name,
                                destination: .singleMedia(itemId: item.id, itemType: item.type),
                                orientation: .portrait,
                                subtitle: subtitleFor(item),
                                progress: progressFor(item),
                                onDelete: progressFor(item) != nil ? {
                                    recordFor(item)?.clearProgress(episodeId: nil)
                                } : nil
                            )
                            .containerRelativeFrame(.horizontal, count: 6, spacing: 40)
                        }
                    }
                }
            }
        }
        .scrollClipDisabled()
    }
}

struct ContinueWatchingSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MediaRecord.updatedAt, order: .reverse) private var allRecords: [MediaRecord]
    @StateObject private var metadataCache = MediaMetadataCache.shared

    @State private var loadedItems: [(record: MediaRecord, metadata: MediaItem)] = []
    @State private var isLoading = true

    /// Filter to only records that have continue watching data
    private var continueWatchingRecords: [MediaRecord] {
        allRecords.filter { $0.hasContinueWatching }
    }

    /// Get the best image URL: episode thumbnail -> background -> poster
    private func imageURL(for record: MediaRecord, metadata: MediaItem) -> URL? {
        if let progress = record.mostRecentProgress,
           let episodeId = progress.episodeId,
           let episode = metadata.videos?.first(where: { $0.id == episodeId }),
           let thumbnail = episode.thumbnailURL
        {
            return thumbnail
        }
        return metadata.backgroundURL ?? metadata.posterURL
    }

    /// Display title - for TV shows includes episode info
    private func displayTitle(for record: MediaRecord, metadata: MediaItem) -> String {
        if let progress = record.mostRecentProgress,
           let season = progress.season,
           let episode = progress.episodeNumber
        {
            return "\(metadata.name) - S\(String(format: "%02d", season))E\(String(format: "%02d", episode))"
        }
        return metadata.name
    }

    /// Get progress for overlay display
    private func progressFor(_ record: MediaRecord) -> EpisodeProgress? {
        record.mostRecentProgress
    }

    /// Get the episode for this progress (if series)
    private func episode(for record: MediaRecord, metadata: MediaItem) -> Episode? {
        guard let episodeId = record.mostRecentProgress?.episodeId else { return nil }
        return metadata.videos?.first { $0.id == episodeId }
    }

    private func deleteProgress(for record: MediaRecord) {
        if let progress = record.mostRecentProgress {
            record.clearProgress(episodeId: progress.episodeId)
            try? modelContext.save()
        }
    }

    var body: some View {
        if !continueWatchingRecords.isEmpty {
            VStack(alignment: .leading) {
                Section("Continue Watching") {
                    if isLoading {
                        ScrollView(.horizontal) {
                            HStack(spacing: 40) {
                                ForEach(0 ..< 3, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 64)
                                        .fill(Color.gray.opacity(0.3))
                                        .aspectRatio(340 / 200, contentMode: .fit)
                                        .containerRelativeFrame(.horizontal, count: 5, spacing: 40)
                                        .overlay { ProgressView() }
                                }
                            }
                        }
                    } else {
                        ScrollView(.horizontal) {
                            HStack(spacing: 40) {
                                ForEach(loadedItems, id: \.record.id) { item in
                                    let ep = episode(for: item.record, metadata: item.metadata)
                                    let streamUrl = item.record.mostRecentProgress?.streamUrl.flatMap { URL(string: $0) }

                                    MediaCard(
                                        imageURL: imageURL(for: item.record, metadata: item.metadata),
                                        title: displayTitle(for: item.record, metadata: item.metadata),
                                        destination: streamUrl != nil
                                            ? .videoPlayer(url: streamUrl!, mediaItem: item.metadata, episode: ep)
                                            : .singleMedia(itemId: item.metadata.id, itemType: item.metadata.type),
                                        orientation: .landscape,
                                        progress: progressFor(item.record),
                                        onDelete: {
                                            deleteProgress(for: item.record)
                                        }
                                    )
                                    .containerRelativeFrame(.horizontal, count: 5, spacing: 40)
                                }
                            }
                        }
                    }
                }
            }
            .scrollClipDisabled()
            .task(id: continueWatchingRecords.map { $0.id }) {
                await loadMetadata()
            }
        }
    }

    private func loadMetadata() async {
        isLoading = true

        // Prefetch all metadata in parallel
        await metadataCache.prefetch(items: continueWatchingRecords.map { ($0.id, $0.type) })

        // Load metadata for each record
        var items: [(record: MediaRecord, metadata: MediaItem)] = []
        for record in continueWatchingRecords {
            do {
                let metadata = try await metadataCache.get(id: record.id, type: record.type)
                items.append((record: record, metadata: metadata))
            } catch {
                print("Failed to load metadata for \(record.id): \(error)")
            }
        }

        loadedItems = items
        isLoading = false
    }
}

#Preview {
    HomeView()
}
