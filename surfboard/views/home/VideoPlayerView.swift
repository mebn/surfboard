//
//  VideoPlayerView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-26.
//

import AVFoundation
import KSPlayer
import SwiftData
import SwiftUI

struct VideoPlayerView: View {
    let url: URL
    let mediaItem: MediaItem
    let episode: Episode?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var allRecords: [MediaRecord]
    @Query private var settingsArray: [AppSettings]
    @StateObject private var playerCoordinator = KSVideoPlayer.Coordinator()

    @State private var lastKnownCurrentTime: Double = 0
    @State private var lastKnownDuration: Double = 0
    @State private var progressTimer: Timer?
    @State private var hideControlsTimer: Timer?

    @State private var controlsOpacity: Double = 1.0
    @State private var isPlaying = false
    @State private var isLoading = true
    @State private var currentSpeed: Float = 1.0

    @State private var isSeeking = false
    @State private var seekPosition: Double = 0

    // Cached tracks to prevent picker flashing
    @State private var audioTracks: [MediaPlayerTrack] = []
    @State private var subtitleTracks: [MediaPlayerTrack] = []
    @State private var selectedAudioTrackId: Int32?
    @State private var selectedSubtitleTrackId: Int32?
    @State private var hasAppliedDefaults = false

    enum FocusableElement: Hashable { case seekbar, audioButton, subtitleButton, speedButton }
    @FocusState private var focusedElement: FocusableElement?

    private let speedOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    private let options = KSOptions()

    /// Get the MediaRecord for this media
    private var record: MediaRecord? {
        allRecords.first { $0.id == mediaItem.id }
    }

    /// Get app settings
    private var settings: AppSettings? {
        settingsArray.first
    }

    /// Initializer for playback - from SourcesView or ContinueWatching
    init(url: URL, mediaItem: MediaItem, episode: Episode? = nil) {
        self.url = url
        self.mediaItem = mediaItem
        self.episode = episode
    }

    private var displayName: String {
        if let episode = episode {
            return "\(mediaItem.name) - S\(episode.season) E\(episode.episodeNumber)"
        }
        return mediaItem.name
    }

    private var displayTime: Double {
        isSeeking ? seekPosition : lastKnownCurrentTime
    }

