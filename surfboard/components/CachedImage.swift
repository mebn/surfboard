//
//  CachedImage.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-01-07.
//

import SwiftUI
import Kingfisher

/// A wrapper around Kingfisher's KFImage for consistent image loading with caching
struct CachedImage: View {
    let url: URL?
    var aspectRatio: CGFloat? = nil
    var cornerRadius: CGFloat = 0
    var contentMode: SwiftUI.ContentMode = .fit
    
    var body: some View {
        KFImage(url)
            .placeholder {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        ProgressView()
                    }
            }
            .retry(maxCount: 3, interval: .seconds(1))
            .fade(duration: 0.2)
            .resizable()
            .aspectRatio(aspectRatio, contentMode: contentMode)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// Variant for background images (fill mode, no corner radius by default)
struct CachedBackgroundImage: View {
    let url: URL?
    
    var body: some View {
        KFImage(url)
            .placeholder {
                Color.black
            }
            .retry(maxCount: 2, interval: .seconds(1))
            .fade(duration: 0.3)
            .resizable()
            .aspectRatio(contentMode: .fill)
    }
}

/// Variant for thumbnail images with fixed size
struct CachedThumbnail: View {
    let url: URL?
    let width: CGFloat
    let height: CGFloat
    var cornerRadius: CGFloat = 10
    
    var body: some View {
        KFImage(url)
            .placeholder {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay {
                        ProgressView()
                    }
            }
            .retry(maxCount: 2, interval: .seconds(1))
            .fade(duration: 0.2)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

#Preview {
    VStack {
        CachedImage(
            url: URL(string: "https://images.metahub.space/poster/medium/tt0111161/img"),
            aspectRatio: 250/375,
            cornerRadius: 20
        )
        .frame(width: 200)
    }
}
