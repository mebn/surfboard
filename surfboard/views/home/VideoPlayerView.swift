//
//  VideoPlayerView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-26.
//

import SwiftUI
import SwiftData
import KSPlayer
import Combine // ?

struct VideoPlayerView: View {
    let url: URL
    let item: MediaItem
    let episode: Episode?
    
    @Environment(\.modelContext) private var modelContext
    @Query private var watchProgressItems: [WatchProgress]
    @StateObject private var playerCoordinator = KSVideoPlayer.Coordinator()
    
    // Track playback state locally so we can save on disappear
    @State private var lastKnownCurrentTime: Double = 0
    @State private var lastKnownDuration: Double = 0
    @State private var progressTimer: Timer?
    
    let options: KSOptions = {
        let opt = KSOptions()
        return opt
    }()
    
    init(url: URL, item: MediaItem, episode: Episode? = nil) {
        self.url = url
        self.item = item
        self.episode = episode
    }
    
    private var progressId: String {
        if let episode = episode {
            return "\(item.id):\(episode.season):\(episode.episodeNumber)"
        }
        return item.id
    }

    var body: some View {
        KSVideoPlayer(coordinator: playerCoordinator, url: url, options: options)
            .onStateChanged { playerLayer, state in
                if state == .readyToPlay {
                    // Start timer to track progress
                    startProgressTimer()
                    
                    // Seek to saved position if resuming
                    if let existingProgress = watchProgressItems.first(where: { $0.id == progressId }) {
                        playerLayer.seek(time: existingProgress.currentTime, autoPlay: true) { _ in }
                    }
                }
            }
            .onAppear {
                startProgressTimer()
            }
            .onDisappear {
                stopProgressTimer()
                saveProgress()
            }
            .ignoresSafeArea()
            .toolbar(.hidden, for: .tabBar)
    }
    
    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in
                updateProgress()
            }
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func updateProgress() {
        guard let playerLayer = playerCoordinator.playerLayer else { return }
        lastKnownCurrentTime = playerLayer.player.currentPlaybackTime
        lastKnownDuration = playerLayer.player.duration
    }
    
    private func saveProgress() {
        let currentTime = lastKnownCurrentTime
        let totalDuration = lastKnownDuration
        
        print("Saving progress: \(currentTime)/\(totalDuration)")
        
        // Don't save if duration is 0
        guard totalDuration > 0 else {
            print("Duration is 0, not saving")
            return
        }
        
        // If nearly finished (95%+), remove from continue watching
        let progress = currentTime / totalDuration
        if progress >= 0.95 {
            if let existingProgress = watchProgressItems.first(where: { $0.id == progressId }) {
                modelContext.delete(existingProgress)
                try? modelContext.save()
                print("Removed completed item")
            }
            return
        }
        
        // Don't save if less than 10 seconds watched
        guard currentTime >= 10 else {
            print("Less than 10 seconds watched, not saving")
            return
        }
        
        if let existingProgress = watchProgressItems.first(where: { $0.id == progressId }) {
            // Update existing progress
            existingProgress.currentTime = currentTime
            existingProgress.totalDuration = totalDuration
            existingProgress.updatedAt = Date()
            existingProgress.streamUrl = url.absoluteString
            print("Updated existing progress")
        } else {
            // Create new progress entry
            let newProgress: WatchProgress
            if let episode = episode {
                newProgress = WatchProgress(from: item, episode: episode, currentTime: currentTime, totalDuration: totalDuration, streamUrl: url.absoluteString)
            } else {
                newProgress = WatchProgress(from: item, currentTime: currentTime, totalDuration: totalDuration, streamUrl: url.absoluteString)
            }
            modelContext.insert(newProgress)
            print("Created new progress entry for: \(newProgress.title)")
        }
        
        do {
            try modelContext.save()
            print("Model context saved successfully")
        } catch {
            print("Failed to save model context: \(error)")
        }
    }
}

#Preview {
    VideoPlayerView(
        url: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!,
        item: .preview()
    )
}
