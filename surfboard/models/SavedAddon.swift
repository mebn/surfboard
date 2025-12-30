//
//  SavedAddon.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-30.
//

import Foundation
import SwiftData

@Model
final class SavedAddon {
    var url: String
    var createdAt: Date
    
    init(url: String, createdAt: Date = Date()) {
        self.url = url
        self.createdAt = createdAt
    }
}
