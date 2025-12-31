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
    var addedAt: Date
    
    init(mediaItem: MediaItem) {
        id = mediaItem.id
        type = mediaItem.type
        addedAt = Date()
    }
    
    var isMovie: Bool {
        return type == "movie"
    }
    
    var isSeries: Bool {
        return type == "series"
    }
}
