//
//  MediaCard.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-01-11.
//

import SwiftUI

// MARK: - Shared Types

enum CardDestination {
    case singleMedia(itemId: String, itemType: String)
    case sources(item: MediaItem, episode: Episode?)
    case videoPlayer(url: URL, mediaItem: MediaItem, episode: Episode?)
}

enum CardOrientation {
    case portrait
    case landscape

    var aspectRatio: CGFloat {
        switch self {
        case .portrait:
            return 250 / 375
        case .landscape:
            return 340 / 200
        }
    }
}

// MARK: - MediaCard

struct MediaCard: View {
    // Required
    let imageURL: URL?
    let title: String
    let destination: CardDestination
    let orientation: CardOrientation

    // Optional display
    var subtitle: String? = nil
    var description: String? = nil
    var showsText: Bool = true

    // Progress tracking
    var progress: EpisodeProgress? = nil

    // Delete action (only shown if non-nil)
    var onDelete: (() -> Void)? = nil

    private var isWatched: Bool {
        progress?.isCompleted ?? false
    }

    private var isInProgress: Bool {
        guard let progress = progress else { return false }
        return progress.currentTime > 0 && !progress.isCompleted
    }

    @ViewBuilder
    private var destinationView: some View {
        switch destination {
        case let .singleMedia(itemId, itemType):
            SingleMediaView(itemId: itemId, itemType: itemType)
        case let .sources(item, episode):
            VideoPlayerView(mediaItem: item, episode: episode)
        case let .videoPlayer(url, mediaItem, episode):
            VideoPlayerView(url: url, mediaItem: mediaItem, episode: episode)
        }
    }

    var body: some View {
        NavigationLink(destination: destinationView) {
            CachedImage(
                url: imageURL,
                aspectRatio: orientation.aspectRatio
            )
            .overlay {
                if isWatched {
                    ZStack {
                        Color.black.opacity(0.5)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                    }
                } else if isInProgress, let progress = progress {
                    ZStack {
                        Color.black.opacity(0.5)

                        Text(progress.timeRemainingText)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                }
            }
            .hoverEffect(.highlight)

            if showsText {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .lineLimit(1)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    if orientation == .landscape {
                        Text(description ?? " ")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    } else if let description = description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
        .buttonStyle(.borderless)
        .buttonBorderShape(.roundedRectangle(radius: 64))
        .contextMenu {
            if let onDelete = onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("Remove from History", systemImage: "trash")
                }
            }
        }
    }
}

#Preview("Portrait") {
    MediaCard(
        imageURL: URL(string: "https://images.metahub.space/poster/medium/tt0111161/img"),
        title: "The Shawshank Redemption",
        destination: .singleMedia(itemId: "tt0111161", itemType: "movie"),
        orientation: .portrait,
        subtitle: "9.3 • 1994"
    )
}

#Preview("Landscape") {
    MediaCard(
        imageURL: URL(string: "https://images.metahub.space/background/medium/tt0944947/img"),
        title: "Winter Is Coming",
        destination: .singleMedia(itemId: "tt0944947", itemType: "series"),
        orientation: .landscape,
        subtitle: "S01E01 • Apr 17, 2011",
        description: "Eddard Stark is torn between his family and an old friend when asked to serve at the side of King Robert Baratheon."
    )
}
