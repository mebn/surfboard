//
//  MediaCard.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftUI

struct MediaCard: View {
    let item: MediaItem
    
    let radius: CGFloat = 64
    
    var body: some View {
        NavigationLink(destination: SingleMediaView(itemId: item.id, itemType: item.type)) {
            CachedImage(
                url: item.posterURL,
                aspectRatio: 250 / 375,
                cornerRadius: radius
            )
            .hoverEffect(.highlight)
        
            Text(item.name)
                .lineLimit(1)
        
            HStack(alignment: .center, spacing: 12) {
                Text(item.year ?? "")
            
                if item.year != nil || item.imdbRating != nil {
                    Text("|")
                }
                
                Text(item.imdbRating ?? "")
            }
            .foregroundColor(.secondary)
        }
        .buttonStyle(.borderless)
        .buttonBorderShape(.roundedRectangle(radius: radius))
    }
}

#Preview {
    MediaCard(item: .preview(poster: "https://images.metahub.space/poster/medium/tt0111161/img"))
}
