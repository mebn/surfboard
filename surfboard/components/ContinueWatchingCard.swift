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
        if let streamUrl = progress.streamUrl, let url = URL(string: streamUrl) {
            NavigationLink(destination: VideoPlayerView(url: url, progress: progress)) {
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
}
