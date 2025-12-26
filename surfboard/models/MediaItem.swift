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
    let id: String
    let type: String
    let name: String
    let poster: String?
    
    var posterURL: URL? {
        guard let poster = poster else { return nil }
        return URL(string: poster)
    }
}
