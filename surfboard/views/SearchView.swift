//
//  HomeView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        Text("SearchView")
    }
}

#Preview {
    SearchView()
        .modelContainer(for: Item.self, inMemory: true)
}
