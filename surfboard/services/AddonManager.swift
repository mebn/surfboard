//
//  AddonManager.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-30.
//

import Foundation

/// Manages multiple Stremio addons and routes requests to appropriate ones
@MainActor
class AddonManager: ObservableObject {
    static let shared = AddonManager()
    
    @Published private(set) var addons: [StremioAddonService] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoaded = false
    
    private init() {}
    
    /// Loads addons from manifest URLs
    func loadAddons(from urls: [URL]) async {
        isLoading = true
        var loadedAddons: [StremioAddonService] = []
        
        for url in urls {
            let addon = StremioAddonService(manifestURL: url)
            do {
                try await addon.loadManifest()
                loadedAddons.append(addon)
                print("Loaded addon: \(addon.name) with resources: \(addon.manifest?.resources.map { $0.name } ?? [])")
            } catch {
                print("Failed to load addon from \(url): \(error)")
            }
        }
        
        addons = loadedAddons
        isLoading = false
        isLoaded = true
        print("Total addons loaded: \(addons.count)")
    }
    
    /// Loads addons from Info.plist keys
    func loadAddonsFromBundle() async {
        var urls: [URL] = []
        
        // Load from individual keys: CINEMETA, TORRENTIO, MEDIAFUSION
        let keys = ["CINEMETA", "TORRENTIO", "MEDIAFUSION"]
        for key in keys {
            if var urlString = Bundle.main.object(forInfoDictionaryKey: key) as? String,
               !urlString.isEmpty {
                // Support both https:// and stremio:// protocols
                if urlString.hasPrefix("stremio://") {
                    urlString = urlString.replacingOccurrences(of: "stremio://", with: "https://")
                }
                
                if let url = URL(string: urlString) {
                    urls.append(url)
                    print("Found addon URL for \(key): \(urlString)")
                }
            } else {
                print("No addon URL found for key: \(key)")
            }
        }
        
        await loadAddons(from: urls)
    }
    
    /// Returns addons that support a specific resource and type
    func addons(for resource: String, type: String) -> [StremioAddonService] {
        let matching = addons.filter { $0.supports(resource: resource, type: type) }
        print("Found \(matching.count) addons for resource '\(resource)' type '\(type)': \(matching.map { $0.name })")
        return matching
    }
    
    /// Fetches all catalogs of a given type from all supporting addons
    func fetchCatalogs(type: String) async throws -> [(addon: StremioAddonService, items: [MediaItem])] {
        let catalogAddons = addons(for: "catalog", type: type)
        var results: [(addon: StremioAddonService, items: [MediaItem])] = []
        
        for addon in catalogAddons {
            guard let catalogs = addon.manifest?.catalogs(for: type), !catalogs.isEmpty else {
                print("No catalogs for type \(type) in addon \(addon.name)")
                continue
            }
            
            // Use the first catalog for this type
            if let firstCatalog = catalogs.first {
                do {
                    print("Fetching catalog '\(firstCatalog.id)' from \(addon.name)")
                    let items = try await addon.fetchCatalog(type: type, id: firstCatalog.id)
                    print("Got \(items.count) items from \(addon.name)")
                    results.append((addon: addon, items: items))
                } catch {
                    print("Error fetching catalog from \(addon.name): \(error)")
                }
            }
        }
        
        return results
    }
    
    /// Fetches metadata from the first addon that supports it
    func fetchMeta(type: String, id: String) async throws -> MediaItem {
        let metaAddons = addons(for: "meta", type: type)
        
        for addon in metaAddons {
            do {
                return try await addon.fetchMeta(type: type, id: id)
            } catch {
                print("Error fetching meta from \(addon.name): \(error)")
                continue
            }
        }
        
        throw StremioAddonError.noAddonFound
    }
    
    /// Fetches streams from all addons that support it
    func fetchStreams(type: String, id: String) async throws -> [StremioStream] {
        let streamAddons = addons(for: "stream", type: type)
        var allStreams: [StremioStream] = []
        
        for addon in streamAddons {
            do {
                print("Fetching streams from \(addon.name) for \(type)/\(id)")
                let streams = try await addon.fetchStreams(type: type, id: id)
                print("Got \(streams.count) streams from \(addon.name)")
                allStreams.append(contentsOf: streams)
            } catch {
                print("Error fetching streams from \(addon.name): \(error)")
            }
        }
        
        return allStreams
    }
    
    /// Searches catalogs that support search
    func searchCatalogs(type: String, query: String) async throws -> [MediaItem] {
        let catalogAddons = addons(for: "catalog", type: type)
        var allResults: [MediaItem] = []
        
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }
        
        for addon in catalogAddons {
            guard let catalogs = addon.manifest?.catalogs(for: type) else { continue }
            
            // Find catalogs that support search
            for catalog in catalogs where catalog.supportsSearch {
                do {
                    print("Searching catalog '\(catalog.id)' in \(addon.name) for '\(query)'")
                    let results = try await addon.fetchCatalog(type: type, id: catalog.id, extra: ["search": encodedQuery])
                    allResults.append(contentsOf: results)
                } catch {
                    print("Error searching in \(addon.name): \(error)")
                }
            }
        }
        
        // Remove duplicates based on ID
        var seen = Set<String>()
        return allResults.filter { item in
            if seen.contains(item.id) {
                return false
            }
            seen.insert(item.id)
            return true
        }
    }
}
