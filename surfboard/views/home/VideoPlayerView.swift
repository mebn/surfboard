//
//  VideoPlayerView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-26.
//

import SwiftUI
import SwiftData
import KSPlayer

struct VideoPlayerView: View {
    let url: URL
    let item: MediaItem
    let episode: Episode?
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var watchProgressItems: [WatchProgress]
    @StateObject private var playerCoordinator = KSVideoPlayer.Coordinator()
    
    // Track playback state locally so we can save on disappear
    @State private var lastKnownCurrentTime: Double = 0
    @State private var lastKnownDuration: Double = 0
    @State private var progressTimer: Timer?
    
    // UI state
    @State private var showControls = true
    @State private var hideControlsTimer: Timer?
    @State private var isPlaying = false
    
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
    
    private var displayTitle: String {
        if let episode = episode {
            return "\(item.name) - S\(episode.season)E\(episode.episodeNumber)"
        }
        return item.name
    }

    var body: some View {
        ZStack {
            // Video Player
            KSVideoPlayer(coordinator: playerCoordinator, url: url, options: options)
                .onStateChanged { playerLayer, state in
                    if state == .readyToPlay {
                        startProgressTimer()
                        isPlaying = true
                        
                        // Seek to saved position if resuming
                        if let existingProgress = watchProgressItems.first(where: { $0.id == progressId }) {
                            playerLayer.seek(time: existingProgress.currentTime, autoPlay: true) { _ in }
                        }
                    }
                }
            
            // Controls Overlay - tap anywhere to toggle play/pause
            Color.clear
                .contentShape(Rectangle())
                .focusable()
                .onTapGesture {
                    togglePlayPause()
                }
            
            // Controls UI
            if showControls {
                controlsOverlay
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            startProgressTimer()
            resetHideControlsTimer()
        }
        .onDisappear {
            stopProgressTimer()
            saveProgress()
            hideControlsTimer?.invalidate()
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
        .onPlayPauseCommand {
            togglePlayPause()
        }
        .onMoveCommand { direction in
            showControlsTemporarily()
            switch direction {
            case .left:
                skipBackward()
            case .right:
                skipForward()
            default:
                break
            }
        }
        .onExitCommand {
            dismiss()
        }
    }
    
    // MARK: - Controls Overlay
    
    private var controlsOverlay: some View {
        VStack {
            Spacer()
            
            // Bottom controls
            VStack(spacing: 20) {
                // Title
                HStack {
                    Text(displayTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    Spacer()
                }
                
                // Seek bar
                VStack(spacing: 8) {
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background track
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.3))
                                .frame(height: 8)
                            
                            // Progress
                            if lastKnownDuration > 0 {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white)
                                    .frame(width: geometry.size.width * CGFloat(lastKnownCurrentTime / lastKnownDuration), height: 8)
                            }
                            
                            // Seek indicator (knob)
                            if lastKnownDuration > 0 {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 20, height: 20)
                                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                    .offset(x: (geometry.size.width - 20) * CGFloat(lastKnownCurrentTime / lastKnownDuration))
                            }
                        }
                    }
                    .frame(height: 20)
                    
                    // Time labels
                    HStack {
                        Text(formatTime(lastKnownCurrentTime))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .monospacedDigit()
                        
                        Spacer()
                        
                        Text("-\(formatTime(max(0, lastKnownDuration - lastKnownCurrentTime)))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .monospacedDigit()
                    }
                }
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 60)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.clear, .clear, .black.opacity(0.7)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    // MARK: - Playback Controls
    
    private func togglePlayPause() {
        guard let playerLayer = playerCoordinator.playerLayer else { return }
        
        if isPlaying {
            playerLayer.pause()
        } else {
            playerLayer.play()
        }
        isPlaying.toggle()
        showControlsTemporarily()
    }
    
    private func skipForward() {
        guard let playerLayer = playerCoordinator.playerLayer else { return }
        let newTime = min(lastKnownCurrentTime + 10, lastKnownDuration)
        playerLayer.seek(time: newTime, autoPlay: isPlaying) { _ in }
        lastKnownCurrentTime = newTime
    }
    
    private func skipBackward() {
        guard let playerLayer = playerCoordinator.playerLayer else { return }
        let newTime = max(lastKnownCurrentTime - 10, 0)
        playerLayer.seek(time: newTime, autoPlay: isPlaying) { _ in }
        lastKnownCurrentTime = newTime
    }
    
    // MARK: - UI Helpers
    
    private func showControlsTemporarily() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showControls = true
        }
        resetHideControlsTimer()
    }
    
    private func resetHideControlsTimer() {
        hideControlsTimer?.invalidate()
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            Task { @MainActor in
                if isPlaying {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showControls = false
                    }
                }
            }
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
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
