//
//  AD_LargeBanner.swift
//  CampuraOne
//
//  Created by Lin Shay on 06/06/2026.
//

import SwiftUI
import SwiftData

#Preview("app - 已登录") {
    
    @Previewable @StateObject var authSession = AuthSession()
    
    AppRootView()
        .environmentObject(authSession)
        .modelContainer(for: [
            School.self,
            Campus.self,
            SchoolCalendar.self,
            CourseTable.self,
            AppUser.self,
            Student.self
        ])
}

struct AD_LargeBanner: View {
    let advertisements: [Advertisement]
    @State private var selection: Int?
    
    private var activeLargeAdvertisements: [Advertisement] {
        advertisements.activeLargeAdvertisements()
    }
    
    init(advertisements: [Advertisement]) {
        self.advertisements = advertisements
        _selection = State(initialValue: advertisements.activeLargeAdvertisements().first?.adID)
    }
    
    var body: some View {
        let ads = activeLargeAdvertisements
        let ids = ads.map(\.adID)
        // Derive height from the available width, not the device's screen width.
        GeometryReader { proxy in
            if ads.isEmpty {
                placeholder
            } else {
                TabView(selection: Binding(
                    get: { selection.flatMap { ids.contains($0) ? $0 : nil } ?? ids.first },
                    set: { selection = $0 }
                )) {
                    ForEach(ads) { advertisement in
                        AsyncImage(url: advertisement.imageURL, scale: 1, transaction: .init(animation: .spring), content: { phase in
                            switch phase {
                            case .empty:
                                    placeholder
                                
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFit()
                                
                            case .failure:
                                Rectangle()
                                    .fill(.quaternary)
                                    .overlay {
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.badge.exclamationmark")
                                                .font(.title2)
                                            
                                            Text("广告图片加载失败")
                                                .font(.caption)
                                        }
                                        .foregroundStyle(.secondary)
                                    }
                                
                            @unknown default:
                                Rectangle()
                                    .fill(.quaternary)
                            }
                        })
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .tag(Optional(advertisement.adID))
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
        }
        .aspectRatio(3, contentMode: .fit)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        // Keep page indicators outside the artwork so promotional text stays legible.
        .overlay(alignment: .bottom) {
            if ads.count > 1 {
                HStack(spacing: 5) {
                    ForEach(ids, id: \.self) { id in
                        Circle()
                            .fill((selection ?? ids.first) == id ? Color.primary : Color.secondary.opacity(0.35))
                            .frame(width: 5, height: 5)
                    }
                }
                .accessibilityHidden(true)
                .offset(y: 12)
            }
        }
        .padding(.bottom, ads.count > 1 ? 16 : 0)
        .padding(.horizontal)
        .onChange(of: ids, initial: true) { _, newIDs in
            if selection == nil || !newIDs.contains(selection!) {
                selection = newIDs.first
            }
        }
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
    @StateObject private var viewModel = LoadableListViewModel<Advertisement>(loader: {
        try await RemoteDataService.shared.fetchLargeAdvertisements(onlyActive: true)
    })

    var body: some View {
        Group {
            if !viewModel.items.isEmpty {
                AD_LargeBanner(advertisements: viewModel.items)
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
                                Button("重试") { Task { await viewModel.load() } }
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
        .task {
            guard viewModel.items.isEmpty, !viewModel.isLoading else { return }
            await viewModel.load()
        }
    }
}
