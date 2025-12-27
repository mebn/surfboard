//
//  VideoPlayerView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-26.
//

import SwiftUI
import KSPlayer

struct VideoPlayerView: View {
    let url: URL
    let title: String
    
    @StateObject private var coordinator = KSVideoPlayer.Coordinator()
    @State private var isMaskShow = false
    @State private var hideTask: Task<Void, Never>?
    @State private var scrubPosition: Double = 0
    @State private var isScrubbing = false
    @FocusState private var focusedElement: PlayerFocusElement?
    
    private let seekInterval: Int = 10
    
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
