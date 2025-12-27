//
//  ContinueWatchingCard.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-27.
//

import SwiftUI

struct ContinueWatchingCard: View {
    let progress: WatchProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Image with progress bar
            ZStack(alignment: .bottom) {
                AsyncImage(url: progress.imageURL) { phase in
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
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // Progress bar overlay
                VStack(spacing: 0) {
                    Spacer()
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                            Rectangle()
                                .fill(Color.white)
                                .frame(width: geometry.size.width * progress.progress)
                        }
                    }
                    .frame(height: 4)
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
            // Text info
            VStack(alignment: .leading, spacing: 4) {
                Text(progress.title)
                    .font(.callout)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if let seasonEpisode = progress.seasonEpisodeText {
                        Text(seasonEpisode)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(progress.timeRemainingText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 320, alignment: .leading)
        }
    }
}

#Preview("Movie") {
    ContinueWatchingCard(
        progress: WatchProgress(
            id: "tt0111161",
            mediaId: "tt0111161",
            mediaType: "movie",
            title: "The Shawshank Redemption",
            imageUrl: "https://images.metahub.space/poster/medium/tt0111161/img",
            currentTime: 3600,
            totalDuration: 8520
        )
    )
}

#Preview("TV Episode") {
    ContinueWatchingCard(
        progress: WatchProgress(
            id: "tt0903747:1:5",
            mediaId: "tt0903747",
            mediaType: "series",
            title: "Breaking Bad",
            imageUrl: "https://episodes.metahub.space/tt0959621/img",
            season: 1,
            episodeNumber: 5,
            episodeName: "Gray Matter",
            currentTime: 1500,
            totalDuration: 2700
        )
    )
}
