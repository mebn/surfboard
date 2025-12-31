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
    /// Unique identifier - mediaId for movies, or "mediaId:season:episode" for TV episodes
    @Attribute(.unique) var id: String
    
    /// IMDB ID of the movie or series
    var mediaId: String
    
    /// "movie" or "series"
    var mediaType: String
    
    /// Title of the movie or series
    var title: String
    
    /// Poster URL for movies, thumbnail URL for TV episodes
    var imageUrl: String?
    
    // TV Show specific fields
    var season: Int?
    var episodeNumber: Int?
    var episodeName: String?
    
    // Progress tracking
    var currentTime: Double
    var totalDuration: Double
    var updatedAt: Date
    
    /// Stream URL for resuming playback directly
    var streamUrl: String?
    
    init(
        id: String,
        mediaId: String,
        mediaType: String,
        title: String,
        imageUrl: String? = nil,
        season: Int? = nil,
        episodeNumber: Int? = nil,
        episodeName: String? = nil,
        currentTime: Double = 0,
        totalDuration: Double = 0,
        updatedAt: Date = Date(),
        streamUrl: String? = nil
    ) {
        self.id = id
        self.mediaId = mediaId
        self.mediaType = mediaType
        self.title = title
        self.imageUrl = imageUrl
        self.season = season
        self.episodeNumber = episodeNumber
        self.episodeName = episodeName
        self.currentTime = currentTime
        self.totalDuration = totalDuration
        self.updatedAt = updatedAt
        self.streamUrl = streamUrl
    }
    
    /// Creates a WatchProgress for a movie
    convenience init(from movie: MediaItem, currentTime: Double = 0, totalDuration: Double = 0, streamUrl: String? = nil) {
        self.init(
            id: movie.id,
            mediaId: movie.id,
            mediaType: movie.type,
            title: movie.name,
            imageUrl: movie.background,
            currentTime: currentTime,
            totalDuration: totalDuration,
            streamUrl: streamUrl
        )
    }
    
    /// Creates a WatchProgress for a TV episode
    convenience init(from series: MediaItem, episode: Episode, currentTime: Double = 0, totalDuration: Double = 0, streamUrl: String? = nil) {
        self.init(
            id: "\(series.id):\(episode.season):\(episode.episodeNumber)",
            mediaId: series.id,
            mediaType: series.type,
            title: series.name,
            imageUrl: episode.thumbnail,
            season: episode.season,
            episodeNumber: episode.episodeNumber,
            episodeName: episode.name,
            currentTime: currentTime,
            totalDuration: totalDuration,
            streamUrl: streamUrl
        )
    }
    
    var imageURL: URL? {
        guard let imageUrl = imageUrl else { return nil }
        return URL(string: imageUrl)
    }
    
    var isMovie: Bool {
        return mediaType == "movie"
    }
    
    var isSeries: Bool {
        return mediaType == "series"
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
        guard let season = season, let episodeNumber = episodeNumber else { return nil }
        return "S\(season) E\(episodeNumber)"
    }
}
