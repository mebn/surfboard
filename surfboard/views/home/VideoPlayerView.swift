//
//  VideoPlayerView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-26.
//

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

    @State private var progressTimer: Timer?
    @State private var hideControlsTimer: Timer?
    @State private var controlsOpacity: Double = 1.0
    @State private var isPlaying = false
    @State private var isLoading = true
    @State private var currentSpeed: Float = 1.0
    @State private var audioTracks: [MediaPlayerTrack] = []
    @State private var subtitleTracks: [MediaPlayerTrack] = []
    @State private var selectedAudioTrackId: Int32?
    @State private var selectedSubtitleTrackId: Int32?
    @State private var hasAppliedDefaults = false
    @State private var isMenuOpen = false

    @State private var selectedAudio: Int?
    @State private var selectedSubtitle: Int?
    @State private var selectedPlaybackSpeed: Int?

    enum FocusableElement: Hashable { case seekbar, audioButton, subtitleButton, speedButton }
    @FocusState private var focusedElement: FocusableElement?

    private let speedOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    private var record: MediaRecord? { allRecords.first { $0.id == mediaItem.id } }
    private var settings: AppSettings? { settingsArray.first }
    private var player: (any MediaPlayerProtocol)? { playerCoordinator.playerLayer?.player }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            KSVideoPlayer(coordinator: playerCoordinator, url: url, options: KSOptions())
                .onStateChanged {
                    handlePlayerState($1, playerLayer: $0)
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

            controlsOverlay
                .opacity(controlsOpacity)
        }
        .onDisappear {
            stopTimers()
            saveProgress()
        }
        .onChange(of: focusedElement) { _, focus in
            if focus == .seekbar {
                showControls(hideAfter: 1.0)
            } else {
                showControls(hideAfter: 5.0)
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
        .onPlayPauseCommand { togglePlayPause() }
        .onExitCommand { dismiss() }
    }

    // MARK: - Controls Overlay

    private var controlsOverlay: some View {
        VStack {
            HStack {
                VStack(alignment: .leading, spacing: 12) {
                    Text(mediaItem.name)
                        .font(.title3)
                        .foregroundColor(.white)

                    if let ep = episode {
                        Text(String(format: "S%02dE%02d", ep.season, ep.episodeNumber))
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 80)
            .padding(.top, 60)

            Spacer()

            VStack(spacing: 20) {
                seekbarView

                HStack(spacing: 16) {
                    // audio
                    Menu {
                        if audioTracks.isEmpty {
                            Text("No tracks available")
                        } else {
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
                        }
                    } label: {
                        menuButtonLabel(icon: "speaker.wave.2.fill", focus: .audioButton)
                    }
                    .menuStyle(.borderlessButton)
                    .focused($focusedElement, equals: .audioButton)

                    // subtitle
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

                    // playback speed
                    Menu {
                        ForEach(speedOptions, id: \.self) { speed in
                            Button {
                                setPlaybackSpeed(speed)
                            } label: {
                                HStack {
                                    Text(String(format: "%.2fx", speed)).tag(speed)
                                    if currentSpeed == speed { Image(systemName: "checkmark") }
                                }
                            }
                        }
                    } label: {
                        menuButtonLabel(icon: "speedometer", focus: .speedButton)
                    }
                    .menuStyle(.borderlessButton)
                    .focused($focusedElement, equals: .speedButton)

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
        let currentTime = playerCoordinator.playerLayer?.player.currentPlaybackTime ?? 0
        let duration = playerCoordinator.playerLayer?.player.duration ?? 0

        return (
            VStack(spacing: 8) {
                HStack {
                    Text(formatTime(currentTime)).font(.callout).foregroundColor(.white.opacity(0.8)).monospacedDigit()
                    Spacer()
                    Text("-\(formatTime(max(0, duration - currentTime)))").font(.callout).foregroundColor(.white.opacity(0.8)).monospacedDigit()
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8).fill(.white.opacity(0.3)).frame(height: 16)
                        if duration > 0 {
                            RoundedRectangle(cornerRadius: 8).fill(.white).frame(width: geo.size.width * (currentTime / duration), height: 16)
                        }
                    }
                }
                .frame(height: 16)
                .focusable()
                .focused($focusedElement, equals: .seekbar)
                .onMoveCommand { handleSeekbarMove($0) }
            }
        )
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
        subtitleTracks.filter(\.isEnabled).forEach { player?.select(track: $0) }
        selectedSubtitleTrackId = nil
    }

    private func loadTracks() {
        guard let player = player else { return }
        audioTracks = player.tracks(mediaType: .audio)
        subtitleTracks = player.tracks(mediaType: .subtitle)
    }

    private func applyDefaultSettings() {
        guard !hasAppliedDefaults, let player = player else { return }
        let audio = player.tracks(mediaType: .audio)
        guard !audio.isEmpty else { return }
        hasAppliedDefaults = true

        setPlaybackSpeed(settings?.preferredPlaybackSpeed ?? 1.0)

        if let lang = settings?.preferredAudioLanguage,
           let track = audio.first(where: { trackMatchesLanguage($0, language: lang) })
        {
            selectAudioTrack(track)
        }
        if let lang = settings?.preferredSubtitleLanguage {
            if lang == "none" {
                disableSubtitles()
            } else if let track = player.tracks(mediaType: .subtitle).first(where: { trackMatchesLanguage($0, language: lang) }) {
                selectSubtitleTrack(track)
            }
        }
    }

    private func trackMatchesLanguage(_ track: MediaPlayerTrack, language: String) -> Bool {
        let name = track.name.lowercased()
        let lang = track.language?.lowercased() ?? ""
        let code = language.lowercased()
        if lang == code || lang.hasPrefix(code) { return true }
        if let langName = LanguageOption.audioLanguages.first(where: { $0.id == code })?.name.lowercased(),
           name.contains(langName) || lang.contains(langName) { return true }
        return false
    }

    // MARK: - Player State

    private func handlePlayerState(_ state: KSPlayerState, playerLayer: KSPlayerLayer) {
        switch state {
        case .readyToPlay:
            isLoading = false
            isPlaying = true
            showControls(hideAfter: 1.0)
            loadTracks()
            applyDefaultSettings()
            if let rec = record, let prog = rec.progressForEpisode(episodeId: episode?.id), !prog.isCompleted {
                playerLayer.seek(time: prog.currentTime, autoPlay: true) { _ in }
            }

        case .buffering:
            isLoading = true

        case .bufferFinished:
            isLoading = false

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
        guard let layer = playerCoordinator.playerLayer else { return }
        if isPlaying {
            layer.pause()
            isPlaying = false
            showControls(persistent: true)
        } else {
            layer.play()
            isPlaying = true
            showControls(hideAfter: 1.0)
        }
    }

    private func skip(seconds: Double) {
        guard let layer = playerCoordinator.playerLayer else { return }
        let currentTime = layer.player.currentPlaybackTime
        let duration = layer.player.duration
        let newTime = max(0, min(currentTime + seconds, duration))
        layer.seek(time: newTime, autoPlay: isPlaying) { _ in }
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

    // MARK: - Controls Visibility

    private func showControls(hideAfter delay: TimeInterval? = nil, persistent: Bool = false) {
        hideControlsTimer?.invalidate()
        withAnimation(.easeInOut(duration: 0.3)) { controlsOpacity = 1.0 }
        guard !persistent, !isMenuOpen, let delay else { return }
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { _ in
            Task { @MainActor in
                guard isPlaying, !isMenuOpen else { return }
                withAnimation(.easeInOut(duration: 0.5)) { controlsOpacity = 0.0 }
            }
        }
    }

    // MARK: - Timers

    private func stopTimers() {
        [progressTimer, hideControlsTimer].forEach { $0?.invalidate() }
        progressTimer = nil
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
        let currentTime = playerCoordinator.playerLayer?.player.currentPlaybackTime ?? 0
        let duration = playerCoordinator.playerLayer?.player.duration ?? 0

        guard duration > 0, currentTime >= 10 else { return }

        let mediaRecord = record ?? {
            let new = MediaRecord(id: mediaItem.id, type: mediaItem.type)
            modelContext.insert(new)
            return new
        }()

        let isComplete = currentTime / duration >= 0.9

        mediaRecord.updateProgress(
            episodeId: episode?.id,
            season: episode?.season,
            episode: episode?.episodeNumber,
            currentTime: isComplete ? duration : currentTime,
            totalDuration: duration,
            streamUrl: url.absoluteString
        )
        try? modelContext.save()
    }
}
