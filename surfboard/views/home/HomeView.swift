//
//  HomeView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WatchProgress.lastWatched, order: .reverse) private var continueWatching: [WatchProgress]
    
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
                    if !continueWatching.isEmpty {
                        ContinueWatchingSection(
                            items: continueWatching,
                            onRemove: removeFromContinueWatching
                        )
                    }
                    
                    MediaSection(title: "Popular Movies", items: popularMovies)
                    MediaSection(title: "Popular TV Shows", items: popularTVShows)
                }
            }
        }
    }
    
    private func loadContent() async {
        do {
            async let movies = CinemetaService.shared.fetchPopularMovies()
            async let tvShows = CinemetaService.shared.fetchPopularTVShows()
            
            popularMovies = try await movies
            popularTVShows = try await tvShows
        } catch {
            print("Error loading content: \(error)")
        }
        
        isLoading = false
    }
    
    private func removeFromContinueWatching(_ progress: WatchProgress) {
        modelContext.delete(progress)
    }
}

struct ContinueWatchingSection: View {
    let items: [WatchProgress]
    let onRemove: (WatchProgress) -> Void
    
    @State private var selectedShowProgress: WatchProgress?
    
    var body: some View {
        VStack(alignment: .leading) {
            Section("Continue Watching") {
                ScrollView(.horizontal) {
                    HStack(spacing: 40) {
                        ForEach(items) { progress in
                            NavigationLink(destination: VideoPlayerView(
                                url: progress.streamURL!,
                                title: progress.displayTitle,
                                startTime: progress.currentTime,
                                itemId: progress.itemId,
                                itemType: progress.itemType,
                                itemName: progress.itemName,
                                itemPoster: progress.itemPoster,
                                episodeId: progress.episodeId,
                                episodeSeason: progress.episodeSeason,
                                episodeNumber: progress.episodeNumber,
                                episodeName: progress.episodeName,
                                episodeThumbnail: progress.episodeThumbnail,
                                streamUrl: progress.streamUrl
                            )) {
                                ContinueWatchingCard(progress: progress)
                            }
                            .buttonStyle(.card)
                            .contextMenu {
                                NavigationLink(destination: SingleMediaView(
                                    itemId: progress.itemId,
                                    itemType: progress.itemType
                                )) {
                                    Label("Go to Show", systemImage: "tv")
                                }
                                
                                Button(role: .destructive) {
                                    onRemove(progress)
                                } label: {
                                    Label("Remove from List", systemImage: "xmark.circle")
                                }
                            }
                        }
                    }
                }
            }
        }
        .scrollClipDisabled()
        .buttonStyle(.borderless)
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
                            NavigationLink(destination: SingleMediaView(itemId: item.id, itemType: item.type)) {
                                MediaCard(item: item)
                                    .containerRelativeFrame(.horizontal, count: 6, spacing: 40)
                            }
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
    HomeView()
}

