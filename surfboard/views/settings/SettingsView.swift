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
            Section("General") {
                NavigationLink(destination: AddonsView()) {
                    Text("Addons")
                }
                
                NavigationLink(destination: LanguageView()) {
                    Text("Languages and subtitles")
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: AppSettings.self, inMemory: true)
}
