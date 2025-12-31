//
//  ContinueWatchingCard.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-27.
//

import SwiftUI

struct ContinueWatchingCard: View {
    let progress: WatchProgress
    
    let radius: CGFloat = 64
    
    var body: some View {
        NavigationLink(destination: HomeView()) {
            AsyncImage(url: progress.imageURL) { image in
                image
                    .resizable()
                    .clipShape(.rect(cornerRadius: radius))
                    .hoverEffect(.highlight)
            } placeholder: {
                ProgressView()
            }
            .aspectRatio(340 / 200, contentMode: .fit)
            
            Text(progress.title)
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
