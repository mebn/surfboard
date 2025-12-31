//
//  ContinueWatchingSection.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-27.
//

import SwiftUI
import SwiftData
import KSPlayer

struct ContinueWatchingSection: View {
    @Query(sort: \WatchProgress.updatedAt, order: .reverse) private var watchProgress: [WatchProgress]
    @State private var selectedProgress: WatchProgress?
    
    var body: some View {
        if !watchProgress.isEmpty {
            VStack(alignment: .leading) {
                Section("Continue Watching") {
                    ScrollView(.horizontal) {
                        HStack(spacing: 40) {
                            ForEach(watchProgress) { progress in
                                ContinueWatchingCard(progress: progress)
                                    .containerRelativeFrame(.horizontal, count: 5, spacing: 40)
                            }
                        }
                    }
                }
            }
            .scrollClipDisabled()
        }
    }
}

#Preview {
    ContinueWatchingSection()
        .modelContainer(for: WatchProgress.self, inMemory: true)
}
