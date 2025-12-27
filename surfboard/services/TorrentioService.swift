//
//  TorrentioService.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-26.
//

import Foundation
import SwiftData

class TorrentioService {
    static let shared = TorrentioService()
    
    private let secretsBaseURL: String
    private var customBaseURL: String?
    
    private init() {
        secretsBaseURL = Bundle.main.object(forInfoDictionaryKey: "TORRENTIO_BASE_URL") as? String ?? ""
    }
    
    /// Updates the custom base URL from SwiftData settings
    func updateBaseURL(from settings: AppSettings?) {
        customBaseURL = settings?.torrentioBaseURL
    }
    
    /// Sets a custom base URL directly
    func setCustomBaseURL(_ url: String?) {
        customBaseURL = url
    }
    
    /// Gets the effective base URL (custom > secrets > empty)
    var effectiveBaseURL: String {
        if let custom = customBaseURL, !custom.isEmpty {
            return custom
        }
        return secretsBaseURL
    }
    
    func fetchStreams(type: String, id: String) async throws -> [TorrentStream] {
        let urlString = "\(effectiveBaseURL)/stream/\(type)/\(id).json"
        
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
