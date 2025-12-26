//
//  SourcesView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-26.
//

import SwiftUI

struct SourcesView: View {
    let item: MediaItem
    
    @State private var streams: [TorrentStream] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
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
        .navigationTitle("Sources for \(item.name)")
        .task {
            await loadStreams()
        }
    }
    
    private func loadStreams() async {
        do {
            streams = try await TorrentioService.shared.fetchStreams(
                type: item.type,
                id: item.id
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    private func handleStreamTap(_ stream: TorrentStream) {
        print("Selected stream: \(stream.displayTitle)")
        print("URL: \(stream.url ?? "N/A")")
        print("InfoHash: \(stream.infoHash ?? "N/A")")
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
    NavigationStack {
        SourcesView(item: MediaItem(id: "tt0111161", type: "movie", name: "The Shawshank Redemption", poster: nil))
    }
}
