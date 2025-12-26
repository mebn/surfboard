//
//  SingleMediaView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftUI

struct SingleMediaView: View {
    let item: MediaItem
    
    var body: some View {
        VStack(spacing: 40) {
            MediaCard(item: item)
            
            Text(item.name)
                .font(.title)
            
            NavigationLink(destination: SourcesView(item: item)) {
                Text("Play")
            }
        }
        .padding(60)
        .toolbar(.hidden, for: .tabBar)
    }
}

#Preview {
    SingleMediaView(item: .preview(poster: "https://images.metahub.space/poster/medium/tt0111161/img"))
}
