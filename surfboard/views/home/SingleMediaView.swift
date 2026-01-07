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
            
            if let firstSeason = item?.seasons.first {
                selectedSeason = firstSeason
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
            VStack(alignment: .center) {
                HStack(alignment: .top) {
                    MediaCard(item: item)
                        .frame(width: 300)
                    
                    VStack(alignment: .leading) {
                        Text(item.name)
                            .font(.headline)
                            .bold()
                        
                        Text(item.description ?? "")
                        
                        HStack(alignment: .center) {
                            if item.isMovie {
                                NavigationLink(destination: SourcesView(item: item)) {
                                    Text("Play")
                                }
                            }
                            
                            Button(action: toggleFavorite) {
                                Image(systemName: isFavorited ? "star.fill" : "star")
                                    .foregroundColor(isFavorited ? .yellow : .gray)
                                    .font(.title2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(width: 800)
                }
                
                if item.isSeries {
                    VStack(alignment: .leading, spacing: 30) {
                        // Season buttons - horizontal
                        if !item.seasons.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(item.seasons, id: \.self) { season in
                                        Button {
                                            selectedSeason = season
                                        } label: {
                                            Text("Season \(season)")
                                                .font(.callout)
                                                .fontWeight(selectedSeason == season ? .bold : .regular)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 10)
                                                .background(selectedSeason == season ? Color.white : Color.white.opacity(0.2))
                                                .foregroundColor(selectedSeason == season ? .black : .white)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 50)
                            }
                        }
                        
                        // Episodes - horizontal scroll
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                ForEach(episodesForSelectedSeason(item: item)) { episode in
                                    NavigationLink(destination: SourcesView(item: item, episode: episode)) {
                                        EpisodeCard(
                                            episode: episode,
                                            isWatched: record?.isEpisodeWatched(episodeId: episode.id) ?? false
                                        )
                                    }
                                    .buttonStyle(.card)
                                }
                            }
                            .padding(.horizontal, 50)
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
}

struct EpisodeCard: View {
    let episode: Episode
    var isWatched: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Episode thumbnail with watched indicator
            ZStack(alignment: .topTrailing) {
                CachedThumbnail(
                    url: episode.thumbnailURL,
                    width: 320,
                    height: 180,
                    cornerRadius: 10
                )
                
                // Watched checkmark overlay
                if isWatched {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.7))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .padding(8)
                }
            }
            
            // Episode info
            VStack(alignment: .leading, spacing: 6) {
                Text("Episode \(episode.episodeNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(episode.name ?? "Episode \(episode.episodeNumber)")
                    .font(.headline)
                    .lineLimit(1)
                
                if let description = episode.displayDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(width: 320, alignment: .leading)
        }
    }
}

#Preview("Movie") {
    SingleMediaView(itemId: "tt0111161", itemType: "movie")
}

#Preview("Series") {
    SingleMediaView(itemId: "tt0903747", itemType: "series")
}
