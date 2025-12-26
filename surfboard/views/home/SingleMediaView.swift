//
//  SingleMediaView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftUI

struct SingleMediaView: View {
    let item: MediaItem
    
    @State private var selectedSeason: Int = 1
    
    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            // Left side: Poster and info
            VStack(spacing: 20) {
                MediaCard(item: item)
                
                Text(item.name)
                    .font(.title)
                
                if item.isMovie {
                    NavigationLink(destination: SourcesView(item: item)) {
                        Text("Play")
                    }
                }
            }
            .frame(width: 300)
            
            // Right side: Season/Episode selection for series
            if item.isSeries {
                VStack(alignment: .leading, spacing: 20) {
                    // Season picker
                    if !item.seasons.isEmpty {
                        Picker("Season", selection: $selectedSeason) {
                            ForEach(item.seasons, id: \.self) { season in
                                Text("Season \(season)").tag(season)
                            }
                        }
                        .pickerStyle(.menu)
                        .onAppear {
                            if let firstSeason = item.seasons.first {
                                selectedSeason = firstSeason
                            }
                        }
                    }
                    
                    // Episodes list
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(episodesForSelectedSeason) { episode in
                                NavigationLink(destination: SourcesView(item: item, episode: episode)) {
                                    EpisodeRow(episode: episode)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(60)
        .toolbar(.hidden, for: .tabBar)
    }
    
    private var episodesForSelectedSeason: [Episode] {
        item.episodesBySeason[selectedSeason]?.sorted { $0.episodeNumber < $1.episodeNumber } ?? []
    }
}

struct EpisodeRow: View {
    let episode: Episode
    
    var body: some View {
        HStack(spacing: 16) {
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
            .frame(width: 200, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // Episode info
            VStack(alignment: .leading, spacing: 8) {
                Text("Episode \(episode.episodeNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(episode.name ?? "Episode \(episode.episodeNumber)")
                    .font(.headline)
                    .lineLimit(2)
                
                if let description = episode.displayDescription {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
            }
            
            Spacer()
            
            Image(systemName: "play.circle.fill")
                .font(.title)
                .foregroundColor(.white)
        }
        .padding(12)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    SingleMediaView(item: .preview(poster: "https://images.metahub.space/poster/medium/tt0111161/img"))
}
