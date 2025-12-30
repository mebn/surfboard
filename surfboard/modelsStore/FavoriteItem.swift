//
//  FavoriteItem.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-27.
//

import Foundation
import SwiftData

@Model
final class FavoriteItem {
    @Attribute(.unique) var id: String
    var type: String
    var name: String
    var poster: String?
    var addedAt: Date
    
    init(id: String, type: String, name: String, poster: String? = nil, addedAt: Date = Date()) {
        self.id = id
        self.type = type
        self.name = name
        self.poster = poster
        self.addedAt = addedAt
    }
    
    /// Creates a FavoriteItem from a MediaItem
    convenience init(from mediaItem: MediaItem) {
        self.init(
            id: mediaItem.id,
            type: mediaItem.type,
            name: mediaItem.name,
            poster: mediaItem.poster
        )
    }
    
    var posterURL: URL? {
        guard let poster = poster else { return nil }
        return URL(string: poster)
    }
    
    var isMovie: Bool {
        return type == "movie"
    }
    
    var isSeries: Bool {
        return type == "series"
    }
}
