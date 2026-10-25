//
//  AD_Small.swift
//  CampuraOne
//
//  Created by LShayc1own on 25/05/2026.
//

import SwiftUI
import SwiftData

#Preview("app - 已登录") {
    ContentView()
        .modelContainer(PreviewContainer.app)
}

struct AD_SmallModule: View {
    @ObservedObject private var viewModel = AdvertisementStore.shared
    private var advertisements: [Advertisement] {
        viewModel.items.activeSmallAdvertisements()
    }

    var body: some View {
        Group {
            if !advertisements.isEmpty {
                AdvertisementPhotoStack(advertisements: advertisements, aspectRatio: 1)
                    .id("ads-loaded")
            } else if viewModel.isLoading {
                placeholderCard { ProgressView("正在加载广告…") }
                    .id("ads-loading")
            } else if let errorMessage = viewModel.errorMessage {
                placeholderCard {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title2)
                        Text("广告加载失败")
                            .font(.headline)
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        Text("重新加载")
                            .beButton {
                                Task {
                                    await viewModel.refresh()
                                }
                            }
                    }
                    .padding()
                }
                .id("ads-error")
            } else {
                placeholderCard {
                    ContentUnavailableView("暂无小广告", systemImage: "rectangle.stack")
                }
                .id("ads-empty")
            }
        }
    }

    private func placeholderCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.quaternary)
            .aspectRatio(1, contentMode: .fit)
            .overlay { content() }
    }
}