    private var player: (any MediaPlayerProtocol)? {
        playerCoordinator.playerLayer?.player
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            KSVideoPlayer(coordinator: playerCoordinator, url: url, options: options)
                .onStateChanged { playerLayer, state in
                    handlePlayerState(state, playerLayer: playerLayer)
                }

            if isLoading {
                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
            }

            if !isPlaying && !isLoading {
                Image(systemName: "pause.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 10)
            }

            controlsOverlay.opacity(controlsOpacity)
        }
        .onAppear {
            startProgressTimer()
            showControls(hideAfter: 1.0)
            focusedElement = .seekbar
        }
        .onDisappear {
            stopTimers()
            saveProgress()
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
        .onPlayPauseCommand { togglePlayPause() }
        .onExitCommand { dismiss() }
    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        VStack {
            // Title at top left
            HStack {
                Text(displayName)
                    .font(.title3)
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)
                Spacer()
            }
            .padding(.horizontal, 80)
            .padding(.top, 60)

            Spacer()

            // Bottom controls
            VStack(spacing: 20) {
                seekbarView
                HStack(spacing: 16) {
                    audioMenuButton
                    subtitleMenuButton
                    speedMenuButton
                    Spacer()
                }
            }
            .padding(.horizontal, 80)
            .padding(.bottom, 60)
        }
        .background(
            LinearGradient(colors: [.black.opacity(0.7), .clear, .clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
        )
    }

    private var seekbarView: some View {
        VStack(spacing: 8) {
            HStack {
                timeLabel(displayTime)
                Spacer()
                timeLabel(max(0, lastKnownDuration - displayTime), prefix: "-")
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    progressBar(color: .white.opacity(0.3), width: geo.size.width)
                    if lastKnownDuration > 0 {
                        progressBar(color: .white, width: geo.size.width * (displayTime / lastKnownDuration))
                    }
                }
            }
            .frame(height: 16)
            .focusable(true) { if $0 { focusedElement = .seekbar } }
            .focused($focusedElement, equals: .seekbar)
            .onMoveCommand { handleSeekbarMove($0) }
        }
    }

    private func progressBar(color: Color, width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .frame(width: width, height: 16)
    }

    private func timeLabel(_ seconds: Double, prefix: String = "") -> some View {
        Text("\(prefix)\(formatTime(seconds))")
            .font(.callout)
            .foregroundColor(.white.opacity(0.8))
            .monospacedDigit()
    }

    // MARK: - Menu Buttons

    private var audioMenuButton: some View {
        Menu {
            ForEach(audioTracks, id: \.trackID) { track in
                Button {
                    selectAudioTrack(track)
                } label: {
                    HStack {
                        Text(track.name)
                        if selectedAudioTrackId == track.trackID { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            menuButtonLabel(icon: "speaker.wave.2.fill", focus: .audioButton)
        }
        .menuStyle(.borderlessButton)
        .focused($focusedElement, equals: .audioButton)
        .onMoveCommand { if $0 == .up { focusedElement = .seekbar }; showControls(hideAfter: 5.0) }
    }

    private var subtitleMenuButton: some View {
        Menu {
            Button {
                disableSubtitles()
            } label: {
                HStack {
                    Text("Off")
                    if selectedSubtitleTrackId == nil { Image(systemName: "checkmark") }
                }
            }

            ForEach(subtitleTracks, id: \.trackID) { track in
                Button {
                    selectSubtitleTrack(track)
                } label: {
                    HStack {
                        Text(track.name)
                        if selectedSubtitleTrackId == track.trackID { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            menuButtonLabel(icon: "captions.bubble.fill", focus: .subtitleButton)
        }
        .menuStyle(.borderlessButton)
        .focused($focusedElement, equals: .subtitleButton)
        .onMoveCommand { if $0 == .up { focusedElement = .seekbar }; showControls(hideAfter: 5.0) }
    }

    private var speedMenuButton: some View {
        Menu {
            ForEach(speedOptions, id: \.self) { speed in
                Button {
                    setPlaybackSpeed(speed)
                } label: {
                    HStack {
                        Text(speedLabel(speed))
                        if currentSpeed == speed { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            menuButtonLabel(icon: "speedometer", focus: .speedButton)
        }
        .menuStyle(.borderlessButton)
        .focused($focusedElement, equals: .speedButton)
        .onMoveCommand { if $0 == .up { focusedElement = .seekbar }; showControls(hideAfter: 5.0) }
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

    // MARK: - Track Selection

    private func selectAudioTrack(_ track: MediaPlayerTrack) {
        player?.select(track: track)
        selectedAudioTrackId = track.trackID
    }

    private func selectSubtitleTrack(_ track: MediaPlayerTrack) {
        player?.select(track: track)
        selectedSubtitleTrackId = track.trackID
    }

    private func disableSubtitles() {
        if let player = player {
            for track in subtitleTracks where track.isEnabled {
                player.select(track: track) // Toggle off
            }
        }
        selectedSubtitleTrackId = nil
    }

    private func updateCachedTracks() {
        guard let player = player else { return }

        let newAudioTracks = player.tracks(mediaType: .audio)
        let newSubtitleTracks = player.tracks(mediaType: .subtitle)

        // Only update if tracks have changed
        if audioTracks.map({ $0.trackID }) != newAudioTracks.map({ $0.trackID }) {
            audioTracks = newAudioTracks
            // Update selected audio track
            if let enabledTrack = newAudioTracks.first(where: { $0.isEnabled }) {
                selectedAudioTrackId = enabledTrack.trackID
            }
        }

        if subtitleTracks.map({ $0.trackID }) != newSubtitleTracks.map({ $0.trackID }) {
            subtitleTracks = newSubtitleTracks
            // Update selected subtitle track
            if let enabledTrack = newSubtitleTracks.first(where: { $0.isEnabled }) {
                selectedSubtitleTrackId = enabledTrack.trackID
            } else {
                selectedSubtitleTrackId = nil
            }
        }
    }

    private func applyDefaultSettings() {
        guard !hasAppliedDefaults, let player = player else { return }

        let currentAudioTracks = player.tracks(mediaType: .audio)
        let currentSubtitleTracks = player.tracks(mediaType: .subtitle)

        guard !currentAudioTracks.isEmpty else { return }

        hasAppliedDefaults = true

        // Apply default playback speed from settings
        let preferredSpeed = settings?.preferredPlaybackSpeed ?? 1.0
        setPlaybackSpeed(preferredSpeed)

        // Apply preferred audio language
        if let preferredAudioLang = settings?.preferredAudioLanguage {
            if let matchingTrack = currentAudioTracks.first(where: { trackMatchesLanguage($0, language: preferredAudioLang) }) {
                selectAudioTrack(matchingTrack)
            }
        }

        // Apply preferred subtitle language
        if let preferredSubtitleLang = settings?.preferredSubtitleLanguage {
            if preferredSubtitleLang == "none" {
                disableSubtitles()
            } else if let matchingTrack = currentSubtitleTracks.first(where: { trackMatchesLanguage($0, language: preferredSubtitleLang) }) {
                selectSubtitleTrack(matchingTrack)
            }
        }
    }

    private func trackMatchesLanguage(_ track: MediaPlayerTrack, language: String) -> Bool {
        let trackName = track.name.lowercased()
        let trackLang = track.language?.lowercased() ?? ""
        let langCode = language.lowercased()

        // Check language code match
        if trackLang == langCode || trackLang.hasPrefix(langCode) {
            return true
        }

        // Check language name match
        if let langName = LanguageOption.audioLanguages.first(where: { $0.id == langCode })?.name.lowercased() {
            if trackName.contains(langName) || trackLang.contains(langName) {
                return true
            }
        }

        return false
    }

    // MARK: - Player State

    private func handlePlayerState(_ state: KSPlayerState, playerLayer: KSPlayerLayer) {
        switch state {
        case .readyToPlay:
            isLoading = false
            isPlaying = true
            startProgressTimer()
            showControls(hideAfter: 1.0)

            // Update cached tracks and apply defaults
            updateCachedTracks()
            applyDefaultSettings()

            // Resume from saved position if available
            if let existingRecord = record,
               let progress = existingRecord.progressForEpisode(episodeId: episode?.id),
               !progress.isCompleted
            {
                playerLayer.seek(time: progress.currentTime, autoPlay: true) { _ in }
            }
        case .buffering:
            isLoading = true
        case .bufferFinished:
            isLoading = false
            // Update tracks when buffer finishes as more may be available
            updateCachedTracks()
        case .paused where isPlaying:
            isPlaying = false
            showControls(persistent: true)
        case .playedToTheEnd:
            isPlaying = false
        default:
            break
        }
    }

    // MARK: - Playback Controls

    private func togglePlayPause() {
        guard let playerLayer = playerCoordinator.playerLayer else { return }
        if isPlaying {
            playerLayer.pause()
            isPlaying = false
            showControls(persistent: true)
        } else {
            playerLayer.play()
            isPlaying = true
            showControls(hideAfter: 1.0)
        }
    }

    private func skip(seconds: Double) {
        guard let playerLayer = playerCoordinator.playerLayer else { return }
        let newTime = max(0, min(lastKnownCurrentTime + seconds, lastKnownDuration))
        playerLayer.seek(time: newTime, autoPlay: isPlaying) { _ in }
        lastKnownCurrentTime = newTime
    }

    private func handleSeekbarMove(_ direction: MoveCommandDirection) {
        guard focusedElement == .seekbar else { return }
        showControls(hideAfter: 1.0)
        switch direction {
        case .left: skip(seconds: -10)
        case .right: skip(seconds: 10)
        case .down: focusedElement = .audioButton
        default: break
        }
    }

    private func setPlaybackSpeed(_ speed: Float) {
        player?.playbackRate = speed
        currentSpeed = speed
    }

    private func speedLabel(_ speed: Float) -> String {
        speed == 1.0 ? "Normal" : "\(String(format: "%.2g", speed))x"
    }

    // MARK: - Controls Visibility

    private func showControls(hideAfter: TimeInterval? = nil, persistent: Bool = false) {
        hideControlsTimer?.invalidate()
        withAnimation(.easeInOut(duration: 0.3)) { controlsOpacity = 1.0 }

        guard !persistent, let delay = hideAfter else { return }
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            Task { @MainActor in
                guard isPlaying else { return }
                withAnimation(.easeInOut(duration: 0.5)) { controlsOpacity = 0.0 }
                focusedElement = .seekbar
            }
        }
    }

    // MARK: - Timers

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in
                guard let playerLayer = playerCoordinator.playerLayer else { return }
                lastKnownCurrentTime = playerLayer.player.currentPlaybackTime
                lastKnownDuration = playerLayer.player.duration
            }
        }
    }

    private func stopTimers() {
        progressTimer?.invalidate()
        progressTimer = nil
        hideControlsTimer?.invalidate()
        hideControlsTimer = nil
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    // MARK: - Progress Saving

    private func saveProgress() {
        guard lastKnownDuration > 0, lastKnownCurrentTime >= 10 else { return }

        let progress = lastKnownCurrentTime / lastKnownDuration

        // Get or create MediaRecord
        let mediaRecord: MediaRecord
        if let existing = record {
            mediaRecord = existing
        } else {
            mediaRecord = MediaRecord(id: mediaItem.id, type: mediaItem.type)
            modelContext.insert(mediaRecord)
        }

        // If nearly finished (>= 90%), mark as completed but keep in history
        // The episode will show as "watched" with a checkmark
        if progress >= 0.9 {
            // Save with full duration to mark as completed
            mediaRecord.updateProgress(
                episodeId: episode?.id,
                season: episode?.season,
                episode: episode?.episodeNumber,
                currentTime: lastKnownDuration,
                totalDuration: lastKnownDuration,
                streamUrl: url.absoluteString
            )
        } else {
            // Save current progress for continue watching
            mediaRecord.updateProgress(
                episodeId: episode?.id,
                season: episode?.season,
                episode: episode?.episodeNumber,
                currentTime: lastKnownCurrentTime,
                totalDuration: lastKnownDuration,
                streamUrl: url.absoluteString
            )
        }

        try? modelContext.save()
    }
}
