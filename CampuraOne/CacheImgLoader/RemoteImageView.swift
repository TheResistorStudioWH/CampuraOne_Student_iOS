//
//  UserAvatarView.swift
//  CampuraOne
//
//  Created by LShayc1own on 25/05/2026.
//

import SwiftUI

struct RemoteImageView<Placeholder: View>: View {
    let url: URL?
    let cacheKey: String?
    var contentMode: ContentMode = .fill
    var cornerRadius: CGFloat = 0
    @ViewBuilder var placeholder: () -> Placeholder
    
    @StateObject private var loader: RemoteImageLoader
    
    init(
        url: URL?,
        cacheKey: String? = nil,
        contentMode: ContentMode = .fill,
        cornerRadius: CGFloat = 0,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.cacheKey = cacheKey
        self.contentMode = contentMode
        self.cornerRadius = cornerRadius
        self.placeholder = placeholder
        _loader = StateObject(
            wrappedValue: RemoteImageLoader(url: url, cacheKey: cacheKey)
        )
    }
    
    var body: some View {
        Group {
            if let image = loader.image {
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear {
            loader.load()
        }
        .onDisappear {
            loader.cancel()
        }
    }
}

