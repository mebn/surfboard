//
//  StremioAddonService.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-30.
//

import Foundation

/// A service that communicates with a single Stremio addon via its manifest URL
class StremioAddonService: Identifiable {
    let manifestURL: URL
    private(set) var manifest: StremioManifest?
    
    /// The base URL derived from manifest URL (without /manifest.json)
    var baseURL: String {
        var base = manifestURL.deletingLastPathComponent().absoluteString
        // Remove trailing slash if present
        if base.hasSuffix("/") {
            base = String(base.dropLast())
        }
        return base
    }
    
    var id: String {
        manifest?.id ?? manifestURL.absoluteString
    }
    
    var name: String {
        manifest?.name ?? "Unknown Addon"
    }
    
    init(manifestURL: URL) {
        self.manifestURL = manifestURL
    }
    
    /// Loads and caches the manifest from the URL
    @discardableResult
    func loadManifest() async throws -> StremioManifest {
        if let manifest = manifest {
            return manifest
        }
        
        let (data, _) = try await URLSession.shared.data(from: manifestURL)
        let loadedManifest = try JSONDecoder().decode(StremioManifest.self, from: data)
        self.manifest = loadedManifest
        return loadedManifest
    }
    
    /// Checks if this addon supports a resource for a given type
    func supports(resource: String, type: String) -> Bool {
        manifest?.supports(resource: resource, type: type) ?? false
    }
    
    /// Fetches a catalog
    /// - Parameters:
    ///   - type: Content type (movie, series)
    ///   - catalogId: The catalog ID from manifest
    ///   - extra: Optional extra parameters (e.g., search query, skip)
    func fetchCatalog(type: String, id catalogId: String, extra: [String: String]? = nil) async throws -> [MediaItem] {
        var urlString = "\(baseURL)/catalog/\(type)/\(catalogId)"
        
        // Build extra parameters - always include skip=0 if not provided and not searching
        var extraParams = extra ?? [:]
        if extraParams["search"] == nil && extraParams["skip"] == nil {
            extraParams["skip"] = "0"
        }
        
        if !extraParams.isEmpty {
            let extraParts = extraParams.map { "\($0.key)=\($0.value)" }
            urlString += "/\(extraParts.joined(separator: "&"))"
        }
        
        urlString += ".json"
        
        print("Fetching catalog URL: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            throw StremioAddonError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(StremioCatalogResponse.self, from: data)
        return response.metas
    }
    
    /// Fetches metadata for a specific item
    func fetchMeta(type: String, id: String) async throws -> MediaItem {
        let urlString = "\(baseURL)/meta/\(type)/\(id).json"
        
        guard let url = URL(string: urlString) else {
            throw StremioAddonError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(StremioMetaResponse.self, from: data)
        return response.meta
    }
    
    /// Fetches streams for a specific item
    func fetchStreams(type: String, id: String) async throws -> [StremioStream] {
        let urlString = "\(baseURL)/stream/\(type)/\(id).json"
        
        guard let url = URL(string: urlString) else {
            throw StremioAddonError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw StremioAddonError.requestFailed
        }
        
        let streamResponse = try JSONDecoder().decode(StremioStreamResponse.self, from: data)
        return streamResponse.streams
    }
}

enum StremioAddonError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    case manifestNotLoaded
    case noAddonFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed:
            return "Request failed"
        case .manifestNotLoaded:
            return "Addon manifest not loaded"
        case .noAddonFound:
            return "No addon found for this request"
        }
    }
}
