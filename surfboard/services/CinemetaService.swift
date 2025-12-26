//
//  CinemetaService.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import Foundation

class CinemetaService {
    static let shared = CinemetaService()
    
    private let baseURL = "https://v3-cinemeta.strem.io"
    
    private init() {}
    
    func fetchPopularMovies() async throws -> [MediaItem] {
        let url = URL(string: "\(baseURL)/catalog/movie/top/skip=0.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(CinemetaCatalogResponse.self, from: data)
        return response.metas
    }
    
    func fetchPopularTVShows() async throws -> [MediaItem] {
        let url = URL(string: "\(baseURL)/catalog/series/top/skip=0.json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(CinemetaCatalogResponse.self, from: data)
        return response.metas
    }
    
    func searchMovies(query: String) async throws -> [MediaItem] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }
        let url = URL(string: "\(baseURL)/catalog/movie/top/search=\(encodedQuery).json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(CinemetaCatalogResponse.self, from: data)
        return response.metas
    }
    
    func searchSeries(query: String) async throws -> [MediaItem] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }
        let url = URL(string: "\(baseURL)/catalog/series/top/search=\(encodedQuery).json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(CinemetaCatalogResponse.self, from: data)
        return response.metas
    }
    
    func fetchMediaDetails(type: String, id: String) async throws -> MediaItem {
        let url = URL(string: "\(baseURL)/meta/\(type)/\(id).json")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(CinemetaMetaResponse.self, from: data)
        return response.meta
    }
}
