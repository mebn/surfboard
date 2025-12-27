//
//  SourcesView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-26.
//

import SwiftUI
import SwiftData

struct SourcesView: View {
    let item: MediaItem
    let episode: Episode?
    
    init(item: MediaItem, episode: Episode? = nil) {
        self.item = item
        self.episode = episode
    }
    
    @Environment(\.modelContext) private var modelContext
    @Query private var watchProgressList: [WatchProgress]
    
    @State private var streams: [TorrentStream] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedStream: TorrentStream?
    
    /// Get existing watch progress for this item/episode
    private var existingProgress: WatchProgress? {
        let progressId: String
        if let episodeId = episode?.id {
            progressId = "\(item.id):\(episodeId)"
        } else {
            progressId = item.id
        }
        return watchProgressList.first { $0.id == progressId }
    }
    
    /// Start time from existing progress, or 0
    private var startTime: TimeInterval {
        existingProgress?.currentTime ?? 0
    }
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading sources...")
            } else if let error = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                    Text(error)
                        .foregroundColor(.secondary)
                }
            } else if streams.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "film.stack")
                        .font(.largeTitle)
                    Text("No sources available")
                        .foregroundColor(.secondary)
                }
            } else {
                List(streams) { stream in
                    Button {
                        handleStreamTap(stream)
                    } label: {
                        StreamRow(stream: stream)
                    }
                }
                .listStyle(.grouped)
            }
        }
        .navigationTitle(navigationTitle)
        .navigationDestination(item: $selectedStream) { stream in
            if let urlString = stream.url, let url = URL(string: urlString) {
                VideoPlayerView(
                    url: url,
                    title: navigationTitle,
                    startTime: startTime,
                    itemId: item.id,
                    itemType: item.type,
                    itemName: item.name,
                    itemPoster: item.poster,
                    episodeId: episode?.id,
                    episodeSeason: episode?.season,
                    episodeNumber: episode?.episodeNumber,
                    episodeName: episode?.name,
                    episodeThumbnail: episode?.thumbnail,
                    streamUrl: urlString
                )
            }
        }
        .task {
            await loadStreams()
        }
    }
    
    private var navigationTitle: String {
        if let episode = episode {
            return "\(item.name) - S\(episode.season)E\(episode.episodeNumber)"
        }
        return item.name
    }
    
    private var streamId: String {
        if let episode = episode {
            // For series episodes, use the episode ID (e.g., "tt1234567:1:1" format)
            return episode.id
        }
        return item.id
    }
    
    private func loadStreams() async {
        do {
            streams = try await TorrentioService.shared.fetchStreams(
                type: item.type,
                id: streamId
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func handleStreamTap(_ stream: TorrentStream) {
        guard stream.url != nil else { return }
        selectedStream = stream
    }
}

struct StreamRow: View {
    let stream: TorrentStream
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                if let name = stream.name {
                    Text(name)
                        .font(.headline)
                }
                
                if let title = stream.title {
                    Text(title)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            if !stream.qualityBadge.isEmpty {
                Text(stream.qualityBadge)
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(qualityColor)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var qualityColor: Color {
        switch stream.qualityBadge {
        case "4K":
            return .purple
        case "1080p":
            return .blue
        case "720p":
            return .green
        default:
            return .gray
        }
    }
}

#Preview {
    SourcesView(item: .preview())
}

