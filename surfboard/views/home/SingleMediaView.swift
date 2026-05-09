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
    @FocusState private var focusedEpisodeId: String?

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

    /// The episode to pass to the player for the play button (nil for movies)
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

            let episodeText = String(format: "S%02dE%02d", ep.season, ep.episodeNumber)
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

    // MARK: - Episode Helpers

    private func subtitleFor(_ episode: Episode) -> String {
        var parts = [String(format: "S%02dE%02d", episode.season, episode.episodeNumber)]
        if let releaseDate = episode.formattedReleasedDate {
            parts.append(releaseDate)
        }
        return parts.joined(separator: " • ")
    }

    private func progressFor(_ episode: Episode) -> EpisodeProgress? {
        record?.progressForEpisode(episodeId: episode.id)
    }

    private func deleteProgress(for episode: Episode) {
        record?.clearProgress(episodeId: episode.id)
        try? modelContext.save()
    }

    private var lastFocusedEpisodeKey: String {
        "SingleMediaView.lastFocusedEpisode.\(itemId)"
    }

    private func rememberEpisode(_ episode: Episode) {
        UserDefaults.standard.set(episode.id, forKey: lastFocusedEpisodeKey)
    }

    private func lastFocusedEpisode(in item: MediaItem) -> Episode? {
        guard let episodeId = UserDefaults.standard.string(forKey: lastFocusedEpisodeKey) else { return nil }
        return item.videos?.first { $0.id == episodeId }
    }

    private func seasonAnchor(for season: Int) -> String {
        "\(itemId)-season-\(season)"
    }

    private func restoreSeriesFocus(item: MediaItem, proxy: ScrollViewProxy) {
        guard let episode = lastFocusedEpisode(in: item) else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(100))
            proxy.scrollTo(seasonAnchor(for: episode.season), anchor: .center)
            focusedEpisodeId = episode.id
        }
    }

    @ViewBuilder
    private func mediaContent(item: MediaItem) -> some View {
        if item.isSeries {
            seriesContent(item: item)
        } else {
            movieContent(item: item)
        }
    }

    @ViewBuilder
    private func seriesContent(item: MediaItem) -> some View {
        ScrollViewReader { verticalProxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 36) {
                    HStack(alignment: .center, spacing: 24) {
                        NavigationLink(destination: VideoPlayerView(mediaItem: item, episode: playButtonEpisode(item: item))) {
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

                    ForEach(availableSeasons(item: item), id: \.self) { season in
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Season \(season)")
                                .font(.title3)
                                .fontWeight(.semibold)

                            ScrollViewReader { horizontalProxy in
                                ScrollView(.horizontal) {
                                    HStack(alignment: .top, spacing: 40) {
                                        ForEach(episodes(for: season, item: item)) { episode in
                                            let progress = progressFor(episode)
                                            MediaCard(
                                                imageURL: episode.thumbnailURL,
                                                title: episode.name ?? "Episode \(episode.episodeNumber)",
                                                destination: .sources(item: item, episode: episode),
                                                orientation: .landscape,
                                                subtitle: subtitleFor(episode),
                                                description: episode.displayDescription,
                                                progress: progress,
                                                onDelete: progress != nil ? {
                                                    deleteProgress(for: episode)
                                                } : nil
                                            )
                                            .focused($focusedEpisodeId, equals: episode.id)
                                            .id(episode.id)
                                            .onChange(of: focusedEpisodeId) { _, newValue in
                                                if newValue == episode.id {
                                                    rememberEpisode(episode)
                                                }
                                            }
                                            .simultaneousGesture(
                                                TapGesture().onEnded {
                                                    rememberEpisode(episode)
                                                }
                                            )
                                            .containerRelativeFrame(.horizontal, count: 5, spacing: 40)
                                        }
                                    }
                                }
                                .onAppear {
                                    if lastFocusedEpisode(in: item)?.season == season,
                                       let episodeId = lastFocusedEpisode(in: item)?.id
                                    {
                                        Task { @MainActor in
                                            try? await Task.sleep(for: .milliseconds(100))
                                            horizontalProxy.scrollTo(episodeId, anchor: .center)
                                        }
                                    }
                                }
                            }
                        }
                        .id(seasonAnchor(for: season))
                        .scrollClipDisabled()
                    }
                }
                .padding(.top, 32)
            }
            .onAppear {
                restoreSeriesFocus(item: item, proxy: verticalProxy)
            }
        }
        .scrollClipDisabled()
    }

    @ViewBuilder
    private func movieContent(item: MediaItem) -> some View {
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

                            HStack(spacing: 8) {
                                if let rating = item.imdbRating, !rating.isEmpty {
                                    Text(rating)
                                }

                                if let year = item.year, !year.isEmpty {
                                    if item.imdbRating != nil && !item.imdbRating!.isEmpty {
                                        Text("•")
                                    }
                                    Text(year)
                                }

                                if let runtime = item.runtime, !runtime.isEmpty {
                                    if (item.imdbRating != nil && !item.imdbRating!.isEmpty) || (item.year != nil && !item.year!.isEmpty) {
                                        Text("•")
                                    }
                                    Text(runtime)
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
                            NavigationLink(destination: VideoPlayerView(mediaItem: item, episode: playButtonEpisode(item: item))) {
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
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func episodes(for season: Int, item: MediaItem) -> [Episode] {
        item.episodesBySeason[season]?.sorted { $0.episodeNumber < $1.episodeNumber } ?? []
    }

    /// Returns available seasons, excluding season 0
    private func availableSeasons(item: MediaItem) -> [Int] {
        item.seasons.filter { $0 != 0 }.sorted()
    }
}

#Preview("Movie") {
    SingleMediaView(itemId: "tt0111161", itemType: "movie")
}

#Preview("TV Show") {
    SingleMediaView(itemId: "tt0944947", itemType: "series")
}
