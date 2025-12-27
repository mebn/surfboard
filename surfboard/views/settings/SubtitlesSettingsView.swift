//
//  SubtitlesSettingsView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-27.
//

import SwiftUI
import SwiftData

struct SubtitlesSettingsView: View {
    @Bindable var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            Text("Subtitle Language")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Select your preferred subtitle language. This will be used as the default when playing media in KSPlayer.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 10) {
                ForEach(LanguageOption.subtitleLanguages) { language in
                    Button(action: {
                        settings.preferredSubtitleLanguage = language.id
                    }) {
                        HStack {
                            Text(language.name)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if settings.preferredSubtitleLanguage == language.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            settings.preferredSubtitleLanguage == language.id
                            ? Color.accentColor.opacity(0.2)
                            : Color.gray.opacity(0.1)
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
        }
        .padding(40)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: AppSettings.self, configurations: config)
    let settings = AppSettings()
    container.mainContext.insert(settings)
    
    return SubtitlesSettingsView(settings: settings)
        .modelContainer(container)
}
