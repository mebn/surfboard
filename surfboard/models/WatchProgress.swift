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
    // Unique identifier combining itemId and episodeId
    @Attribute(.unique) var id: String
    
    // Media item info
    var itemId: String
    var itemType: String
    var itemName: String
    var itemPoster: String?
    
    // Episode info (optional, for series)
    var episodeId: String?
    var episodeSeason: Int?
    var episodeNumber: Int?
    var episodeName: String?
    var episodeThumbnail: String?
    
    // Progress info
    var currentTime: TimeInterval
    var totalTime: TimeInterval
    var streamUrl: String
    var lastWatched: Date
    
    init(
        itemId: String,
        itemType: String,
        itemName: String,
        itemPoster: String? = nil,
        episodeId: String? = nil,
        episodeSeason: Int? = nil,
        episodeNumber: Int? = nil,
        episodeName: String? = nil,
        episodeThumbnail: String? = nil,
        currentTime: TimeInterval,
        totalTime: TimeInterval,
        streamUrl: String,
        lastWatched: Date = Date()
    ) {
        // Create unique ID from itemId and episodeId
        if let episodeId = episodeId {
            self.id = "\(itemId):\(episodeId)"
        } else {
            self.id = itemId
        }
        
        self.itemId = itemId
        self.itemType = itemType
        self.itemName = itemName
        self.itemPoster = itemPoster
        self.episodeId = episodeId
        self.episodeSeason = episodeSeason
        self.episodeNumber = episodeNumber
        self.episodeName = episodeName
        self.episodeThumbnail = episodeThumbnail
        self.currentTime = currentTime
        self.totalTime = totalTime
        self.streamUrl = streamUrl
        self.lastWatched = lastWatched
    }
    
    // MARK: - Computed Properties
    
    /// Returns remaining time in seconds
    var remainingTime: TimeInterval {
        max(0, totalTime - currentTime)
    }
    
    /// Returns progress as percentage (0.0 to 1.0)
    var progressPercentage: Double {
        guard totalTime > 0 else { return 0 }
        return min(1.0, currentTime / totalTime)
    }
    
    /// Returns formatted remaining time string (e.g., "45 min left" or "1h 30m left")
    var remainingTimeFormatted: String {
        let remaining = Int(remainingTime)
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        } else if minutes > 0 {
            return "\(minutes) min left"
        } else {
            return "Less than 1 min left"
        }
    }
    
    /// Returns the thumbnail URL - uses episode thumbnail for series, poster for movies
    var thumbnailURL: URL? {
        if let episodeThumbnail = episodeThumbnail {
            return URL(string: episodeThumbnail)
        }
        guard let poster = itemPoster else { return nil }
        return URL(string: poster)
    }
    
    /// Returns the display title - includes episode info for series
    var displayTitle: String {
        if let season = episodeSeason, let episode = episodeNumber {
            return "S\(season) E\(episode)"
        }
        return itemName
    }
    
    /// Returns stream URL as URL object
    var streamURL: URL? {
        URL(string: streamUrl)
    }
    
    var isMovie: Bool {
        itemType == "movie"
    }
    
    var isSeries: Bool {
        itemType == "series"
    }
    
    /// Check if the content is considered "finished" (within 60 seconds of the end)
    var isNearlyFinished: Bool {
        remainingTime < 60
    }
}
