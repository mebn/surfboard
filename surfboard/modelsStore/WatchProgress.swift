//
//  WatchProgress.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-27.
//

import Foundation
import SwiftData

@Model
final class WatchProgress {
    /// Unique identifier - for movies: mediaId, for TV shows: mediaId (so only one episode per show is saved)
    @Attribute(.unique) var id: String
    
    /// The stored MediaItem as JSON data
    var mediaItemData: Data
    
    /// The stored Episode as JSON data (for TV shows)
    var episodeData: Data?
    
    /// The stream URL for resuming playback
    var streamUrl: String?
    
    /// Current playback position in seconds
    var currentTime: Double
    
    /// Total duration in seconds
    var totalDuration: Double
    
    /// Timestamp for sorting
    var updatedAt: Date
    
    init(
        mediaItem: MediaItem,
        episode: Episode? = nil,
        streamUrl: String? = nil,
        currentTime: Double = 0,
        totalDuration: Double = 0,
        updatedAt: Date = Date()
    ) {
        self.id = mediaItem.id
        self.mediaItemData = (try? JSONEncoder().encode(mediaItem)) ?? Data()
        self.episodeData = episode.flatMap { try? JSONEncoder().encode($0) }
        self.streamUrl = streamUrl
        self.currentTime = currentTime
        self.totalDuration = totalDuration
        self.updatedAt = updatedAt
    }
    
    /// Decode the stored MediaItem
    var mediaItem: MediaItem? {
        try? JSONDecoder().decode(MediaItem.self, from: mediaItemData)
    }
    
    /// Decode the stored Episode
    var episode: Episode? {
        guard let data = episodeData else { return nil }
        return try? JSONDecoder().decode(Episode.self, from: data)
    }
    
    /// Computed property to get the best available image URL
    var imageURL: URL? {
        // Priority: episode thumbnail → background → poster
        if let thumbnail = episode?.thumbnail, let url = URL(string: thumbnail) {
            return url
        }
        if let background = mediaItem?.background, let url = URL(string: background) {
            return url
        }
        if let poster = mediaItem?.poster, let url = URL(string: poster) {
            return url
        }
        return nil
    }
    
    /// Display title - for TV shows includes episode info
    var displayTitle: String {
        if let episode = episode, let mediaItem = mediaItem {
            return "\(mediaItem.name) - S\(episode.season) E\(episode.episodeNumber)"
        }
        return mediaItem?.name ?? "Unknown"
    }
    
    /// Time remaining in seconds
    var timeRemaining: Double {
        return max(0, totalDuration - currentTime)
    }
    
    /// Progress as a percentage (0.0 to 1.0)
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(1.0, currentTime / totalDuration)
    }
    
    /// Formatted time remaining string (e.g., "45 min left")
    var timeRemainingText: String {
        let minutes = Int(timeRemaining / 60)
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes > 0 {
                return "\(hours)h \(remainingMinutes)m left"
            }
            return "\(hours)h left"
        }
        return "\(minutes) min left"
    }
    
    /// Display text for season and episode (e.g., "S1 E5")
    var seasonEpisodeText: String? {
        guard let episode = episode else { return nil }
        return "S\(episode.season) E\(episode.episodeNumber)"
    }
    
    /// Update the stored MediaItem
    func updateMediaItem(_ mediaItem: MediaItem) {
        self.mediaItemData = (try? JSONEncoder().encode(mediaItem)) ?? Data()
    }
    
    /// Update the stored Episode
    func updateEpisode(_ episode: Episode?) {
        self.episodeData = episode.flatMap { try? JSONEncoder().encode($0) }
    }
}
