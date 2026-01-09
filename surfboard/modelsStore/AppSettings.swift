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
    var preferredAudioLanguage: String
    var preferredSubtitleLanguage: String
    var preferredPlaybackSpeed: Float

    init(
        preferredAudioLanguage: String = "en",
        preferredSubtitleLanguage: String = "en",
        preferredPlaybackSpeed: Float = 1.0
    ) {
        self.preferredAudioLanguage = preferredAudioLanguage
        self.preferredSubtitleLanguage = preferredSubtitleLanguage
        self.preferredPlaybackSpeed = preferredPlaybackSpeed
    }
}

struct PlaybackSpeedOption: Identifiable, Hashable {
    let id: Float
    let name: String

    static let speeds: [PlaybackSpeedOption] = [
        PlaybackSpeedOption(id: 0.5, name: "0.5x"),
        PlaybackSpeedOption(id: 0.75, name: "0.75x"),
        PlaybackSpeedOption(id: 1.0, name: "Normal"),
        PlaybackSpeedOption(id: 1.25, name: "1.25x"),
        PlaybackSpeedOption(id: 1.5, name: "1.5x"),
        PlaybackSpeedOption(id: 2.0, name: "2x"),
    ]
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
