//
//  CachedImage.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-01-07.
//

import Kingfisher
import SwiftUI

/// A wrapper around Kingfisher's KFImage for consistent image loading with caching
struct CachedImage: View {
    let url: URL?
    var cornerRadius: CGFloat = 0 // not used

    var aspectRatio: CGFloat?
    var width: CGFloat?

    /// Aspect ratio instead of specified width
    init(url: URL?, aspectRatio: CGFloat?) {
        self.url = url
        self.aspectRatio = aspectRatio
    }

    /// Specify width, auto adjust height
    init(url: URL?, width: CGFloat?) {
        self.url = url
        self.width = width
    }

    var body: some View {
        if aspectRatio != nil {
            Base(url: url)
                .aspectRatio(aspectRatio, contentMode: .fit)
        }

        if width != nil {
            Base(url: url)
                .aspectRatio(contentMode: .fit)
                .frame(width: width)
        }
    }
}

private struct Base: View {
    let url: URL?

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
