//
//  SettingsView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftUI
import SwiftData

enum SettingsCategory: String, CaseIterable, Identifiable {
    case addons = "Addons"
    case languages = "Languages"
    case subtitles = "Subtitles"
    
    var id: String { rawValue }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [AppSettings]
    
    @State private var selectedCategory: SettingsCategory = .addons
    @State private var torrentioURL: String = ""
    @State private var localAudioLang: String = ""
    @State private var localSubtitleLang: String = ""
    
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
        Form {
            Section("Addons") {
                HStack(alignment: .center) {
                    Text("Torrentio Base URL")
                        .font(.caption)
                    
                    Spacer()
                    
                    TextField("", text: $torrentioURL)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .onAppear {
                            let envURL = Bundle.main.infoDictionary?["TORRENTIO_BASE_URL"] as? String ?? ""
                            torrentioURL = settings.torrentioBaseURL ?? envURL
                        }
                        .onChange(of: torrentioURL) { _, newValue in
                            settings.torrentioBaseURL = newValue.isEmpty ? nil : newValue
                        }
                }
            }
            
            Section("Language") {
                HStack(alignment: .center) {
                    Text("Default audio language")
                        .font(.caption)
                    
                    Spacer()
                    
                    Picker("Default audio language", selection: $localAudioLang) {
                        ForEach(LanguageOption.audioLanguages) { language in
                            Text(language.name).tag(language.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .onAppear {
                        localAudioLang = settings.preferredAudioLanguage
                    }
                    .onChange(of: localAudioLang) { _, newValue in
                        settings.preferredAudioLanguage = newValue
                    }
                }
                
                HStack(alignment: .center) {
                    Text("Default subtitle language")
                        .font(.caption)
                    
                    Spacer()
                    
                    Picker("Default subtitle language", selection: $localSubtitleLang) {
                        ForEach(LanguageOption.subtitleLanguages) { language in
                            Text(language.name).tag(language.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .onAppear {
                        localSubtitleLang = settings.preferredSubtitleLanguage
                    }
                    .onChange(of: localSubtitleLang) { _, newValue in
                        settings.preferredSubtitleLanguage = newValue
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: AppSettings.self, inMemory: true)
}
