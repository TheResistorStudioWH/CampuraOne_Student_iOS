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

// MARK: - ViewModel

typealias ADSmallViewModel = LoadableListViewModel<Advertisement>

// MARK: - 小广告位

struct AD_SmallModule: View {
    @StateObject private var viewModel: ADSmallViewModel
    
    init() {
        _viewModel = StateObject(
            wrappedValue: ADSmallViewModel(loader: {
                try await RemoteDataService.shared.fetchSmallAdvertisements(
                    onlyActive: true
                )
            })
        )
    }
    
    var body: some View {
        Group {
            if !viewModel.items.isEmpty {
                ADSmallWidgetStack(
                    advertisements: viewModel.items
                )
                .id("ads-loaded")
            } else if viewModel.isLoading {
                placeholderCard {
                    ProgressView("正在加载广告…")
                }
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
                                    await viewModel.load()
                                }
                            }
                    }
                    .padding()
                }
                .id("ads-error")
            } else {
                placeholderCard {
                    ContentUnavailableView(
                        "暂无小广告",
                        systemImage: "rectangle.stack"
                    )
                }
                .id("ads-empty")
            }
        }
        .task {
            guard viewModel.items.isEmpty,
                  !viewModel.isLoading else {
                return
            }
            
            await viewModel.load()
        }
    }
    
    private func placeholderCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.quaternary)
            .aspectRatio(1.65, contentMode: .fit)
            .overlay {
                content()
            }
    }
}

// MARK: - iOS 叠放小组件式切换

private struct ADSmallWidgetStack: View {
    let advertisements: [Advertisement]
    
    @State private var selectedIndex = 0
    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false
    
    private let cardAspectRatio: CGFloat = 1.65
    private let visibleStackDepth = 3
    
