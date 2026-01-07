//
//  SingleMediaView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftUI
import SwiftData

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
            // Fullscreen background
            CachedBackgroundImage(url: item.backgroundURL)
                .ignoresSafeArea()
                .blur(radius: 10)
            
            // Content
            VStack(alignment: .center, spacing: 24) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading) {
                        CachedImage(
                            url: item.logoURL,
                            aspectRatio: 170 / 100
                        )
                        
                        Text(item.name)
                            .font(.headline)
                            .bold()
                        
                        Text(item.description ?? "")
                        
                        HStack(alignment: .center) {
                            NavigationLink(destination: SourcesView(item: item)) {
                                Text(item.isMovie ? "Play" : "Continue watching")
                            }
                            .buttonBorderShape(.capsule)
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                            
                            Button(action: toggleFavorite) {
                                Image(systemName: isFavorited ? "star.fill" : "star")
                                    .foregroundColor(isFavorited ? .yellow : .gray)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .frame(width: 800)
                }
                
                if item.isSeries {
                    VStack(alignment: .leading, spacing: 30) {
                        // Episodes - horizontal scroll
                        VStack(alignment: .leading) {
                            ScrollView(.horizontal) {
                                HStack(spacing: 40) {
                                    ForEach(episodesForSelectedSeason(item: item)) { episode in
                                        EpisodeCard(
                                            episode: episode,
                                            isWatched: record?.isEpisodeWatched(episodeId: episode.id) ?? false
                                        )
                                            .containerRelativeFrame(.horizontal, count: 5, spacing: 40)
                                    }
                                }
                            }
                        }
                        .scrollClipDisabled()
                        
                        // Season buttons - horizontal
                        if !availableSeasons(item: item).isEmpty {
                            HStack(alignment: .center, spacing: 24) {
                                Button {
                                    if let prevSeason = previousSeason(item: item) {
                                        selectedSeason = prevSeason
                                    }
                                } label: {
                                    Image(systemName: "chevron.left")
                                }
                                .disabled(previousSeason(item: item) == nil)
                                .buttonBorderShape(.capsule)
                                
                                Picker("Season", selection: $selectedSeason) {
                                    ForEach(availableSeasons(item: item), id: \.self) { season in
                                        Text("Season \(season)").tag(season)
                                    }
                                }
                                .pickerStyle(.menu)
                                .buttonBorderShape(.capsule)
                                
                                Button {
                                    if let nextSeason = nextSeason(item: item) {
                                        selectedSeason = nextSeason
                                    }
                                } label: {
                                    Image(systemName: "chevron.right")
                                }
                                .disabled(nextSeason(item: item) == nil)
                                .buttonBorderShape(.capsule)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
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
    let episode: Episode
    var isWatched: Bool = false
    
    let radius: CGFloat = 64
    
    var body: some View {
        NavigationLink(destination: HomeView()) {
            CachedImage(
                url: episode.thumbnailURL,
                aspectRatio: 340 / 200,
                cornerRadius: radius
            )
            .hoverEffect(.highlight)
            
            Text(episode.name ?? "Episode \(episode.episodeNumber)")
                .lineLimit(1)
            
            HStack(alignment: .center, spacing: 12) {
                Text("Episode \(episode.episodeNumber)")
                
                if let released = episode.released {
                    Text("|")
                    Text(released)
                }
            }
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
        .buttonStyle(.borderless)
        .buttonBorderShape(.roundedRectangle(radius: radius))
    }
}

#Preview("Movie") {
    SingleMediaView(itemId: "tt0111161", itemType: "movie")
}

#Preview("Series") {
    SingleMediaView(itemId: "tt0903747", itemType: "series")
}
