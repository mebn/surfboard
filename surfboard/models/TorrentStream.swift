//
//  TorrentStream.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-26.
//

import Foundation

struct StremioStreamResponse: Codable {
    let streams: [StremioStream]
}

struct StremioStream: Codable, Identifiable, Hashable {
    // Core properties
    let name: String?
    let title: String?
    let url: String?
    let infoHash: String?
    let fileIdx: Int?
    
    // Sources (tracker URLs, DHT info)
    let sources: [String]?
    
    // Behavior hints
    let behaviorHints: StreamBehaviorHints?
    
    // Additional stream info (some addons provide these)
    let description: String?
    let subtitles: [Subtitle]?
    
    // Stremio addon specific
    let externalUrl: String?
    
    var id: String {
        infoHash ?? url ?? UUID().uuidString
    }
    
    var displayTitle: String {
        title ?? name ?? "Unknown Source"
    }
    
    var displayName: String {
        name ?? "Unknown"
    }
    
    var filename: String? {
        behaviorHints?.filename
    }
    
    var bingeGroup: String? {
        behaviorHints?.bingeGroup
    }
    
    var magnetURL: String? {
        guard let infoHash = infoHash else { return nil }
        var magnet = "magnet:?xt=urn:btih:\(infoHash)"
        
        if let filename = filename {
            if let encodedName = filename.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                magnet += "&dn=\(encodedName)"
            }
        }
        
        if let sources = sources {
            for source in sources {
                if source.hasPrefix("tracker:") {
                    let tracker = String(source.dropFirst(8))
                    if let encodedTracker = tracker.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                        magnet += "&tr=\(encodedTracker)"
                    }
                }
            }
        }
        
        return magnet
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
    
    var resolution: StreamResolution {
        let titleLower = (title ?? "").lowercased()
        if titleLower.contains("2160p") || titleLower.contains("4k") {
            return .uhd4k
        } else if titleLower.contains("1080p") {
            return .fullHD
        } else if titleLower.contains("720p") {
            return .hd
        } else if titleLower.contains("480p") {
            return .sd
        }
        return .unknown
    }
    
    var hdrType: HDRType {
        let titleLower = (title ?? "").lowercased() + (name ?? "").lowercased()
        if titleLower.contains("dolby vision") || titleLower.contains("dv") {
            if titleLower.contains("hdr") {
                return .dvHdr
            }
            return .dolbyVision
        } else if titleLower.contains("hdr10+") {
            return .hdr10Plus
        } else if titleLower.contains("hdr10") || titleLower.contains("hdr") {
            return .hdr10
        }
        return .sdr
    }
    
    
    var videoCodec: String? {
        let titleLower = (title ?? "").lowercased() + (filename ?? "").lowercased()
        if titleLower.contains("hevc") || titleLower.contains("x265") || titleLower.contains("h.265") || titleLower.contains("h265") {
            return "HEVC"
        } else if titleLower.contains("x264") || titleLower.contains("h.264") || titleLower.contains("h264") {
            return "H.264"
        } else if titleLower.contains("av1") {
            return "AV1"
        }
        return nil
    }
    
    var audioCodec: String? {
        let titleLower = (title ?? "").lowercased() + (filename ?? "").lowercased()
        if titleLower.contains("truehd") && titleLower.contains("atmos") {
            return "TrueHD Atmos"
        } else if titleLower.contains("truehd") {
            return "TrueHD"
        } else if titleLower.contains("dts-hd ma") || titleLower.contains("dts-hd.ma") {
            return "DTS-HD MA"
        } else if titleLower.contains("dts") {
            return "DTS"
        } else if titleLower.contains("dolby digital") || titleLower.contains("dd5.1") || titleLower.contains("ac3") {
            return "AC3"
        } else if titleLower.contains("aac") {
            return "AAC"
        }
        return nil
    }
    
    var isRemux: Bool {
        let titleLower = (title ?? "").lowercased() + (filename ?? "").lowercased()
        return titleLower.contains("remux")
    }
    
    var isWebDL: Bool {
        let titleLower = (title ?? "").lowercased() + (filename ?? "").lowercased()
        return titleLower.contains("web-dl") || titleLower.contains("webdl")
    }
    
    var isBluRay: Bool {
        let titleLower = (title ?? "").lowercased() + (filename ?? "").lowercased()
        return titleLower.contains("bluray") || titleLower.contains("blu-ray") || titleLower.contains("bdrip")
    }
}

struct StreamBehaviorHints: Codable, Hashable {
    let bingeGroup: String?
    let filename: String?
    let videoHash: String?
    let videoSize: Int64?
    let notWebReady: Bool?
    
    // Additional hints some addons provide
    let countryWhitelist: [String]?
    let proxyHeaders: ProxyHeaders?
}

struct ProxyHeaders: Codable, Hashable {
    let request: [String: String]?
    let response: [String: String]?
}

struct Subtitle: Codable, Hashable {
    let id: String?
    let url: String?
    let lang: String?
}

enum StreamResolution: String, Comparable {
    case unknown = "Unknown"
    case sd = "480p"
    case hd = "720p"
    case fullHD = "1080p"
    case uhd4k = "4K"
    
    var sortOrder: Int {
        switch self {
        case .unknown: return 0
        case .sd: return 1
        case .hd: return 2
        case .fullHD: return 3
        case .uhd4k: return 4
        }
    }
    
    static func < (lhs: StreamResolution, rhs: StreamResolution) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

enum HDRType: String {
    case sdr = "SDR"
    case hdr10 = "HDR10"
    case hdr10Plus = "HDR10+"
    case dolbyVision = "DV"
    case dvHdr = "DV HDR"
}