    var body: some View {
        GeometryReader { proxy in
            let cardHeight = proxy.size.width / cardAspectRatio
            
            ZStack(alignment: .bottom) {
                stackTray
                    .offset(y: 10)
                    .opacity(isDragging && advertisements.count > 1 ? 1 : 0)
                    .scaleEffect(isDragging ? 1 : 0.88)
                    .animation(
                        .easeOut(duration: 0.16),
                        value: isDragging
                    )
                
                ZStack {
                    ForEach(renderedIndices.reversed(), id: \.self) { index in
                        advertisementCard(
                            advertisements[index]
                        )
                        .scaleEffect(scale(for: index, cardHeight: cardHeight))
                        .offset(y: offset(for: index, cardHeight: cardHeight))
                        .opacity(opacity(for: index, cardHeight: cardHeight))
                        .zIndex(zIndex(for: index))
                        .allowsHitTesting(index == selectedIndex)
                    }
                }
                .frame(height: cardHeight)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    stackDragGesture(cardHeight: cardHeight)
                )
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .top
            )
        }
        .aspectRatio(cardAspectRatio, contentMode: .fit)
        .onChange(of: advertisements.count) { _, newCount in
            if newCount == 0 {
                selectedIndex = 0
            } else {
                selectedIndex = min(selectedIndex, newCount - 1)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("小广告位")
        .accessibilityValue(
            "第 \(selectedIndex + 1) 张，共 \(advertisements.count) 张"
        )
    }
    
    private var renderedIndices: [Int] {
        guard !advertisements.isEmpty else {
            return []
        }
        
        let lowerBound = max(selectedIndex - 1, 0)
        let upperBound = min(
            selectedIndex + visibleStackDepth - 1,
            advertisements.count - 1
        )
        
        return Array(lowerBound...upperBound)
    }
    
    private var stackTray: some View {
        HStack(spacing: 5) {
            ForEach(advertisements.indices, id: \.self) { index in
                Capsule()
                    .fill(
                        index == selectedIndex
                        ? Color.primary
                        : Color.secondary.opacity(0.35)
                    )
                    .frame(
                        width: index == selectedIndex ? 18 : 6,
                        height: 6
                    )
                    .animation(
                        .snappy(duration: 0.18),
                        value: selectedIndex
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(
            color: .black.opacity(0.2),
            radius: 8,
            y: 3
        )
    }
    
    private func advertisementCard(
        _ advertisement: Advertisement
    ) -> some View {
        AsyncImage(url: URL(string: advertisement.img)) { phase in
            switch phase {
            case .empty:
                Rectangle()
                    .fill(.quaternary)
                    .overlay {
                        ProgressView()
                    }
                
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
                
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .background(.quaternary)
        .clipShape(
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 22,
                style: .continuous
            )
            .strokeBorder(
                .white.opacity(0.12),
                lineWidth: 1
            )
        }
        .shadow(
            color: .black.opacity(0.18),
            radius: 10,
            y: 5
        )
        .accessibilityLabel("广告 \(advertisement.adID)")
    }
    
    private func stackDragGesture(
        cardHeight: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                guard advertisements.count > 1 else {
                    return
                }
                
                isDragging = true
                
                let translation = value.translation.height
                let isPastFirst = selectedIndex == 0 && translation > 0
                let isPastLast = selectedIndex == advertisements.count - 1 && translation < 0
                
                dragTranslation = (isPastFirst || isPastLast)
                    ? translation * 0.18
                    : translation
            }
            .onEnded { value in
                guard advertisements.count > 1 else {
                    resetDragState()
                    return
                }
                
                let threshold = cardHeight * 0.2
                let predictedTranslation = value.predictedEndTranslation.height
                
                withAnimation(
                    .spring(
                        response: 0.34,
                        dampingFraction: 0.86
                    )
                ) {
                    if predictedTranslation < -threshold,
                       selectedIndex < advertisements.count - 1 {
                        selectedIndex += 1
                    } else if predictedTranslation > threshold,
                              selectedIndex > 0 {
                        selectedIndex -= 1
                    }
                    
                    resetDragState()
                }
            }
    }
    
    private func resetDragState() {
        dragTranslation = 0
        isDragging = false
    }
    
    private func relativeIndex(for index: Int) -> Int {
        index - selectedIndex
    }
    
    private func scale(
        for index: Int,
        cardHeight: CGFloat
    ) -> CGFloat {
        let relative = relativeIndex(for: index)
        let upwardProgress = min(
            max(-dragTranslation / cardHeight, 0),
            1
        )
        
        switch relative {
        case -1:
            return 1
        case 0:
            return 1 - upwardProgress * 0.025
        case 1:
            return 0.94 + upwardProgress * 0.06
        case 2:
            return 0.88 + upwardProgress * 0.06
        default:
            return 0.84
        }
    }
    
    private func offset(
        for index: Int,
        cardHeight: CGFloat
    ) -> CGFloat {
        let relative = relativeIndex(for: index)
        let upwardProgress = min(
            max(-dragTranslation / cardHeight, 0),
            1
        )
        
        switch relative {
        case -1:
            return -cardHeight + max(dragTranslation, 0)
        case 0:
            return dragTranslation
        case 1:
            return 13 * (1 - upwardProgress)
        case 2:
            return 25 - upwardProgress * 12
        default:
            return 34
        }
    }
    
    private func opacity(
        for index: Int,
        cardHeight: CGFloat
    ) -> Double {
        let relative = relativeIndex(for: index)
        
        if relative == -1 {
            let progress = min(
                max(dragTranslation / cardHeight, 0),
                1
            )
            return Double(progress)
        }
        
        return relative == 2 ? 0.72 : 1
    }
    
    private func zIndex(for index: Int) -> Double {
        let relative = relativeIndex(for: index)
        
        switch relative {
        case -1:
            return dragTranslation > 0 ? 4 : 0
        case 0:
            return 3
        case 1:
            return 2
        case 2:
            return 1
        default:
            return 0
        }
    }
}
