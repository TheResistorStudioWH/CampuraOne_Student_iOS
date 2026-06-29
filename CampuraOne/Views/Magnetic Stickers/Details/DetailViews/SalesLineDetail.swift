//
//  SalesLineDetail.swift
//  CampuraOne
//
//  Created by Lin Shay on 15/06/2026.
//

import SwiftUI
import SwiftData

#Preview("app - 已登录") {
    ContentView()
        .modelContainer(PreviewContainer.app)
}

struct SalesTimeLineDetailView: View {
    @State var mode: SalesTimelineMode
    @State var refreshID = 0
    @State var randomSaleIDs: [Int] = []
    
    @StateObject private var viewModel: LoadableListViewModel<SaleEvent>
    
    init(initialMode: SalesTimelineMode = .random) {
        _mode = State(initialValue: initialMode)
        _viewModel = StateObject(
            wrappedValue: LoadableListViewModel<SaleEvent>(loader: {
                try await RemoteDataService.shared.fetchPromotionEvents(
                    onlyActive: true
                )
            })
        )
    }
    
    private var displayedEvents: [SaleEvent] {
        switch mode {
        case .hot:
            ///真实热度字段接入前，暂时用“越接近结束越靠前”占位。
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
        VStack(spacing: 14) {
            modePicker
            content
        }
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
    
    private var modePicker: some View {
        HStack(spacing: 8) {
            ForEach(SalesTimelineMode.allCases) { option in
                Button {
                    if mode == option {
                        refreshID += 1
                        TapSucceed()
                    } else {
                        withAnimation(.snappy) {
                            mode = option
                        }
                        TapSoft()
                    }
                } label: {
                    Label(option.title, systemImage: option.systemImage)
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .foregroundStyle(
                            mode == option
                            ? Color.primary
                            : Color.secondary
                        )
                        .background {
                            RoundedRectangle(
                                cornerRadius: 12,
                                style: .continuous
                            )
                            .fill(
                                mode == option
                                ? Material.regular
                                : Material.ultraThin
                            )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityHint(
                    mode == option
                    ? "再次点击可刷新当前榜单"
                    : "切换到\(option.title)"
                )
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        if !viewModel.items.isEmpty {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(
                        Array(displayedEvents.enumerated()),
                        id: \.element.saleID
                    ) { index, event in
                        SalesTimelineDetailRow(
                            event: event,
                            rank: mode == .hot ? index + 1 : nil
                        )
                    }
                }
                .padding(.bottom, 8)
            }
            .scrollIndicators(.hidden)
        } else if viewModel.isLoading {
            VStack(spacing: 10) {
                ProgressView()
                Text("正在加载促销…")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = viewModel.errorMessage {
            ContentUnavailableView {
                Label(
                    "促销加载失败",
                    systemImage: "exclamationmark.triangle"
                )
            } description: {
                Text(errorMessage)
            } actions: {
                Button("重新加载") {
                    refreshID += 1
                }
            }
        } else {
            ContentUnavailableView(
                "暂无促销",
                systemImage: "tag"
            )
        }
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

struct SalesTimelineDetailRow: View {
    let event: SaleEvent
    let rank: Int?
    
    @StateObject private var productViewModel: LoadableListViewModel<Product>
    
    init(
        event: SaleEvent,
        rank: Int?
    ) {
        self.event = event
        self.rank = rank
        
        _productViewModel = StateObject(
            wrappedValue: LoadableListViewModel<Product>(loader: {
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
        HStack(alignment: .top, spacing: 12) {
            leadingIcon
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(product?.productName ?? event.saleRule ?? "促销活动")
                        .font(.headline)
                        .lineLimit(2)
                    
                    Spacer(minLength: 8)
                    
                    Text(event.remainingText)
                        .font(.caption.bold())
                        .foregroundStyle(event.remainingColor)
                }
                
                if let categoryName = product?.category?.categoryName {
                    Label(categoryName, systemImage: categoryIcon)
                        .font(.subheadline)
                        .foregroundStyle(categoryColor)
                }
                
                if let saleRule = event.saleRule {
                    Text(saleRule)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                HStack(spacing: 6) {
                    Text(
                        event.startTime.formatted(
                            date: .abbreviated,
                            time: .omitted
                        )
                    )
                    
                    Image(systemName: "arrow.right")
                    
                    Text(
                        event.endTime?.formatted(
                            date: .abbreviated,
                            time: .omitted
                        ) ?? "长期有效"
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .fill(.quaternary)
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
    
    @ViewBuilder
    private var leadingIcon: some View {
        if let rank {
            Text("#\(rank)")
                .font(.subheadline.bold())
                .foregroundStyle(rank <= 3 ? .orange : .secondary)
                .frame(width: 34, height: 34)
                .background(.thinMaterial, in: Circle())
        } else if productViewModel.isLoading {
            ProgressView()
                .controlSize(.small)
                .frame(width: 34, height: 34)
                .background(.thinMaterial, in: Circle())
        } else {
            Image(systemName: categoryIcon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(categoryColor)
                .frame(width: 34, height: 34)
                .background(.thinMaterial, in: Circle())
                .contentTransition(.symbolEffect(.replace))
        }
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
        
        if remaining < 3_600 {
            let minutes = max(Int(ceil(remaining / 60)), 1)
            return "剩余 \(minutes) 分钟"
        }
        
        if remaining < 86_400 {
            let hours = max(Int(ceil(remaining / 3_600)), 1)
            return "剩余 \(hours) 小时"
        }
        
        let days = max(Int(ceil(remaining / 86_400)), 1)
        return "剩余 \(days) 天"
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
