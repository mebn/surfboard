//
//  ContentView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftData
import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            TabView {
                Tab("Home", systemImage: "house.fill") {
                    HomeView()
                }

                Tab("Search", systemImage: "magnifyingglass") {
                    SearchView()
                }

                Tab("Library", systemImage: "rectangle.stack.fill") {
                    LibraryView()
                }

                Tab("Settings", systemImage: "gearshape.fill") {
                    SettingsView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
