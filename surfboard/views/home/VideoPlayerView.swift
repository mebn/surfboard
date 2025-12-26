//
//  VideoPlayerView.swift
//  surfboard
//
//  Created by Marcus Nilszén on 2025-12-26.
//

import SwiftUI
import KSPlayer

struct VideoPlayerView: View {
    let url: URL
    let title: String
    
    var body: some View {
        KSVideoPlayerView(url: url, options: KSOptions())
            .ignoresSafeArea()
    }
}

#Preview {
    VideoPlayerView(
        url: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!,
        title: "Sample Video"
    )
}
