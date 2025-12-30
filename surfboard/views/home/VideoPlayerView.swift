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
    @State private var controlsOpacity: Double = 1.0
    @State private var hideControlsTimer: Timer?
    @State private var isPlaying = false
    @State private var isLoading = true
    
    // Selection state
    @State private var selectedAudioIndex: Int = 0
    @State private var selectedSubtitleIndex: Int = -1 // -1 means off
    @State private var currentSpeed: Float = 1.0
    @State private var isMenuOpen = false
    
    // Focus management
    enum FocusableElement: Hashable {
        case seekbar
        case audioButton
        case subtitleButton
        case speedButton
    }
    @FocusState private var focusedElement: FocusableElement?
    
    // Seeking state (for scrubbing when paused)
    @State private var isSeeking = false
    @State private var seekPosition: Double = 0
    
    private let speedOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    
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
            // Black background for letterboxing
            Color.black
                .ignoresSafeArea()
            
            // Video Player
            KSVideoPlayer(coordinator: playerCoordinator, url: url, options: options)
                .onStateChanged { playerLayer, state in
                    switch state {
                    case .readyToPlay:
                        isLoading = false
                        startProgressTimer()
                        isPlaying = true
                        showControlsTemporarily()
                        
                        // Seek to saved position if resuming
                        if let existingProgress = watchProgressItems.first(where: { $0.id == progressId }) {
                            playerLayer.seek(time: existingProgress.currentTime, autoPlay: true) { _ in }
                        }
                    case .buffering:
                        isLoading = true
                    case .bufferFinished:
                        isLoading = false
                    case .paused:
                        // Sync UI state when player pauses (e.g., from remote button)
                        if isPlaying {
                            isPlaying = false
                            showControlsPersistent()
                        }
                    case .playedToTheEnd:
                        isPlaying = false
                    default:
                        break
                    }
                }
            
            // Loading spinner
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            }
            
            // Centered pause icon when paused
            if !isPlaying && !isLoading {
                Image(systemName: "pause.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 0)
            }
            
            // Controls UI with fade animation
            controlsOverlay
                .opacity(controlsOpacity)
        }
        .onAppear {
            startProgressTimer()
            resetHideControlsTimer()
            focusedElement = .seekbar
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
        .onExitCommand {
            dismiss()
        }
    }

    
    private func speedLabel(for speed: Float) -> String {
        if speed == 1.0 {
            return "Normal"
        } else {
            return "\(String(format: "%.2g", speed))x"
        }
    }
    
    private func setPlaybackSpeed(_ speed: Float) {
        guard let playerLayer = playerCoordinator.playerLayer else { return }
        playerLayer.player.playbackRate = speed
        currentSpeed = speed
    }
    
    private var controlsOverlay: some View {
        VStack {
            Spacer()
            
            // Bottom controls
            VStack(spacing: 20) {
                // Title and control buttons row
                HStack(alignment: .bottom) {
                    Text(displayTitle)
                        .font(.title3)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                    
                    Spacer()
                    
                    // Control buttons (Audio, Subtitles, Speed)
                    HStack(spacing: 16) {
                        audioMenuButton
                        subtitleMenuButton
                        speedMenuButton
                    }
                }
                
                // Seek bar
                seekbarView
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
    
    private var seekbarView: some View {
        VStack(spacing: 8) {
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 16)
                    
                    // Buffer indicator (shown slightly ahead of current position)
                    if lastKnownDuration > 0 {
                        let displayTime = isSeeking ? seekPosition : lastKnownCurrentTime
                        // Buffer is typically ahead of playback - using playerCoordinator to get buffer if available
                        let bufferProgress = min(1.0, (displayTime / lastKnownDuration) + 0.1)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.5))
                            .frame(width: geometry.size.width * CGFloat(bufferProgress), height: 16)
                    }
                    
                    // Progress
                    if lastKnownDuration > 0 {
                        let displayTime = isSeeking ? seekPosition : lastKnownCurrentTime
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .frame(width: geometry.size.width * CGFloat(displayTime / lastKnownDuration), height: 16)
                    }
                }
            }
            .frame(height: 16)
            .focusable(true) { isFocused in
                if isFocused {
                    focusedElement = .seekbar
                }
            }
            .focused($focusedElement, equals: .seekbar)
            .onMoveCommand { direction in
                if focusedElement == .seekbar {
                    showControlsTemporarily()
                    switch direction {
                    case .left:
                        skipBackward()
                    case .right:
                        skipForward()
                    case .up:
                        // Move focus to buttons
                        focusedElement = .audioButton
                    default:
                        break
                    }
                }
            }
            
            // Time labels
            HStack {
                let displayTime = isSeeking ? seekPosition : lastKnownCurrentTime
                Text(formatTime(displayTime))
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.8))
                    .monospacedDigit()
                
                Spacer()
                
                Text("-\(formatTime(max(0, lastKnownDuration - displayTime)))")
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.8))
                    .monospacedDigit()
            }
        }
    }
    
    // MARK: - Menu Buttons
    
    private var audioMenuButton: some View {
        Menu {
            if let player = playerCoordinator.playerLayer?.player {
                let tracks = player.tracks(mediaType: .audio)
                ForEach(tracks.indices, id: \.self) { index in
                    let track = tracks[index]
                    Button {
                        player.select(track: track)
                        selectedAudioIndex = index
                    } label: {
                        HStack {
                            Text(track.name)
                            if track.isEnabled {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            menuButtonLabel(icon: "speaker.wave.2.fill", focus: .audioButton)
        }
        .menuStyle(.borderlessButton)
        .focused($focusedElement, equals: .audioButton)
        .onMoveCommand { direction in
            showControlsTemporarilyLong()
            if direction == .down {
                focusedElement = .seekbar
            }
        }
    }
    
    private var subtitleMenuButton: some View {
        Menu {
            Button {
                if let player = playerCoordinator.playerLayer?.player {
                    let tracks = player.tracks(mediaType: .subtitle)
                    for track in tracks {
                        if track.isEnabled {
                            player.select(track: track)
                        }
                    }
                }
                selectedSubtitleIndex = -1
            } label: {
                HStack {
                    Text("Off")
                    if selectedSubtitleIndex == -1 {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            if let player = playerCoordinator.playerLayer?.player {
                let tracks = player.tracks(mediaType: .subtitle)
                ForEach(tracks.indices, id: \.self) { index in
                    let track = tracks[index]
                    Button {
                        player.select(track: track)
                        selectedSubtitleIndex = index
                    } label: {
                        HStack {
                            Text(track.name)
                            if track.isEnabled {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            menuButtonLabel(icon: "captions.bubble.fill", focus: .subtitleButton)
        }
        .menuStyle(.borderlessButton)
        .focused($focusedElement, equals: .subtitleButton)
        .onMoveCommand { direction in
            showControlsTemporarilyLong()
            if direction == .down {
                focusedElement = .seekbar
            }
        }
    }
    
    private var speedMenuButton: some View {
        Picker(selection: Binding(
            get: { currentSpeed },
            set: { newSpeed in
                setPlaybackSpeed(newSpeed)
            }
        )) {
            ForEach(speedOptions, id: \.self) { speed in
                Text(speedLabel(for: speed)).tag(speed)
            }
        } label: {
            menuButtonLabel(icon: "speedometer", focus: .speedButton)
        }
        .pickerStyle(.menu)
        .focused($focusedElement, equals: .speedButton)
        .onMoveCommand { direction in
            showControlsTemporarilyLong()
            if direction == .down {
                focusedElement = .seekbar
            }
        }
    }
    
    private func menuButtonLabel(icon: String, focus: FocusableElement) -> some View {
        ZStack {
            Circle()
                .fill(focusedElement == focus ? Color.white.opacity(0.4) : Color.white.opacity(0.2))
                .frame(width: 64, height: 64)
            
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(.white)
        }
    }
    

    
    private func togglePlayPause() {
        guard let playerLayer = playerCoordinator.playerLayer else { return }
        
        if isPlaying {
            playerLayer.pause()
            isPlaying = false
            // Show controls and keep them visible when paused
            showControlsPersistent()
        } else {
            playerLayer.play()
            isPlaying = true
            // Start the hide timer when playing
            showControlsTemporarily()
        }
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
    
    private func showControlsPersistent() {
        // Show controls and cancel any hide timer
        hideControlsTimer?.invalidate()
        hideControlsTimer = nil
        withAnimation(.easeInOut(duration: 0.3)) {
            controlsOpacity = 1.0
        }
    }
    
    private func showControlsTemporarily() {
        withAnimation(.easeInOut(duration: 0.3)) {
            controlsOpacity = 1.0
        }
        resetHideControlsTimer()
    }
    
    private func showControlsTemporarilyLong() {
        withAnimation(.easeInOut(duration: 0.3)) {
            controlsOpacity = 1.0
        }
        resetHideControlsTimerLong()
    }
    
    private func resetHideControlsTimerLong() {
        hideControlsTimer?.invalidate()
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { _ in
            Task { @MainActor in
                // Only hide if playing
                if isPlaying {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        controlsOpacity = 0.0
                    }
                    // Reset focus to seekbar so hard press works for play/pause
                    focusedElement = .seekbar
                }
            }
        }
    }
    
    private func resetHideControlsTimer() {
        hideControlsTimer?.invalidate()
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            Task { @MainActor in
                // Only hide if playing
                if isPlaying {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        controlsOpacity = 0.0
                    }
                    // Reset focus to seekbar so hard press works for play/pause
                    focusedElement = .seekbar
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
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
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
