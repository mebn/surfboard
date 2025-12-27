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
    
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [FavoriteItem]
    
    @State private var item: MediaItem?
    @State private var isLoading = true
    @State private var selectedSeason: Int = 1
    
    private var isFavorited: Bool {
        favorites.contains { $0.id == itemId }
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
        do {
            item = try await CinemetaService.shared.fetchMediaDetails(type: itemType, id: itemId)
            if let firstSeason = item?.seasons.first {
                selectedSeason = firstSeason
            }
        } catch {
            print("Error loading item: \(error)")
        }
        isLoading = false
    }
    
    private func toggleFavorite() {
        if let existingFavorite = favorites.first(where: { $0.id == itemId }) {
            modelContext.delete(existingFavorite)
        } else if let item = item {
            let favorite = FavoriteItem(from: item)
            modelContext.insert(favorite)
        }
    }
    
    @ViewBuilder
    private func mediaContent(item: MediaItem) -> some View {
        ZStack {
            // Fullscreen background
            AsyncImage(url: item.backgroundURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .empty, .failure:
                    Color.black
                @unknown default:
                    Color.black
                }
            }
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
                        LazyHStack(spacing: 20) {
                            ForEach(episodesForSelectedSeason(item: item)) { episode in
                                NavigationLink(destination: SourcesView(item: item, episode: episode)) {
                                    EpisodeCard(episode: episode)
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Episode thumbnail
            AsyncImage(url: episode.thumbnailURL) { phase in
                switch phase {
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            ProgressView()
                        }
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        }
                @unknown default:
                    EmptyView()
                }
            }
            .frame(width: 320, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
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
