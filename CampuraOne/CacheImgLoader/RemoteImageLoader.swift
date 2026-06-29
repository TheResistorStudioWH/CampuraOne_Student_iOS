//
//  RemoteImageLoader.swift
//  CampuraOne
//
//  Created by LShayc1own on 25/05/2026.
//

import SwiftUI
import Alamofire
import Combine

@MainActor
final class RemoteImageLoader: ObservableObject {
    
    @Published var image: Image?
    @Published var isLoading = false
    @Published var loadFailed = false
    
    private let url: URL?
    private let cacheKey: String?
    private var request: DataRequest?
    
    init(url: URL?, cacheKey: String? = nil) {
        self.url = url
        self.cacheKey = cacheKey
    }
    
    func load() {
        guard !isLoading else { return }
        guard image == nil else { return }
        
        guard let url else {
            withAnimation {
                loadFailed = true
            }
            return
        }
        
        if let cachedUIImage = cachedImage(for: url) {
            withAnimation {
                image = Image(uiImage: cachedUIImage)
                loadFailed = false
            }
            return
        }
        
        withAnimation {
            isLoading = true
            loadFailed = false
        }
        
        request = AF.request(url)
            .validate(statusCode: 200..<300)
            .responseData { [weak self] response in
                Task { @MainActor in
                    guard let self else { return }
                    
                    withAnimation {
                        self.isLoading = false
                    }
                    
                    switch response.result {
                    case .success(let data):
                        guard let uiImage = UIImage(data: data) else {
                            withAnimation {
                                self.loadFailed = true
                            }
                            return
                        }
                        
                        self.cacheImage(uiImage, for: url)
                        
                        withAnimation {
                            self.image = Image(uiImage: uiImage)
                            self.loadFailed = false
                        }
                        
                    case .failure:
                        withAnimation {
                            self.loadFailed = true
                        }
                    }
                }
            }
    }
    
    func cancel() {
        request?.cancel()
        request = nil
    }
    
    private func cachedImage(for url: URL) -> UIImage? {
        if let cacheKey {
            return RemoteImageCache.shared.image(for: cacheKey, url: url)
        } else {
            return RemoteImageCache.shared.image(for: url)
        }
    }
    
    private func cacheImage(_ image: UIImage, for url: URL) {
        if let cacheKey {
            RemoteImageCache.shared.setImage(image, for: cacheKey, url: url)
        } else {
            RemoteImageCache.shared.setImage(image, for: url)
        }
    }
}

// 兼容旧代码：之前头像专用的 AvatarLoader 现在指向通用图片加载器。
typealias AvatarLoader = RemoteImageLoader
