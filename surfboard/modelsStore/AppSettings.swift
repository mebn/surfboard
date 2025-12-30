//
//  AppSettings.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-27.
//

import Foundation
import SwiftData

@Model
final class AppSettings {
    var torrentioBaseURL: String?
    var preferredAudioLanguage: String
    var preferredSubtitleLanguage: String
    
    init(
        torrentioBaseURL: String? = nil,
        preferredAudioLanguage: String = "en",
        preferredSubtitleLanguage: String = "en"
    ) {
        self.torrentioBaseURL = torrentioBaseURL
        self.preferredAudioLanguage = preferredAudioLanguage
        self.preferredSubtitleLanguage = preferredSubtitleLanguage
    }
}

struct LanguageOption: Identifiable, Hashable {
    let id: String // ISO 639-1 code
    let name: String
    
    static let audioLanguages: [LanguageOption] = [
        LanguageOption(id: "en", name: "English"),
        LanguageOption(id: "sv", name: "Swedish"),
        LanguageOption(id: "de", name: "German"),
        LanguageOption(id: "fr", name: "French"),
        LanguageOption(id: "es", name: "Spanish"),
        LanguageOption(id: "it", name: "Italian"),
        LanguageOption(id: "pt", name: "Portuguese"),
        LanguageOption(id: "ru", name: "Russian"),
        LanguageOption(id: "ja", name: "Japanese"),
        LanguageOption(id: "ko", name: "Korean"),
        LanguageOption(id: "zh", name: "Chinese"),
    ]
    
    static let subtitleLanguages: [LanguageOption] = [
        LanguageOption(id: "none", name: "None"),
        LanguageOption(id: "en", name: "English"),
        LanguageOption(id: "sv", name: "Swedish"),
        LanguageOption(id: "de", name: "German"),
        LanguageOption(id: "fr", name: "French"),
        LanguageOption(id: "es", name: "Spanish"),
        LanguageOption(id: "it", name: "Italian"),
        LanguageOption(id: "pt", name: "Portuguese"),
        LanguageOption(id: "ru", name: "Russian"),
        LanguageOption(id: "ja", name: "Japanese"),
        LanguageOption(id: "ko", name: "Korean"),
        LanguageOption(id: "zh", name: "Chinese"),
    ]
}
