//
//  LanguageView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-30.
//

import SwiftData
import SwiftUI

struct LanguageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [AppSettings]

    private var settings: AppSettings {
        if let existing = settingsArray.first {
            return existing
        } else {
            let newSettings = AppSettings()
            modelContext.insert(newSettings)
            return newSettings
        }
    }

    var body: some View {
        List {
            Section("Language") {
                HStack {
                    Text("Default audio language")

                    Spacer()

                    Picker("", selection: Binding(
                        get: { settings.preferredAudioLanguage },
                        set: { settings.preferredAudioLanguage = $0 }
                    )) {
                        ForEach(LanguageOption.audioLanguages) { language in
                            Text(language.name).tag(language.id)
                        }
                    }
                    .pickerStyle(.menu)
                }

                HStack {
                    Text("Default subtitle language")

                    Spacer()

                    Picker("", selection: Binding(
                        get: { settings.preferredSubtitleLanguage },
                        set: { settings.preferredSubtitleLanguage = $0 }
                    )) {
                        ForEach(LanguageOption.subtitleLanguages) { language in
                            Text(language.name).tag(language.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            Section("Playback") {
                HStack {
                    Text("Default playback speed")

                    Spacer()

                    Picker("", selection: Binding(
                        get: { settings.preferredPlaybackSpeed },
                        set: { settings.preferredPlaybackSpeed = $0 }
                    )) {
                        ForEach(PlaybackSpeedOption.speeds) { speed in
                            Text(speed.name).tag(speed.id)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
    }
}

#Preview {
    LanguageView()
        .modelContainer(for: AppSettings.self, inMemory: true)
}
