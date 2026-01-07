//
//  HomeView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftUI
import SwiftData

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
    
    var body: some View {
        VStack(alignment: .leading) {
            Section(title) {
                ScrollView(.horizontal) {
                    HStack(spacing: 40) {
                        ForEach(items) { item in
                            MediaCard(item: item)
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
    @Query(sort: \MediaRecord.updatedAt, order: .reverse) private var allRecords: [MediaRecord]
    @StateObject private var metadataCache = MediaMetadataCache.shared
    
    @State private var loadedItems: [(record: MediaRecord, metadata: MediaItem)] = []
    @State private var isLoading = true
    
    /// Filter to only records that have continue watching data
    private var continueWatchingRecords: [MediaRecord] {
        allRecords.filter { $0.hasContinueWatching }
    }
    
    var body: some View {
        if !continueWatchingRecords.isEmpty {
            VStack(alignment: .leading) {
                Section("Continue Watching") {
                    if isLoading {
                        ScrollView(.horizontal) {
                            HStack(spacing: 40) {
                                ForEach(0..<3, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 64)
                                        .fill(Color.gray.opacity(0.3))
                                        .aspectRatio(340/200, contentMode: .fit)
                                        .containerRelativeFrame(.horizontal, count: 5, spacing: 40)
                                        .overlay { ProgressView() }
                                }
                            }
                        }
                    } else {
                        ScrollView(.horizontal) {
                            HStack(spacing: 40) {
                                ForEach(loadedItems, id: \.record.id) { item in
                                    ContinueWatchingCard(record: item.record, metadata: item.metadata)
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
