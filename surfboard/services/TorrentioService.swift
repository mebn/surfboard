//
//  TorrentioService.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-26.
//

import Foundation

class TorrentioService {
    static let shared = TorrentioService()
    
    private let baseURL: String
    
    private init() {
        baseURL = Bundle.main.object(forInfoDictionaryKey: "TORRENTIO_BASE_URL") as? String ?? ""
    }
    
    func fetchStreams(type: String, id: String) async throws -> [TorrentStream] {
        let urlString = "\(baseURL)/stream/\(type)/\(id).json"
        
        guard let url = URL(string: urlString) else {
            throw TorrentioError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TorrentioError.requestFailed
        }
        
        let streamResponse = try JSONDecoder().decode(TorrentioStreamResponse.self, from: data)
        return streamResponse.streams
    }
}

enum TorrentioError: Error, LocalizedError {
    case invalidURL
    case requestFailed
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .requestFailed:
            return "Request failed"
        case .decodingFailed:
            return "Failed to decode response"
        }
    }
}
