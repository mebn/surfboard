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

    @StateObject private var addonManager = AddonManager.shared
    @State private var streams: [StremioStream] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedStream: StremioStream?
    
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
        .navigationDestination(item: $selectedStream) { stream in
            if let urlString = stream.url, let url = URL(string: urlString) {
                VideoPlayerView(url: url, mediaItem: item, episode: episode)
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
        // Ensure addons are loaded
        if !addonManager.isLoaded {
            await addonManager.loadAddons()
        }
        
        do {
            streams = try await addonManager.fetchStreams(
                type: item.type,
                id: streamId
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func handleStreamTap(_ stream: StremioStream) {
        guard stream.url != nil else { return }
        selectedStream = stream
    }
}

struct StreamRow: View {
    let stream: StremioStream
    
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
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    SourcesView(item: .preview())
}
