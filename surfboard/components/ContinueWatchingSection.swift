//
//  ContinueWatchingSection.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-27.
//

import SwiftUI
import SwiftData
import KSPlayer

struct ContinueWatchingSection: View {
    @Query(sort: \WatchProgress.updatedAt, order: .reverse) private var watchProgress: [WatchProgress]
    @State private var selectedProgress: WatchProgress?
    
    var body: some View {
        if !watchProgress.isEmpty {
            VStack(alignment: .leading) {
                Section("Continue Watching") {
                    ScrollView(.horizontal) {
                        HStack(spacing: 40) {
                            ForEach(watchProgress) { progress in
                                Button {
                                    selectedProgress = progress
                                } label: {
                                    ContinueWatchingCard(progress: progress)
                                }
                            }
                        }
                    }
                }
            }
            .scrollClipDisabled()
            .buttonStyle(.card)
            .navigationDestination(item: $selectedProgress) { progress in
                if let streamUrl = progress.streamUrl, let url = URL(string: streamUrl) {
                    ResumeVideoPlayerView(
                        url: url,
                        progress: progress
                    )
                }
            }
        }
    }
}

/// A simplified VideoPlayerView for resuming from Continue Watching
struct ResumeVideoPlayerView: View {
    let url: URL
    let progress: WatchProgress
    
    @Environment(\.modelContext) private var modelContext
    @StateObject private var playerCoordinator = KSVideoPlayer.Coordinator()
    
    @State private var lastKnownCurrentTime: Double = 0
    @State private var lastKnownDuration: Double = 0
    @State private var progressTimer: Timer?
    
    let options: KSOptions = {
        let opt = KSOptions()
        return opt
    }()

    var body: some View {
        KSVideoPlayer(coordinator: playerCoordinator, url: url, options: options)
            .onStateChanged { playerLayer, state in
                if state == .readyToPlay {
                    startProgressTimer()
                    // Resume from saved position
                    playerLayer.seek(time: progress.currentTime, autoPlay: true) { _ in }
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
        
        guard totalDuration > 0 else { return }
        
        // If nearly finished, remove from continue watching
        let progressPercent = currentTime / totalDuration
        if progressPercent >= 0.95 {
            modelContext.delete(progress)
            try? modelContext.save()
            return
        }
        
        guard currentTime >= 10 else { return }
        
        // Update existing progress
        progress.currentTime = currentTime
        progress.totalDuration = totalDuration
        progress.updatedAt = Date()
        
        try? modelContext.save()
    }
}

#Preview {
    ContinueWatchingSection()
        .modelContainer(for: WatchProgress.self, inMemory: true)
}
