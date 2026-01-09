//
//  surfboardApp.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftData
import SwiftUI

@main
struct surfboardApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            AppSettings.self,
            MediaRecord.self,
            SavedAddon.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Clear expired metadata cache on launch
                    await MediaMetadataCache.shared.clearExpiredCache()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
