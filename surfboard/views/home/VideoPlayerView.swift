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
    let title: String
    let startTime: TimeInterval
    
    // Metadata for progress tracking
    let itemId: String
    let itemType: String
    let itemName: String
    let itemPoster: String?
    let episodeId: String?
    let episodeSeason: Int?
    let episodeNumber: Int?
    let episodeName: String?
    let episodeThumbnail: String?
    let streamUrl: String
    
    init(
        url: URL,
        title: String,
        startTime: TimeInterval = 0,
        itemId: String = "",
        itemType: String = "",
        itemName: String = "",
        itemPoster: String? = nil,
        episodeId: String? = nil,
        episodeSeason: Int? = nil,
        episodeNumber: Int? = nil,
        episodeName: String? = nil,
        episodeThumbnail: String? = nil,
        streamUrl: String = ""
    ) {
        self.url = url
        self.title = title
        self.startTime = startTime
        self.itemId = itemId
        self.itemType = itemType
        self.itemName = itemName
        self.itemPoster = itemPoster
        self.episodeId = episodeId
        self.episodeSeason = episodeSeason
        self.episodeNumber = episodeNumber
        self.episodeName = episodeName
        self.episodeThumbnail = episodeThumbnail
        self.streamUrl = streamUrl.isEmpty ? url.absoluteString : streamUrl
    }
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var coordinator = KSVideoPlayer.Coordinator()
    @State private var isMaskShow = false
    @State private var hideTask: Task<Void, Never>?
    @State private var scrubPosition: Double = 0
    @State private var isScrubbing = false
    @State private var hasSeekToStartTime = false
    @State private var progressSaveTask: Task<Void, Never>?
    @FocusState private var focusedElement: PlayerFocusElement?
    
    private let seekInterval: Int = 10
    private let progressSaveInterval: UInt64 = 10_000_000_000 // 10 seconds in nanoseconds
    
    private enum PlayerFocusElement: Hashable {
        case player
        case scrubber
    }
    
    var body: some View {
        ZStack {
            // Video player
            KSVideoPlayer(coordinator: coordinator, url: url, options: playerOptions)
                .onStateChanged { _, state in
                    if state == .readyToPlay {
                        showControlsTemporarily()
                        seekToStartTimeIfNeeded()
                        startProgressSaving()
                    }
                }
                .ignoresSafeArea()
            
            // Custom overlay
            if isMaskShow {
                CustomPlayerOverlayView(
                    coordinator: coordinator,
                    title: title,
                    scrubPosition: $scrubPosition,
                    isScrubbing: $isScrubbing,
                    isScrubberFocused: focusedElement == .scrubber,
                    onSeek: { time in
                        coordinator.seek(time: time)
                    }
                )
                .transition(.opacity)
            }
            
            // Loading indicator
            if coordinator.state == .buffering {
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
        .focusable(true)
        .focused($focusedElement, equals: .player)
        .onAppear {
            focusedElement = .player
            showControlsTemporarily()
        }
        .onDisappear {
            saveProgress()
            progressSaveTask?.cancel()
        }
        // Update scrub position from player time
        .onChange(of: coordinator.timemodel.currentTime) { _, newValue in
            if !isScrubbing {
                scrubPosition = Double(newValue)
            }
        }
        // Play/Pause: play/pause button on remote
        .onPlayPauseCommand {
            togglePlayPause()
        }
        // Handle directional presses
        .onMoveCommand { direction in
            handleMoveCommand(direction)
        }
        // Exit command to dismiss controls or go back
        .onExitCommand {
            handleExitCommand()
        }
        .animation(.easeInOut(duration: 0.3), value: isMaskShow)
        .preferredColorScheme(.dark)
        .persistentSystemOverlays(.hidden)
        .toolbar(.hidden, for: .automatic)
    }
    
    private var playerOptions: KSOptions {
        let options = KSOptions()
        KSOptions.isAutoPlay = true
        return options
    }
    
    private func seekToStartTimeIfNeeded() {
        guard !hasSeekToStartTime && startTime > 0 else { return }
        hasSeekToStartTime = true
        coordinator.seek(time: startTime)
    }
    
    private func startProgressSaving() {
        // Only save progress if we have item metadata
        guard !itemId.isEmpty else { return }
        
        progressSaveTask?.cancel()
        progressSaveTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: progressSaveInterval)
                if !Task.isCancelled {
                    await MainActor.run {
                        saveProgress()
                    }
                }
            }
        }
    }
    
    private func saveProgress() {
        guard !itemId.isEmpty else { return }
        
        let currentTime = Double(coordinator.timemodel.currentTime)
        let totalTime = Double(coordinator.timemodel.totalTime)
        
        // Don't save if we haven't really started
        guard currentTime > 5 && totalTime > 0 else { return }
        
        // Create unique ID
        let progressId: String
        if let episodeId = episodeId {
            progressId = "\(itemId):\(episodeId)"
        } else {
            progressId = itemId
        }
        
        // Check if nearly finished (within 60 seconds of end)
        let remainingTime = totalTime - currentTime
        if remainingTime < 60 {
            // Remove from continue watching if nearly finished
            let descriptor = FetchDescriptor<WatchProgress>(
                predicate: #Predicate { $0.id == progressId }
            )
            if let existing = try? modelContext.fetch(descriptor).first {
                modelContext.delete(existing)
            }
            return
        }
        
        // Find or create WatchProgress
        let descriptor = FetchDescriptor<WatchProgress>(
            predicate: #Predicate { $0.id == progressId }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            // Update existing
            existing.currentTime = currentTime
            existing.totalTime = totalTime
            existing.lastWatched = Date()
        } else {
            // Create new
            let progress = WatchProgress(
                itemId: itemId,
                itemType: itemType,
                itemName: itemName,
                itemPoster: itemPoster,
                episodeId: episodeId,
                episodeSeason: episodeSeason,
                episodeNumber: episodeNumber,
                episodeName: episodeName,
                episodeThumbnail: episodeThumbnail,
                currentTime: currentTime,
                totalTime: totalTime,
                streamUrl: streamUrl
            )
            modelContext.insert(progress)
        }
    }
    
    private func togglePlayPause() {
        if coordinator.state.isPlaying {
            coordinator.playerLayer?.pause()
        } else {
            coordinator.playerLayer?.play()
        }
        showControlsTemporarily()
    }
    
    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        switch direction {
        case .left:
            if focusedElement == .scrubber && isScrubbing {
                // Scrub backward
                let newPosition = max(0, scrubPosition - 10)
                scrubPosition = newPosition
            } else {
                // Seek backward
                coordinator.skip(interval: -seekInterval)
            }
            showControlsTemporarily()
        case .right:
            if focusedElement == .scrubber && isScrubbing {
                // Scrub forward
                let totalTime = Double(coordinator.timemodel.totalTime)
                let newPosition = min(totalTime, scrubPosition + 10)
                scrubPosition = newPosition
            } else {
                // Seek forward
                coordinator.skip(interval: seekInterval)
            }
            showControlsTemporarily()
        case .up:
            showControlsTemporarily()
        case .down:
            // When pressing down, enter scrub mode
            if isMaskShow && !isScrubbing {
                enterScrubMode()
            }
        @unknown default:
            break
        }
    }
    
    private func handleExitCommand() {
        if isScrubbing {
            // Exit scrub mode and seek to position
            exitScrubMode(seek: true)
        } else if isMaskShow {
            hideControls()
        }
    }
    
    private func enterScrubMode() {
        coordinator.playerLayer?.pause()
        isScrubbing = true
        scrubPosition = Double(coordinator.timemodel.currentTime)
        focusedElement = .scrubber
        showControls()
    }
    
    private func exitScrubMode(seek: Bool) {
        if seek {
            coordinator.seek(time: scrubPosition)
        }
        isScrubbing = false
        focusedElement = .player
        coordinator.playerLayer?.play()
        showControlsTemporarily()
    }
    
    private func showControls() {
        hideTask?.cancel()
        isMaskShow = true
    }
    
    private func hideControls() {
        hideTask?.cancel()
        isMaskShow = false
    }
    
    private func showControlsTemporarily() {
        showControls()
        
        // Don't auto-hide while scrubbing
        guard !isScrubbing else { return }
        
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            if !Task.isCancelled {
                await MainActor.run {
                    if !isScrubbing {
                        hideControls()
                    }
                }
            }
        }
    }
}

#Preview {
    VideoPlayerView(
        url: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!,
        title: "Sample Video"
    )
}

