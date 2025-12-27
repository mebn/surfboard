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
    
    var icon: String {
        switch self {
        case .addons: return "puzzlepiece.extension"
        case .languages: return "globe"
        case .subtitles: return "captions.bubble"
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [AppSettings]
    @State private var selectedCategory: SettingsCategory = .addons
    
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
        HStack(spacing: 0) {
            // Left sidebar - Categories
            VStack(alignment: .leading, spacing: 0) {
                Text("Settings")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.horizontal, 30)
                    .padding(.top, 40)
                    .padding(.bottom, 30)
                
                ForEach(SettingsCategory.allCases) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        HStack(spacing: 15) {
                            Image(systemName: category.icon)
                                .font(.title3)
                                .frame(width: 30)
                            
                            Text(category.rawValue)
                                .font(.body)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 30)
                        .padding(.vertical, 15)
                        .background(
                            selectedCategory == category
                            ? Color.accentColor.opacity(0.3)
                            : Color.clear
                        )
                        .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 10)
                }
                
                Spacer()
            }
            .frame(width: 300)
            .background(Color.gray.opacity(0.1))
            
            // Right content area
            VStack {
                switch selectedCategory {
                case .addons:
                    AddonsSettingsView(settings: settings)
                case .languages:
                    LanguagesSettingsView(settings: settings)
                case .subtitles:
                    SubtitlesSettingsView(settings: settings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: AppSettings.self, inMemory: true)
}
