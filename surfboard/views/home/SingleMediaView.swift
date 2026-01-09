//
//  SingleMediaView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftData
import SwiftUI

struct SingleMediaView: View {
    let itemId: String
    let itemType: String

    @StateObject private var addonManager = AddonManager.shared
    @StateObject private var metadataCache = MediaMetadataCache.shared
    @Environment(\.modelContext) private var modelContext
    @Query private var allRecords: [MediaRecord]

    @State private var item: MediaItem?
    @State private var isLoading = true
    @State private var selectedSeason: Int = 1

    /// Get or create MediaRecord for this item
    private var record: MediaRecord? {
        allRecords.first { $0.id == itemId }
    }

    private var isFavorited: Bool {
        record?.isFavorite ?? false
    }

    // MARK: - Play Button Logic

    /// Check if a movie has been started but not completed
    private var isMovieStarted: Bool {
        guard let progress = record?.progressForEpisode(episodeId: nil) else { return false }
        return !progress.isCompleted
    }

    /// Determines the next episode to watch for a series
    /// Returns: (episode, isNewEpisode) - isNewEpisode is false if continuing or all watched
    private func nextEpisodeToWatch(item: MediaItem) -> (episode: Episode?, isNewEpisode: Bool, allWatched: Bool) {
        guard let videos = item.videos, !videos.isEmpty else {
            return (nil, true, false)
        }

        // Sort all episodes by season (excluding season 0), then episode number
        let sortedEpisodes = videos
            .filter { $0.season != 0 }
            .sorted { ($0.season, $0.episodeNumber) < ($1.season, $1.episodeNumber) }

        guard !sortedEpisodes.isEmpty else {
            return (nil, true, false)
        }

        // Check for in-progress episode first (started but not finished)
        if let progress = record?.mostRecentProgress,
           let episodeId = progress.episodeId,
           let episode = videos.first(where: { $0.id == episodeId })
        {
            return (episode, false, false) // Continue watching this one
        }

        // Find first unwatched episode
        let watchedIds = record?.watchedEpisodeIds ?? []
        if let nextUnwatched = sortedEpisodes.first(where: { !watchedIds.contains($0.id) }) {
            return (nextUnwatched, true, false) // Play this new episode
        }

        // All watched - return last episode
        return (sortedEpisodes.last, false, true)
    }

    /// The episode to pass to SourcesView for the play button (nil for movies)
    private func playButtonEpisode(item: MediaItem) -> Episode? {
        guard item.isSeries else { return nil }
        return nextEpisodeToWatch(item: item).episode
    }

