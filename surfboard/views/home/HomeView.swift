//
//  HomeView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftUI
import SwiftData

struct HomeView: View {
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

