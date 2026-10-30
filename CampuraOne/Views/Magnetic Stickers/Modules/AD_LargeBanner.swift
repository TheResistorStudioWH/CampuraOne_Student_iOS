//
//  AD_LargeBanner.swift
//  CampuraOne
//
//  Created by Lin Shay on 06/06/2026.
//

import SwiftUI
import PetaKitUIX
import SwiftData

#Preview("app - 已登录") {
    PreviewAppView()
}

struct AD_LargeBanner: View {
    let advertisements: [Advertisement]
    
    private var activeLargeAdvertisements: [Advertisement] {
        advertisements.activeLargeAdvertisements()
    }
    
    var body: some View {
        let ads = activeLargeAdvertisements
        Group {
            if ads.isEmpty {
                placeholder.aspectRatio(3, contentMode: .fit)
            } else {
                AdvertisementPhotoStack(advertisements: ads, aspectRatio: 3)
            }
        }
        .padding(.horizontal)
    }
    
    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(Material.bar)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(alignment: .center) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .padding()
            }
        
    }
}

/// Use the same shared list loader as the small-ad module.
struct AD_LargeBannerRemoteModule: View {
    @ObservedObject private var viewModel = AdvertisementStore.shared
    private var advertisements: [Advertisement] { viewModel.items.activeLargeAdvertisements() }

    var body: some View {
        Group {
            if !advertisements.isEmpty {
                AD_LargeBanner(advertisements: advertisements)
            } else {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.quaternary)
                    .aspectRatio(3, contentMode: .fit)
                    .overlay {
                        if viewModel.isLoading {
                            ProgressView("正在加载广告…")
                        } else if viewModel.errorMessage != nil {
                            VStack(spacing: 6) {
                                Text("广告加载失败").font(.caption)
                                Text("重试").beButton { Task { await viewModel.refresh() } }
                            }
                        } else {
                            Label("暂无广告", systemImage: "photo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
            }
        }

    }
}