    /// Dynamic text for the play button
    private func playButtonText(item: MediaItem) -> String {
        if item.isMovie {
            return isMovieStarted ? "Continue Watching" : "Play"
        } else {
            let (episode, isNewEpisode, allWatched) = nextEpisodeToWatch(item: item)

            if allWatched {
                return "No new episodes"
            }

            guard let ep = episode else {
                return "Play"
            }

            let episodeText = "S\(ep.season)E\(ep.episodeNumber)"
            return isNewEpisode ? "Play \(episodeText)" : "Continue Watching \(episodeText)"
        }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if let item = item {
                mediaContent(item: item)
            } else {
                ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: Text("Failed to load content"))
            }
        }
        .task {
            await loadItem()
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private func loadItem() async {
        // Ensure addons are loaded
        if !addonManager.isLoaded {
            await addonManager.loadAddons()
        }

        do {
            // For series: always fetch fresh to catch new episodes
            // For movies: use cache
            if itemType == "series" {
                item = try await metadataCache.fetchFresh(id: itemId, type: itemType)
            } else {
                item = try await metadataCache.get(id: itemId, type: itemType)
            }

            if let loadedItem = item {
                let seasons = loadedItem.seasons.filter { $0 != 0 }.sorted()
                if let firstSeason = seasons.first {
                    selectedSeason = firstSeason
                }
            }
        } catch {
            print("Error loading item: \(error)")
        }
        isLoading = false
    }

    private func toggleFavorite() {
        if let existingRecord = record {
            existingRecord.isFavorite.toggle()
            existingRecord.favoritedAt = existingRecord.isFavorite ? Date() : nil
        } else if let item = item {
            let newRecord = MediaRecord(id: item.id, type: item.type)
            newRecord.isFavorite = true
            newRecord.favoritedAt = Date()
            modelContext.insert(newRecord)
        }
        try? modelContext.save()
    }

    @ViewBuilder
    private func mediaContent(item: MediaItem) -> some View {
        ZStack {
            CachedBackgroundImage(url: item.backgroundURL)
                .ignoresSafeArea()
                .blur(radius: 20)
                .overlay(Color.black.opacity(0.6))

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        CachedImage(
                            url: item.logoURL,
                            width: 400
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            Text(item.description ?? "No Description.")
                                .lineLimit(3)

                            HStack(spacing: 12) {
                                if let field = item.imdbRating, field != "" {
                                    Text("\(field), ")
                                }

                                if let field = item.year, field != "" {
                                    Text("\(field), ")
                                }

                                if let field = item.runtime, field != "" {
                                    Text(field)
                                }
                            }
                            .lineLimit(1)
                            .foregroundColor(.secondary)

                            if let field = item.genres {
                                Text(field.formatted(.list(type: .and, width: .standard)))
                                    .lineLimit(2)
                                    .foregroundColor(.secondary)
                            }

                            if let field = item.cast {
                                Text(field.formatted(.list(type: .and, width: .standard)))
                                    .lineLimit(2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(width: 1000)
                    }

                    Spacer()
                }

                Spacer()

                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .center) {
                        HStack(alignment: .center, spacing: 24) {
                            NavigationLink(destination: SourcesView(item: item, episode: playButtonEpisode(item: item))) {
                                Text(playButtonText(item: item))
                            }
                            .buttonBorderShape(.capsule)
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)

                            Button(action: toggleFavorite) {
                                Image(systemName: isFavorited ? "star.fill" : "star")
                                    .foregroundColor(isFavorited ? .yellow : .white)
                            }
                            .buttonBorderShape(.capsule)
                        }

                        Spacer()

                        // Season button
                        if item.isSeries && !availableSeasons(item: item).isEmpty {
                            Picker("Season", selection: $selectedSeason) {
                                ForEach(availableSeasons(item: item), id: \.self) { season in
                                    Text("Season \(season)").tag(season)
                                }
                            }
                            .pickerStyle(.menu)
                            .buttonBorderShape(.capsule)
                        }
                    }

                    if item.isSeries {
                        VStack(alignment: .leading) {
                            ScrollView(.horizontal) {
                                HStack(spacing: 40) {
                                    ForEach(episodesForSelectedSeason(item: item)) { episode in
                                        EpisodeCard(
                                            item: item,
                                            episode: episode,
                                            isWatched: record?.isEpisodeWatched(episodeId: episode.id) ?? false,
                                            progress: record?.progressForEpisode(episodeId: episode.id)
                                        )
                                        .containerRelativeFrame(.horizontal, count: 5, spacing: 40)
                                    }
                                }
                            }
                        }
                        .scrollClipDisabled()
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func episodesForSelectedSeason(item: MediaItem) -> [Episode] {
        item.episodesBySeason[selectedSeason]?.sorted { $0.episodeNumber < $1.episodeNumber } ?? []
    }

    /// Returns available seasons, excluding season 0
    private func availableSeasons(item: MediaItem) -> [Int] {
        item.seasons.filter { $0 != 0 }.sorted()
    }

    /// Returns the previous season if available, nil otherwise
    private func previousSeason(item: MediaItem) -> Int? {
        let seasons = availableSeasons(item: item)
        guard let currentIndex = seasons.firstIndex(of: selectedSeason),
              currentIndex > 0 else { return nil }
        return seasons[currentIndex - 1]
    }

    /// Returns the next season if available, nil otherwise
    private func nextSeason(item: MediaItem) -> Int? {
        let seasons = availableSeasons(item: item)
        guard let currentIndex = seasons.firstIndex(of: selectedSeason),
              currentIndex < seasons.count - 1 else { return nil }
        return seasons[currentIndex + 1]
    }
}

struct EpisodeCard: View {
    let item: MediaItem
    let episode: Episode
    var isWatched: Bool = false
    var progress: EpisodeProgress? = nil

    /// Check if episode is in progress (started but not completed)
    private var isInProgress: Bool {
        guard let progress = progress else { return false }
        return progress.currentTime > 0 && !progress.isCompleted
    }

    var body: some View {
        NavigationLink(destination: SourcesView(item: item, episode: episode)) {
            CachedImage(
                url: episode.thumbnailURL,
                aspectRatio: 340 / 200
            )
            .overlay {
                if isWatched {
                    // Watched overlay
                    ZStack {
                        Color.black.opacity(0.5)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }
                } else if isInProgress, let progress = progress {
                    // In-progress overlay
                    ZStack(alignment: .bottom) {
                        Color.black.opacity(0.3)

                        VStack {
                            Spacer()
                            Text(progress.timeRemainingText)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                                .padding(.bottom, 12)
                        }
                    }
                }
            }
            .hoverEffect(.highlight)

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(episode.name ?? "Episode \(episode.episodeNumber)")
                        .lineLimit(1)

                    Group {
                        Text("Episode \(episode.episodeNumber)")
                        Text(episode.formattedReleasedDate ?? "")
                    }
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }

                Spacer()
            }
        }
        .buttonStyle(.borderless)
        .buttonBorderShape(.roundedRectangle(radius: 64))
    }
}

#Preview("Movie") {
    SingleMediaView(itemId: "tt0111161", itemType: "movie")
}

#Preview("TV Show") {
    SingleMediaView(itemId: "tt0944947", itemType: "series")
}
