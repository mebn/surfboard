//
//  MediaCard.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-25.
//

import SwiftUI

struct MediaCard: View {
    let item: MediaItem
    
    var body: some View {
        AsyncImage(url: item.posterURL) { image in
            image
                .resizable()
        } placeholder: {
            ProgressView()
        }
        .aspectRatio(250 / 375, contentMode: .fit)
    }
}

#Preview {
    MediaCard(item: MediaItem(id: "tt0111161", type: "movie", name: "The Shawshank Redemption", poster: "https://images.metahub.space/poster/medium/tt0111161/img"))
}
