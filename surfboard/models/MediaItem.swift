//
//  MediaItem.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import Foundation

struct CinemetaCatalogResponse: Codable {
    let metas: [MediaItem]
}

struct MediaItem: Codable, Identifiable, Hashable {
    // Core identifiers
    let id: String
    let type: String
    let name: String
    
    // Alternative identifiers
    let imdbId: String?
    let moviedbId: Int?
    
    // Images
    let poster: String?
    let background: String?
    let logo: String?
    
    // Basic info
    let description: String?
    let year: String?
    let releaseInfo: String?
    let released: String?
    let runtime: String?
    let country: String?
    let awards: String?
    let slug: String?
    
    // Ratings & popularity
    let imdbRating: String?
    let popularity: Double?
    let popularities: Popularities?
    
    // People
    let cast: [String]?
    let director: [String]?
    let writer: [String]?
    
    // Genres/categories
    let genre: [String]?
    let genres: [String]?
    
    // Videos (for series episodes)
    let videos: [Episode]?
    
    // Trailers
    let trailers: [Trailer]?
    let trailerStreams: [TrailerStream]?
    
    // Links (share, IMDb, genres, cast navigation)
    let links: [MediaLink]?
    
    // Behavior hints
    let behaviorHints: MediaBehaviorHints?
    
    // DVD release date (movies)
    let dvdRelease: String?
    
    enum CodingKeys: String, CodingKey {
        case id, type, name
        case imdbId = "imdb_id"
        case moviedbId = "moviedb_id"
        case poster, background, logo
        case description, year, releaseInfo, released, runtime, country, awards, slug
        case imdbRating, popularity, popularities
        case cast, director, writer
        case genre, genres
        case videos
        case trailers, trailerStreams
        case links
        case behaviorHints
        case dvdRelease
    }
    
    var posterURL: URL? {
        guard let poster = poster else { return nil }
        return URL(string: poster)
    }
    
    var backgroundURL: URL? {
        guard let background = background else { return nil }
        return URL(string: background)
    }
    
    var logoURL: URL? {
        guard let logo = logo else { return nil }
        return URL(string: logo)
    }
    
    var allGenres: [String] {
        // The API sometimes returns both 'genre' and 'genres' arrays
        return genres ?? genre ?? []
    }
    
    var castString: String? {
        guard let cast = cast, !cast.isEmpty else { return nil }
        return cast.joined(separator: ", ")
    }
    
    var directorString: String? {
        guard let director = director, !director.isEmpty else { return nil }
        return director.joined(separator: ", ")
    }
    
    var writerString: String? {
        guard let writer = writer, !writer.isEmpty else { return nil }
        return writer.joined(separator: ", ")
    }
    
    var releasedDate: Date? {
        guard let released = released else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: released)
    }
    
    var isMovie: Bool {
        return type == "movie"
    }
    
    var isSeries: Bool {
        return type == "series"
    }
    
    /// Groups episodes by season number
    var episodesBySeason: [Int: [Episode]] {
        guard let videos = videos else { return [:] }
        return Dictionary(grouping: videos, by: { $0.season })
    }
    
    /// Returns season numbers sorted
    var seasons: [Int] {
        return episodesBySeason.keys.sorted()
    }
}

struct Popularities: Codable, Hashable {
    let moviedb: Double?
    let stremio: Double?
    let stremioLib: Double?
    let trakt: Double?
    
    enum CodingKeys: String, CodingKey {
        case moviedb
        case stremio
        case stremioLib = "stremio_lib"
        case trakt
    }
}

struct Episode: Codable, Identifiable, Hashable {
    let id: String
    let name: String?
    let season: Int
    let number: Int
    let episode: Int?
    let firstAired: String?
    let released: String?
    let overview: String?
    let description: String?
    let thumbnail: String?
    let tvdbId: Int?
    let rating: Double?
    
    enum CodingKeys: String, CodingKey {
        case id, name, season, number, episode
        case firstAired, released
        case overview, description
        case thumbnail
        case tvdbId = "tvdb_id"
        case rating
    }
    
    var thumbnailURL: URL? {
        guard let thumbnail = thumbnail else { return nil }
        return URL(string: thumbnail)
    }
    
    var displayDescription: String? {
        return description ?? overview
    }
    
    var releasedDate: Date? {
        guard let dateString = released ?? firstAired else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: dateString)
    }
    
    var episodeNumber: Int {
        return episode ?? number
    }
}

struct Trailer: Codable, Hashable {
    let source: String
    let type: String?
    
    var youtubeURL: URL? {
        return URL(string: "https://www.youtube.com/watch?v=\(source)")
    }
}

struct TrailerStream: Codable, Hashable {
    let title: String?
    let ytId: String?
    
    var youtubeURL: URL? {
        guard let ytId = ytId else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(ytId)")
    }
}

struct MediaLink: Codable, Hashable {
    let name: String?
    let category: String?
    let url: String?
}

struct MediaBehaviorHints: Codable, Hashable {
    let defaultVideoId: String?
    let hasScheduledVideos: Bool?
}

extension MediaItem {
    /// Creates a preview/mock MediaItem for testing and SwiftUI previews
    static func preview(
        id: String = "tt0111161",
        type: String = "movie",
        name: String = "The Shawshank Redemption",
        poster: String? = nil,
        description: String? = nil,
        year: String? = "1994",
        imdbRating: String? = "9.3"
    ) -> MediaItem {
        MediaItem(
            id: id,
            type: type,
            name: name,
            imdbId: id,
            moviedbId: nil,
            poster: poster,
            background: nil,
            logo: nil,
            description: description,
            year: year,
            releaseInfo: year,
            released: nil,
            runtime: nil,
            country: nil,
            awards: nil,
            slug: nil,
            imdbRating: imdbRating,
            popularity: nil,
            popularities: nil,
            cast: nil,
            director: nil,
            writer: nil,
            genre: nil,
            genres: nil,
            videos: nil,
            trailers: nil,
            trailerStreams: nil,
            links: nil,
            behaviorHints: nil,
            dvdRelease: nil
        )
    }
}
