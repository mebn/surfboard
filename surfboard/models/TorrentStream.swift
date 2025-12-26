//
//  TorrentStream.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-26.
//

import Foundation

struct TorrentioStreamResponse: Codable {
    let streams: [TorrentStream]
}

struct TorrentStream: Codable, Identifiable, Hashable {
    let name: String?
    let title: String?
    let url: String?
    let infoHash: String?
    let fileIdx: Int?
    let behaviorHints: BehaviorHints?
    
    var id: String {
        infoHash ?? url ?? UUID().uuidString
    }
    
    var displayTitle: String {
        title ?? name ?? "Unknown Source"
    }
    
    var qualityBadge: String {
        let titleLower = (title ?? "").lowercased()
        if titleLower.contains("2160p") || titleLower.contains("4k") {
            return "4K"
        } else if titleLower.contains("1080p") {
            return "1080p"
        } else if titleLower.contains("720p") {
            return "720p"
        } else if titleLower.contains("480p") {
            return "480p"
        }
        return ""
    }
}

struct BehaviorHints: Codable, Hashable {
    let bingeGroup: String?
    let filename: String?
}
