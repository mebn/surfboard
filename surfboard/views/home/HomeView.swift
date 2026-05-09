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
    @StateObject private var metadataCache = MediaMetadataCache.shared

    @State private var popularMovies: [MediaItem] = []
    @State private var popularTVShows: [MediaItem] = []
    @State private var highlightedCard: HighlightedHomeCard?
    @State private var highlightedDetails: MediaItem?
    @State private var settledHighlightedCard: HighlightedHomeCard?
    @State private var settledHighlightedDetails: MediaItem?
    @State private var isLoading = true
    @FocusState private var focusedMediaId: String?

    var body: some View {
        if isLoading {
            ProgressView().task {
                await loadContent()
            }
        } else {
            ZStack {
                CachedBackgroundImage(url: highlightedBackgroundURL)
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.68))

                VStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(highlightedTitle)
                            .font(.largeTitle)
                            .lineLimit(2)

                        Text(highlightedMetadata)
                            .foregroundStyle(.secondary)

                        Text(highlightedDescription)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .lineLimit(5)
                    }
                    .frame(height: 300, alignment: .topLeading)
                    .padding(.top, 50)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 40) {
                            ContinueWatchingSection(
                                focusedMediaId: $focusedMediaId,
                                onHighlight: highlight
                            )

                            MediaSection(
                                title: "Popular Movies",
                                items: popularMovies,
                                focusedMediaId: $focusedMediaId,
                                onHighlight: highlight
                            )
                            MediaSection(
                                title: "Popular TV Shows",
                                items: popularTVShows,
                                focusedMediaId: $focusedMediaId,
                                onHighlight: highlight
                            )
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
            .task(id: highlightedCard?.item.id) {
                await settleHighlightedCard()
            }
        }
    }

    private var highlightedItem: MediaItem? {
        highlightedDetails ?? highlightedCard?.item
    }

    private var highlightedBackgroundURL: URL? {
        let backgroundItem = settledHighlightedDetails ?? settledHighlightedCard?.item ?? highlightedItem
        return backgroundItem?.backgroundURL ?? backgroundItem?.posterURL
    }

    private var highlightedTitle: String {
        highlightedCard?.titleOverride ?? highlightedItem?.name ?? ""
    }

    private var highlightedMetadata: String {
        var parts: [String] = []
        if let year = highlightedItem?.year, !year.isEmpty {
            parts.append(year)
        }
        if let score = highlightedItem?.imdbRating, !score.isEmpty {
            parts.append(score)
        }
        return parts.joined(separator: " | ")
    }

    private var highlightedDescription: String {
        if let description = highlightedCard?.descriptionOverride, !description.isEmpty {
            return description
        }
        if let description = highlightedItem?.description, !description.isEmpty {
            return description
        }
        return ""
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

            if highlightedCard == nil, let firstItem = popularMovies.first ?? popularTVShows.first {
                highlight(firstItem)
            }
        } catch {
            print("Error loading content: \(error)")
        }

        isLoading = false
    }

    private func highlight(
        _ item: MediaItem,
        titleOverride: String? = nil,
        descriptionOverride: String? = nil
    ) {
        if highlightedCard?.item.id == item.id,
           highlightedCard?.titleOverride == titleOverride,
           highlightedCard?.descriptionOverride == descriptionOverride
        {
            return
        }

        let isSameItem = highlightedCard?.item.id == item.id
        highlightedCard = HighlightedHomeCard(
            item: item,
            titleOverride: titleOverride,
            descriptionOverride: descriptionOverride
        )

        if !isSameItem {
            highlightedDetails = nil
        }
    }

    private func settleHighlightedCard() async {
        guard let card = highlightedCard else { return }

        try? await Task.sleep(for: .milliseconds(150))
        guard !Task.isCancelled, isCurrentHighlight(card) else { return }

        settledHighlightedCard = card

        guard needsDetailedMetadata(card.item) else {
            settledHighlightedDetails = nil
            return
        }

        do {
            let detailedItem = try await metadataCache.get(id: card.item.id, type: card.item.type)
            if !Task.isCancelled, isCurrentHighlight(card) {
                highlightedDetails = detailedItem
                settledHighlightedDetails = detailedItem
            }
        } catch {
            print("Failed to load highlighted metadata for \(card.item.id): \(error)")
        }
    }

    private func isCurrentHighlight(_ card: HighlightedHomeCard) -> Bool {
        highlightedCard?.item.id == card.item.id
            && highlightedCard?.titleOverride == card.titleOverride
            && highlightedCard?.descriptionOverride == card.descriptionOverride
    }

    private func needsDetailedMetadata(_ item: MediaItem) -> Bool {
        item.background == nil || item.description == nil || item.year == nil || item.imdbRating == nil
    }
}

private struct HighlightedHomeCard {
    let item: MediaItem
    let titleOverride: String?
    let descriptionOverride: String?
}

struct MediaSection: View {
    let title: String
    let items: [MediaItem]
    let focusedMediaId: FocusState<String?>.Binding
    let onHighlight: (MediaItem, String?, String?) -> Void

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

    private func destination(for item: MediaItem) -> CardDestination {
        if item.isMovie {
            return .sources(item: item, episode: nil)
        }
        return .singleMedia(itemId: item.id, itemType: item.type)
    }

    var body: some View {
        VStack(alignment: .leading) {
            Section(title) {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 40) {
                        ForEach(items) { item in
                            let focusId = "media-\(item.type)-\(item.id)"

                            MediaCard(
                                imageURL: item.posterURL,
                                title: item.name,
                                destination: destination(for: item),
                                orientation: .portrait,
                                subtitle: subtitleFor(item),
                                showsText: false,
                                progress: progressFor(item),
                                onDelete: progressFor(item) != nil ? {
                                    recordFor(item)?.clearProgress(episodeId: nil)
                                } : nil
                            )
                            .focused(focusedMediaId, equals: focusId)
                            .onChange(of: focusedMediaId.wrappedValue) { _, newValue in
                                if newValue == focusId {
                                    onHighlight(item, nil, nil)
                                }
                            }
                            .containerRelativeFrame(.horizontal, count: 8, spacing: 40)
                        }
                    }
                }
            }
        }
        .scrollClipDisabled()
    }
}

struct ContinueWatchingSection: View {
    let focusedMediaId: FocusState<String?>.Binding
    let onHighlight: (MediaItem, String?, String?) -> Void

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

    private func fallbackDestination(for item: MediaItem) -> CardDestination {
        if item.isMovie {
            return .sources(item: item, episode: nil)
        }
        return .singleMedia(itemId: item.id, itemType: item.type)
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
                                    let displayTitle = displayTitle(for: item.record, metadata: item.metadata)
                                    let focusId = "continue-\(item.record.id)"

                                    MediaCard(
                                        imageURL: imageURL(for: item.record, metadata: item.metadata),
                                        title: displayTitle,
                                        destination: streamUrl != nil
                                            ? .videoPlayer(url: streamUrl!, mediaItem: item.metadata, episode: ep)
                                            : fallbackDestination(for: item.metadata),
                                        orientation: .landscape,
                                        showsText: false,
                                        progress: progressFor(item.record),
                                        onDelete: {
                                            deleteProgress(for: item.record)
                                        }
                                    )
                                    .focused(focusedMediaId, equals: focusId)
                                    .onChange(of: focusedMediaId.wrappedValue) { _, newValue in
                                        if newValue == focusId {
                                            onHighlight(item.metadata, displayTitle, ep?.displayDescription)
                                        }
                                    }
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
