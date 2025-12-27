//
//  CustomPlayerOverlayView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-27.
//

import SwiftUI
import KSPlayer

struct CustomPlayerOverlayView: View {
    @ObservedObject var coordinator: KSVideoPlayer.Coordinator
    let title: String
    @Binding var scrubPosition: Double
    @Binding var isScrubbing: Bool
    let isScrubberFocused: Bool
    let onSeek: (TimeInterval) -> Void
    
    private let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
    
    var body: some View {
        VStack {
            Spacer()
            
            // Bottom control area with gradient background
            VStack(spacing: 20) {
                // Title and buttons row
                HStack(alignment: .center) {
                    // Title on left
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                        
                        if isScrubbing {
                            Text("Scrubbing • Press Menu to confirm")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Control buttons on right (hidden during scrubbing)
                    if !isScrubbing {
                        HStack(spacing: 20) {
                            // Audio language button
                            if let audioTracks = coordinator.playerLayer?.player.tracks(mediaType: .audio),
                               !audioTracks.isEmpty {
                                audioButton(tracks: audioTracks)
                            }
                            
                            // Subtitle button
                            subtitleButton
                            
                            // Playback speed button
                            speedButton
                        }
                    }
                }
                .padding(.horizontal, 60)
                
                // Progress bar
                progressBar
                    .padding(.horizontal, 60)
                
                // Time labels
                HStack {
                    Text(formatTime(displayCurrentTime))
                        .font(.caption)
                        .monospacedDigit()
                    
                    Spacer()
                    
                    Text(formatTime(coordinator.timemodel.totalTime))
                        .font(.caption)
                        .monospacedDigit()
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 40)
            }
            .padding(.top, 40)
            .background(
                LinearGradient(
                    stops: [
                        Gradient.Stop(color: .clear, location: 0),
                        Gradient.Stop(color: .black.opacity(0.8), location: 0.3),
                        Gradient.Stop(color: .black.opacity(0.9), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .foregroundColor(.white)
    }
    
    private var displayCurrentTime: Int {
        isScrubbing ? Int(scrubPosition) : coordinator.timemodel.currentTime
    }
    
    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: isScrubberFocused ? 10 : 6)
                
                // Progress
                Capsule()
                    .fill(isScrubberFocused ? Color.blue : Color.white)
                    .frame(width: progressWidth(in: geometry.size.width), height: isScrubberFocused ? 10 : 6)
                
                // Scrubber indicator when focused
                if isScrubberFocused {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                        .offset(x: progressWidth(in: geometry.size.width) - 10)
                }
            }
            .animation(.easeInOut(duration: 0.15), value: isScrubberFocused)
        }
        .frame(height: isScrubberFocused ? 20 : 6)
    }
    
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let totalTime = Double(coordinator.timemodel.totalTime)
        guard totalTime > 0 else { return 0 }
        
        let currentTime = isScrubbing ? scrubPosition : Double(coordinator.timemodel.currentTime)
        let progress = currentTime / totalTime
        return totalWidth * min(max(CGFloat(progress), 0), 1)
    }
    
    private func audioButton(tracks: [MediaPlayerTrack]) -> some View {
        Menu {
            ForEach(tracks, id: \.trackID) { track in
                Button {
                    coordinator.playerLayer?.player.select(track: track)
                } label: {
                    HStack {
                        Text(track.description)
                        if track.isEnabled {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill")
                Text("Audio")
            }
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.2))
            .cornerRadius(8)
        }
    }
    
    private var subtitleButton: some View {
        Menu {
            Button {
                coordinator.subtitleModel.selectedSubtitleInfo = nil
            } label: {
                HStack {
                    Text("Off")
                    if coordinator.subtitleModel.selectedSubtitleInfo == nil {
                        Image(systemName: "checkmark")
                    }
                }
            }
            
            ForEach(coordinator.subtitleModel.subtitleInfos, id: \.subtitleID) { info in
                Button {
                    coordinator.subtitleModel.selectedSubtitleInfo = info
                } label: {
                    HStack {
                        Text(info.name)
                        if coordinator.subtitleModel.selectedSubtitleInfo?.subtitleID == info.subtitleID {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "captions.bubble.fill")
                Text("Subtitles")
            }
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.2))
            .cornerRadius(8)
        }
    }
    
    private var speedButton: some View {
        Menu {
            ForEach(speeds, id: \.self) { speed in
                Button {
                    coordinator.playbackRate = speed
                } label: {
                    HStack {
                        Text(formatSpeed(speed))
                        if coordinator.playbackRate == speed {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "speedometer")
                Text(formatSpeed(coordinator.playbackRate))
            }
            .font(.callout)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.2))
            .cornerRadius(8)
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func formatSpeed(_ speed: Float) -> String {
        if speed == 1.0 {
            return "1x"
        } else if speed == floor(speed) {
            return String(format: "%.0fx", speed)
        } else {
            return String(format: "%.2gx", speed)
        }
    }
}

#Preview {
    ZStack {
        Color.black
        CustomPlayerOverlayView(
            coordinator: KSVideoPlayer.Coordinator(),
            title: "Sample Movie Title",
            scrubPosition: .constant(120),
            isScrubbing: .constant(false),
            isScrubberFocused: false,
            onSeek: { _ in }
        )
    }
}
