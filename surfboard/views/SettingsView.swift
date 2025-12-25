//
//  HomeView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        Text("SettingView")
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Item.self, inMemory: true)
}
