//
//  SearchView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftData
import SwiftUI

struct SearchView: View {
    @StateObject private var addonManager = AddonManager.shared

    @State private var searchText = ""
    @State private var movies: [MediaItem] = []
    @State private var series: [MediaItem] = []
    @State private var isSearching = false

    var body: some View {
        ScrollView {
            if searchText.isEmpty {
                ContentUnavailableView("Search", systemImage: "magnifyingglass", description: Text("Search for movies and TV shows"))
                    .padding(.top, 100)
            } else if isSearching {
                ProgressView()
                    .padding(.top, 100)
            } else if movies.isEmpty && series.isEmpty {
                ContentUnavailableView("No Results", systemImage: "magnifyingglass", description: Text("No results found for \"\(searchText)\""))
                    .padding(.top, 100)
            } else {
                VStack(alignment: .leading, spacing: 40) {
                    if !movies.isEmpty {
                        SearchSection(title: "Movies", items: movies)
                    }
                    if !series.isEmpty {
                        SearchSection(title: "TV Shows", items: series)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Movies, TV Shows...")
        .onChange(of: searchText) { _, newValue in
            Task {
                await performSearch(query: newValue)
            }
        }
        .task {
            // Ensure addons are loaded
            if !addonManager.isLoaded {
                await addonManager.loadAddons()
            }
        }
    }

    private func performSearch(query: String) async {
        guard !query.isEmpty else {
            movies = []
            series = []
            return
        }

        isSearching = true

        do {
            async let movieResults = addonManager.searchCatalogs(type: "movie", query: query)
            async let seriesResults = addonManager.searchCatalogs(type: "series", query: query)

            movies = try await movieResults
            series = try await seriesResults
        } catch {
            print("Search error: \(error)")
        }

        isSearching = false
    }
}

struct SearchSection: View {
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
                    HStack(spacing: 40) {
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
        .buttonStyle(.borderless)
    }
}

#Preview {
    SearchView()
}
