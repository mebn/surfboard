//
//  StremioManifest.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-30.
//

import Foundation

/// Represents a Stremio addon manifest.json
struct StremioManifest: Codable, Identifiable {
    let id: String
    let version: String
    let name: String
    let description: String?
    let logo: String?
    let resources: [ManifestResource]
    let types: [String]
    let catalogs: [ManifestCatalog]?
    let idPrefixes: [String]?
    let behaviorHints: ManifestBehaviorHints?
    
    /// Checks if this addon provides a specific resource for a given type
    func supports(resource: String, type: String) -> Bool {
        let hasResource = resources.contains { res in
            switch res {
            case .simple(let name):
                return name == resource
            case .detailed(let detail):
                if detail.name != resource { return false }
                if let types = detail.types, !types.contains(type) { return false }
                return true
            }
        }
        return hasResource && types.contains(type)
    }
    
    /// Returns catalogs for a specific type
    func catalogs(for type: String) -> [ManifestCatalog] {
        catalogs?.filter { $0.type == type } ?? []
    }
}

/// A resource can be either a simple string or a detailed object
enum ManifestResource: Codable {
    case simple(String)
    case detailed(ManifestResourceDetail)
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            self = .simple(stringValue)
        } else {
            let detail = try container.decode(ManifestResourceDetail.self)
            self = .detailed(detail)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .simple(let name):
            try container.encode(name)
        case .detailed(let detail):
            try container.encode(detail)
        }
    }
    
    var name: String {
        switch self {
        case .simple(let name): return name
        case .detailed(let detail): return detail.name
        }
    }
}

struct ManifestResourceDetail: Codable {
    let name: String
    let types: [String]?
    let idPrefixes: [String]?
}

struct ManifestCatalog: Codable, Identifiable {
    let type: String
    let id: String
    let name: String?
    let genres: [String]?
    let extra: [CatalogExtra]?
    let extraSupported: [String]?
    let extraRequired: [String]?
    
    var displayName: String {
        name ?? id.capitalized
    }
    
    /// Checks if this catalog supports search
    var supportsSearch: Bool {
        // Check extraSupported array first (more reliable)
        if let supported = extraSupported, supported.contains("search") {
            return true
        }
        // Fallback to checking extra array
        return extra?.contains { $0.name == "search" } ?? false
    }
}

struct CatalogExtra: Codable {
    let name: String
    let isRequired: Bool?
    let options: [String]?
}

struct ManifestBehaviorHints: Codable {
    let adult: Bool?
    let p2p: Bool?
    let configurable: Bool?
    let configurationRequired: Bool?
}
