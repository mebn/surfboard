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
    
    /// The media ID (IMDB ID). For both movies and TV shows, this is the parent media ID.
    var mediaId: String
    
    /// The media type: "movie" or "series"
    var mediaType: String
    
    var title: String
    var imageUrl: String?
    var streamUrl: String?
    
    var season: Int?
    var episode: Int?
    
    var currentTime: Double
    var totalDuration: Double
    
    /// Timestamp for sorting
    var updatedAt: Date
    
    init(
        id: String,
        mediaId: String,
        mediaType: String,
        title: String,
        imageUrl: String? = nil,
        streamUrl: String? = nil,
        season: Int? = nil,
        episode: Int? = nil,
        currentTime: Double = 0,
        totalDuration: Double = 0,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.mediaId = mediaId
        self.mediaType = mediaType
        self.title = title
        self.imageUrl = imageUrl
        self.streamUrl = streamUrl
        self.season = season
        self.episode = episode
        self.currentTime = currentTime
        self.totalDuration = totalDuration
        self.updatedAt = updatedAt
    }
    
    /// Computed property to get URL from string
    var imageURL: URL? {
        guard let imageUrl = imageUrl else { return nil }
        return URL(string: imageUrl)
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
        guard let season = season, let episode = episode else { return nil }
        return "S\(season) E\(episode)"
    }
}
