//
//  ContinueWatchingCard.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-27.
//

import SwiftUI

struct ContinueWatchingCard: View {
    let record: MediaRecord
    let metadata: MediaItem
    
    let radius: CGFloat = 64
    
    /// Get the best image URL: episode thumbnail -> background -> poster
    private var imageURL: URL? {
        if let progress = record.mostRecentProgress,
           let episodeId = progress.episodeId,
           let episode = metadata.videos?.first(where: { $0.id == episodeId }),
           let thumbnail = episode.thumbnailURL {
            return thumbnail
        }
        return metadata.backgroundURL ?? metadata.posterURL
    }
    
    /// Display title - for TV shows includes episode info
    private var displayTitle: String {
        if let progress = record.mostRecentProgress,
           let seasonEpisode = progress.seasonEpisodeText {
            return "\(metadata.name) - \(seasonEpisode)"
        }
        return metadata.name
    }
    
    var body: some View {
        if let progress = record.mostRecentProgress,
           let streamUrlString = progress.streamUrl,
           let streamUrl = URL(string: streamUrlString) {
            
            // Find the episode if this is a series
            let episode: Episode? = {
                guard let episodeId = progress.episodeId else { return nil }
                return metadata.videos?.first { $0.id == episodeId }
            }()
            
            NavigationLink(destination: VideoPlayerView(url: streamUrl, mediaItem: metadata, episode: episode)) {
                CachedImage(
                    url: imageURL,
                    aspectRatio: 340 / 200,
                    cornerRadius: radius
                )
                .hoverEffect(.highlight)
                
                Text(displayTitle)
                    .lineLimit(1)
                
                HStack(alignment: .center, spacing: 12) {
                    Text(progress.timeRemainingText)
                    
                    if let seasonEpisode = progress.seasonEpisodeText {
                        Text("|")
                        Text(seasonEpisode)
                    }
                }
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
            .buttonStyle(.borderless)
            .buttonBorderShape(.roundedRectangle(radius: radius))
        }
    }
}
