//
//  MediaMetadataCache.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-01-07.
//

import Foundation

/// Caches media metadata in memory and on disk to avoid redundant network requests
@MainActor
class MediaMetadataCache: ObservableObject {
    static let shared = MediaMetadataCache()

    /// In-memory cache
    private var memoryCache: [String: CachedItem] = [:]

    /// In-flight network requests (to deduplicate concurrent requests)
    private var inFlightRequests: [String: Task<MediaItem, Error>] = [:]

    /// Cache duration: 7 days
    private let cacheDuration: TimeInterval = 7 * 24 * 60 * 60

    /// Disk cache directory
    private let diskCacheDirectory: URL

    /// Reference to addon manager for network requests
    private var addonManager: AddonManager { AddonManager.shared }

    // MARK: - Cached Item Structure

    private struct CachedItem: Codable {
        let mediaItem: MediaItem
        let cachedAt: Date

        func isExpired(duration: TimeInterval) -> Bool {
            Date().timeIntervalSince(cachedAt) > duration
        }
    }

    // MARK: - Initialization

    private init() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        diskCacheDirectory = cacheDir.appendingPathComponent("MediaMetadataCache", isDirectory: true)

        // Create cache directory if needed
        try? FileManager.default.createDirectory(at: diskCacheDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// Get metadata from cache (memory -> disk -> network)
    /// Use this for continue watching, favorites, and movie detail views
    func get(id: String, type: String) async throws -> MediaItem {
        let key = cacheKey(id: id, type: type)

        // 1. Check memory cache
        if let cached = memoryCache[key], !cached.isExpired(duration: cacheDuration) {
            return cached.mediaItem
        }

        // 2. Check disk cache
        if let cached = loadFromDisk(key: key), !cached.isExpired(duration: cacheDuration) {
            memoryCache[key] = cached
            return cached.mediaItem
        }

        // 3. Fetch from network (with deduplication)
        return try await fetchWithDeduplication(id: id, type: type, key: key)
    }

    /// Always fetch fresh from network (for series detail view to catch new episodes)
    /// Updates both memory and disk cache
    func fetchFresh(id: String, type: String) async throws -> MediaItem {
        let key = cacheKey(id: id, type: type)
        let mediaItem = try await fetchFromNetwork(id: id, type: type)

        let cached = CachedItem(mediaItem: mediaItem, cachedAt: Date())
        memoryCache[key] = cached
        saveToDisk(key: key, item: cached)

        return mediaItem
    }

    /// Prefetch multiple items in parallel (for continue watching section)
    func prefetch(items: [(id: String, type: String)]) async {
        await withTaskGroup(of: Void.self) { group in
            for item in items {
                group.addTask {
                    _ = try? await self.get(id: item.id, type: item.type)
                }
            }
        }
    }

    /// Clear expired cache entries (call on app launch)
    func clearExpiredCache() {
        // Clear expired memory cache
        memoryCache = memoryCache.filter { !$0.value.isExpired(duration: cacheDuration) }

        // Clear expired disk cache
        guard let files = try? FileManager.default.contentsOfDirectory(at: diskCacheDirectory, includingPropertiesForKeys: nil) else {
            return
        }

        for file in files {
            if let cached = loadFromDisk(url: file), cached.isExpired(duration: cacheDuration) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    /// Check if an item exists in cache (without loading it)
    func isCached(id: String, type: String) -> Bool {
        let key = cacheKey(id: id, type: type)

        if let cached = memoryCache[key], !cached.isExpired(duration: cacheDuration) {
            return true
        }

        if let cached = loadFromDisk(key: key), !cached.isExpired(duration: cacheDuration) {
            return true
        }

        return false
    }

    // MARK: - Private Helpers

    private func cacheKey(id: String, type: String) -> String {
        "\(type)_\(id)"
    }

    private func diskCacheURL(for key: String) -> URL {
        diskCacheDirectory.appendingPathComponent("\(key).json")
    }

    private func loadFromDisk(key: String) -> CachedItem? {
        loadFromDisk(url: diskCacheURL(for: key))
    }

    private func loadFromDisk(url: URL) -> CachedItem? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(CachedItem.self, from: data)
    }

    private func saveToDisk(key: String, item: CachedItem) {
        guard let data = try? JSONEncoder().encode(item) else { return }
        try? data.write(to: diskCacheURL(for: key))
    }

    private func fetchWithDeduplication(id: String, type: String, key: String) async throws -> MediaItem {
        // Check if there's already a request in flight for this item
        if let existingTask = inFlightRequests[key] {
            return try await existingTask.value
        }

        // Create a new task for this request
        let task = Task<MediaItem, Error> {
            let mediaItem = try await fetchFromNetwork(id: id, type: type)

            let cached = CachedItem(mediaItem: mediaItem, cachedAt: Date())
            memoryCache[key] = cached
            saveToDisk(key: key, item: cached)

            return mediaItem
        }

        inFlightRequests[key] = task

        defer {
            inFlightRequests.removeValue(forKey: key)
        }

        return try await task.value
    }

    private func fetchFromNetwork(id: String, type: String) async throws -> MediaItem {
        // Ensure addons are loaded
        if !addonManager.isLoaded {
            await addonManager.loadAddons()
        }

        return try await addonManager.fetchMeta(type: type, id: id)
    }
}
