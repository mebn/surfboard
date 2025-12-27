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
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail with progress overlay
            ZStack(alignment: .bottom) {
                AsyncImage(url: progress.thumbnailURL) { phase in
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
                                Image(systemName: "play.rectangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                            }
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 320, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Progress bar overlay
                VStack(spacing: 0) {
                    Spacer()
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            // Background
                            Rectangle()
                                .fill(Color.white.opacity(0.3))
                            
                            // Progress
                            Rectangle()
                                .fill(Color.red)
                                .frame(width: geo.size.width * progress.progressPercentage)
                        }
                    }
                    .frame(height: 4)
                }
                .frame(width: 320, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Title and remaining time
            VStack(alignment: .leading, spacing: 4) {
                Text(progress.itemName)
                    .font(.callout)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    if progress.isSeries, let season = progress.episodeSeason, let episode = progress.episodeNumber {
                        Text("S\(season) E\(episode)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(progress.remainingTimeFormatted)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 320, alignment: .leading)
        }
    }
}
