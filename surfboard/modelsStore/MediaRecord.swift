//
//  MediaRecord.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-01-07.
//

import Foundation
import SwiftData

/// Unified model for tracking user's relationship with media (favorites + watch history)
@Model
final class MediaRecord {
    /// Unique identifier - the media ID (e.g., "tt0903747")
    @Attribute(.unique) var id: String

    /// Media type: "movie" or "series"
    var type: String

    // MARK: - Favorites

    /// Whether this media is favorited
    var isFavorite: Bool = false

    /// When the media was favorited
    var favoritedAt: Date?

    // MARK: - Watch History

    /// JSON-encoded array of EpisodeProgress
    /// For movies: contains a single entry with episodeId = nil
    /// For series: contains an entry for each watched/in-progress episode
    var watchHistoryData: Data = Data()

    /// Last time this record was updated
    var updatedAt: Date = Date()

    // MARK: - Initialization

    init(id: String, type: String) {
        self.id = id
        self.type = type
    }

    // MARK: - Watch History Computed Properties

    /// Decoded watch history
    var watchHistory: [EpisodeProgress] {
        get {
            guard !watchHistoryData.isEmpty else { return [] }
            return (try? JSONDecoder().decode([EpisodeProgress].self, from: watchHistoryData)) ?? []
        }
        set {
            watchHistoryData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    /// Most recent episode/movie progress (for continue watching)
    var mostRecentProgress: EpisodeProgress? {
        watchHistory
            .filter { !$0.isCompleted }
            .sorted { $0.watchedAt > $1.watchedAt }
            .first
    }

    /// Whether there's incomplete watching to continue
    var hasContinueWatching: Bool {
        mostRecentProgress != nil
    }

    /// Display title for continue watching
    var continueWatchingTitle: String? {
        guard let progress = mostRecentProgress else { return nil }
        if let season = progress.season, let episode = progress.episodeNumber {
            return "S\(season) E\(episode)"
        }
        return nil
    }

    // MARK: - Watch History Methods

    /// Update or add progress for an episode (or movie)
    func updateProgress(
        episodeId: String?,
        season: Int?,
        episode: Int?,
        currentTime: Double,
        totalDuration: Double,
        streamUrl: String?
    ) {
        var history = watchHistory

        // Find existing entry
        if let index = history.firstIndex(where: { $0.episodeId == episodeId }) {
            // Update existing
            history[index].currentTime = currentTime
            history[index].totalDuration = totalDuration
            history[index].streamUrl = streamUrl
            history[index].watchedAt = Date()
        } else {
            // Add new entry
            let newProgress = EpisodeProgress(
                episodeId: episodeId,
                season: season,
                episodeNumber: episode,
                currentTime: currentTime,
                totalDuration: totalDuration,
                streamUrl: streamUrl,
                watchedAt: Date()
            )
            history.append(newProgress)
        }

        watchHistory = history
        updatedAt = Date()
    }

    /// Check if an episode is watched (>= 90% progress)
    func isEpisodeWatched(episodeId: String?) -> Bool {
        guard let progress = progressForEpisode(episodeId: episodeId) else { return false }
        return progress.isCompleted
    }

    /// Get progress for a specific episode
    func progressForEpisode(episodeId: String?) -> EpisodeProgress? {
        watchHistory.first { $0.episodeId == episodeId }
    }

    /// Remove progress entry for an episode (when fully watched and we don't want it in continue watching)
    func clearProgress(episodeId: String?) {
        var history = watchHistory
        history.removeAll { $0.episodeId == episodeId }
        watchHistory = history
        updatedAt = Date()
    }

    /// Get all watched episode IDs for this series
    var watchedEpisodeIds: Set<String> {
        Set(watchHistory.filter { $0.isCompleted }.compactMap { $0.episodeId })
    }
}

// MARK: - EpisodeProgress

/// Progress tracking for a single episode or movie
struct EpisodeProgress: Codable, Identifiable, Hashable {
    var id: String { episodeId ?? "movie" }

    /// Episode ID (nil for movies)
    let episodeId: String?

    /// Season number (nil for movies)
    let season: Int?

    /// Episode number (nil for movies)
    let episodeNumber: Int?

    /// Current playback position in seconds
    var currentTime: Double

    /// Total duration in seconds
    var totalDuration: Double

    /// Stream URL for resuming playback
    var streamUrl: String?

    /// When this was last watched
    var watchedAt: Date

    // MARK: - Computed Properties

    /// Progress as a percentage (0.0 to 1.0)
    var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return min(1.0, currentTime / totalDuration)
    }

    /// Whether this episode/movie is considered completed (>= 90%)
    var isCompleted: Bool {
        progress >= 0.9
    }

    /// Time remaining in seconds
    var timeRemaining: Double {
        max(0, totalDuration - currentTime)
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
        guard let season = season, let episode = episodeNumber else { return nil }
        return "S\(season) E\(episode)"
    }
}
