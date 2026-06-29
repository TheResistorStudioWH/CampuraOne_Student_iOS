//
//  SalesTimeLine.swift
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

#Preview("app - 未登录") {
    ContentView()
        .modelContainer(PreviewContainer.empty)
}

enum SalesTimelineMode: String, CaseIterable, Identifiable {
    case hot
    case random
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
            case .hot:
                return "热榜"
            case .random:
                return "随机"
        }
    }
    
    var systemImage: String {
        switch self {
            case .hot:
                return "flame.fill"
            case .random:
                return "shuffle"
        }
    }
    
    var primaryColor: Color {
        switch self {
            case .hot:
                return .red
            case .random:
                return .green
        }
    }
}

typealias SalesTimelineViewModel = LoadableListViewModel<SaleEvent>
typealias SalesTimelineProductViewModel = LoadableListViewModel<Product>

struct SalesTimeLineModule: View {
    @Binding var mode: SalesTimelineMode
    let refreshID: Int
    
    @StateObject private var viewModel: SalesTimelineViewModel
    @State private var randomSaleIDs: [Int] = []
    
    init(
        mode: Binding<SalesTimelineMode> = .constant(.random),
        refreshID: Int = 0
    ) {
        self._mode = mode
        self.refreshID = refreshID
        self._viewModel = StateObject(
            wrappedValue: SalesTimelineViewModel(loader: {
                try await RemoteDataService.shared.fetchPromotionEvents(
                    onlyActive: true
                )
            })
        )
    }
    
    private var displayedEvents: [SaleEvent] {
        switch mode {
        case .hot:
            // 热度接口接入前，先按“即将结束”排序占位。
            return viewModel.items.sorted {
                ($0.endTime ?? .distantFuture) < ($1.endTime ?? .distantFuture)
            }
        case .random:
            let eventsByID = Dictionary(
                uniqueKeysWithValues: viewModel.items.map { ($0.saleID, $0) }
            )
            return randomSaleIDs.compactMap { eventsByID[$0] }
        }
    }
    
    var body: some View {
        moduleContent
            .task {
                guard viewModel.items.isEmpty,
                      !viewModel.isLoading else {
                    return
                }
                
                await reload()
            }
            .onChange(of: mode) { _, newMode in
                if newMode == .random {
                    reshuffle()
                }
            }
            .onChange(of: refreshID) { _, _ in
                Task {
                    await reload()
                }
            }
    }

    @ViewBuilder
    private var moduleContent: some View {
        if !viewModel.items.isEmpty {
            compactContent
        } else if viewModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewModel.errorMessage {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.title3)
                
                Text("促销加载失败")
                    .font(.caption.bold())
                
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                
                Text("重新加载")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                    .beButton {
                        Task {
                            await reload()
                        }
                    }
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "暂无促销",
                systemImage: "tag"
            )
        }
    }
    
    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 7) {
            ForEach(Array(displayedEvents.prefix(3).enumerated()), id: \.element.saleID) { index, event in
                SalesTimelineCompactRow(
                    event: event,
                    rank: mode == .hot ? index + 1 : nil
                )
            }
            
            Spacer()
            
            if displayedEvents.count > 3 {
                Text("还有 \(displayedEvents.count - 3) 项促销，查看更多…")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    @MainActor
    private func reload() async {
        await viewModel.load()
        reshuffle()
    }
    
    @MainActor
    private func reshuffle() {
        randomSaleIDs = viewModel.items
            .map(\.saleID)
            .shuffled()
    }
}

private struct SalesTimelineCompactRow: View {
    let event: SaleEvent
    let rank: Int?
    
    @StateObject private var productViewModel: SalesTimelineProductViewModel
    
    init(
        event: SaleEvent,
        rank: Int?
    ) {
        self.event = event
        self.rank = rank
        
        _productViewModel = StateObject(
            wrappedValue: SalesTimelineProductViewModel(loader: {
                guard let productID = event.productID else {
                    return []
                }
                
                let product = try await RemoteDataService.shared.fetchProduct(
                    productID: productID
                )
                
                return [product]
            })
        )
    }
    
    private var product: Product? {
        productViewModel.items.first
    }
    
    private var categoryIcon: String {
        product?.category?.categoryIcon ?? "tag.fill"
    }
    
    private var categoryColor: Color {
        switch product?.category?.categoryColor?.lowercased() {
        case "brown":
            return .brown
        case "orange":
            return .orange
        case "red":
            return .red
        case "pink":
            return .pink
        case "green":
            return .green
        case "blue":
            return .blue
        case "purple":
            return .purple
        case "cyan":
            return .cyan
        case "mint":
            return .mint
        case "yellow":
            return .yellow
        case "gray", "grey":
            return .gray
        default:
            return .blue
        }
    }
    
    
    var body: some View {
        HStack {
            
           salesLabel()
            
            VStack(alignment: .leading, spacing: 2.5) {
                Text(event.saleRule ?? "促销活动")
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                
                VStack {
                    if let product,
                       let productCategory = product.category {
                        Text("\(productCategory.categoryName)·\(product.productName)")
                    } else {
                        Text("商品…")
                    }
                }
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                
                
                Text(event.remainingText)
                    .font(.footnote)
                    .foregroundStyle(event.remainingColor)
            }
            
        }
        .task {
            guard event.productID != nil,
                  productViewModel.items.isEmpty,
                  !productViewModel.isLoading else {
                return
            }
            
            await productViewModel.load()
        }
    }
    
    
    @ViewBuilder func salesLabel() -> some View {
        VStack {
            if let rank {
                VStack {
                    switch rank {
                        case 1:
                            Text("\(rank)")
                                .foregroundStyle(rank <= 3 ? .red : .secondary)
                        case 2:
                            Text("\(rank)")
                                .foregroundStyle(rank <= 3 ? .orange : .secondary)
                        case 3:
                            Text("\(rank)")
                                .foregroundStyle(rank <= 3 ? .yellow : .secondary)
                        default:
                            Text("\(rank)")
                                .foregroundStyle(rank <= 3 ? .yellow : .secondary)
                    }
                }
                    .font(.title3.bold())
                    .frame(width: screen.width/18, height: screen.width/18)
            } else if productViewModel.isLoading {
                ProgressView()
                    .controlSize(.mini)
                    .frame(width: screen.width/18, height: screen.width/18)
            } else {
                Image(systemName: categoryIcon)
                    .font(.headline)
                    .frame(width: screen.width/18, height: screen.width/18)
                    .foregroundStyle(categoryColor)
            }
            
        }
        .padding(.trailing, 3)
    }
}



private extension SaleEvent {
    var remainingText: String {
        guard let endTime else {
            return "长期有效"
        }
        
        let remaining = endTime.timeIntervalSinceNow
        guard remaining > 0 else {
            return "已结束"
        }
        
        let day = Int(ceil(remaining / 86_400))
        return day <= 1 ? "即将结束" : "剩余 \(day) 天"
    }
    
    var remainingColor: Color {
        guard let endTime else {
            return .green
        }
        
        let remaining = endTime.timeIntervalSinceNow
        guard remaining > 0 else {
            return .red
        }
        
        let total = endTime.timeIntervalSince(startTime)
        guard total > 0 else {
            return .red
        }
        
        let ratio = remaining / total
        if ratio <= 1.0 / 3.0 {
            return .red
        } else if ratio <= 0.5 {
            return .yellow
        } else {
            return .green
        }
    }
}
