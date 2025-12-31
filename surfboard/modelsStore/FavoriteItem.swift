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
    var mediaItemData: Data
    var addedAt: Date
    
    init(mediaItem: MediaItem) {
        self.id = mediaItem.id
        self.mediaItemData = (try? JSONEncoder().encode(mediaItem)) ?? Data()
        self.addedAt = Date()
    }
    
    /// Decode the stored MediaItem
    var mediaItem: MediaItem? {
        try? JSONDecoder().decode(MediaItem.self, from: mediaItemData)
    }
    
    var isMovie: Bool {
        mediaItem?.isMovie ?? false
    }
    
    var isSeries: Bool {
        mediaItem?.isSeries ?? false
    }
}
