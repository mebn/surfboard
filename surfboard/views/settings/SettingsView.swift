//
//  SettingsView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftUI

enum SettingsCategory: String, CaseIterable, Identifiable {
    case addons = "Addons"
    case languages = "Languages"
    case subtitles = "Subtitles"

    var id: String { rawValue }
}

struct SettingsView: View {
    @State private var selectedCategory: SettingsCategory = .addons

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
}
