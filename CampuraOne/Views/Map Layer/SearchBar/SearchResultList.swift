//
//  SearchResultList.swift
//  CampuraOne
//
//  Created by Lin Shay on 10/06/2026.
//

import SwiftUI
import SwiftData

#Preview("搜索结果 - 智能") {
    SearchResultList(
        query: "咖啡",
        mode: .smart
    )
    .padding()
}

#Preview("搜索结果 - 商品") {
    SearchResultList(
        query: "咖啡",
        mode: .product
    )
    .padding()
}

// MARK: - 搜索模式适配

extension SearchPickerItem {
    /// 界面选项与服务器 mode 的对应关系：
    /// - .all：普通全局，服务器接收 all
    /// - .smart：智能全局，服务器接收 smart
    /// - .product / .shop：保持同名
    var searchAPIMode: String {
        switch self {
            case .all:
                return "all"
            case .smart:
                return "smart"
            case .product:
                return "product"
            case .shop:
                return "shop"
        }
    }

    /// 只有“智能全局”显示顶部猜测胶囊。
    var showsSmartSuggestions: Bool {
        self == .smart
    }

}


// MARK: - 统一搜索结果

/// 促销、商品和商户来自不同的数据表，
/// 但搜索列表需要统一展示，所以转换成同一个结构。
struct SearchResultItem: Identifiable {
    enum Kind: String, Codable {
        case promotion
        case product
        case shop

        var title: String {
            switch self {
            case .promotion:
                return "促销"
            case .product:
                return "商品"
            case .shop:
                return "商户"
            }
        }

        var icon: String {
            switch self {
            case .promotion:
                return "tag.fill"
            case .product:
                return "bag.fill"
            case .shop:
                return "cart.fill"
            }
        }
    }

    let id: String
    let targetID: Int
    let kind: Kind
    let title: String
    let subtitle: String?
    let imageURL: String?

    /// 分类信息直接对应服务器的 product_categories 表。
    let categoryID: Int?
    let categoryName: String?
    let categoryIcon: String?
    let categoryColor: String?
    
    
}

/// 智能模式顶部的猜测胶囊。
/// 只保存一份完整的 SearchResultItem，避免重复维护 id、类型和标题。
struct SearchResultSuggestion: Identifiable {
    let info: SearchResultItem

    /// 显式初始化器，供 JSONMapper 使用。
    init(info: SearchResultItem) {
        self.info = info
    }

    var id: String {
        info.id
    }

    var targetID: Int {
        info.targetID
    }

    var title: String {
        info.title
    }

    var kind: SearchResultItem.Kind {
        info.kind
    }
}

/// 一次搜索请求的完整结果
/// 用一个 Payload 同时保存顶部 suggestions 和下面的 results
/// 这样只需要请求服务器一次，不会为了两部分数据重复访问 search.php
struct SearchResultPayload {
    let suggestions: [SearchResultSuggestion]
    let results: [SearchResultItem]
}

typealias SearchResultListViewModel = LoadableListViewModel<SearchResultPayload>

// MARK: - 搜索结果列表

struct SearchResultList: View {
    let query: String
    let mode: SearchPickerItem
    let schoolID: Int?

    /// 使用通用 LoadableListViewModel 加载一次完整搜索响应。
    @StateObject private var viewModel: SearchResultListViewModel

    init(
        query: String,
        mode: SearchPickerItem,
        schoolID: Int? = 1
    ) {
        self.query = query
        self.mode = mode
        self.schoolID = schoolID

        _viewModel = StateObject(
            wrappedValue: SearchResultListViewModel(loader: {
                /// 智能模式需要两份数据：
                /// 1. smart 请求只负责顶部的智能猜测胶囊；
                /// 2. all 请求负责下面普通的全局搜索列表。
                if mode.showsSmartSuggestions {
                    async let smartResponse = RemoteDataService.shared.search(
                        query: query,
                        mode: .smart,
                        schoolID: schoolID
                    )

                    async let allResponse = RemoteDataService.shared.search(
                        query: query,
                        mode: .all,
                        schoolID: schoolID
                    )

                    let (smart, all) = try await (
                        smartResponse,
                        allResponse
                    )

                    return [
                        SearchResultPayload(
                            suggestions: smart.suggestions,
                            results: all.results
                        )
                    ]
                }

                /// 非智能模式只请求一次服务器。
                let response = try await RemoteDataService.shared.search(
                    query: query,
                    mode: mode,
                    schoolID: schoolID
                )

                return [
                    SearchResultPayload(
                        suggestions: [],
                        results: response.results
                    )
                ]
            })
        )
    }

    /// 示例阶段在本地模拟服务器 mode 过滤。
    /// 服务器接好后，这部分可以保留做保险，也可以交给服务器完成。
    private var displayedResults: [SearchResultItem] {
        let results = viewModel.items.first?.results ?? []

        /// all / smart 都包含促销、商品和商户。
        /// 普通全局的显示顺序由服务器固定为：促销 > 商品 > 商户。
        /// 智能全局下面的普通列表来自额外的 all 请求，因此顺序相同。
        switch mode {
        case .all, .smart:
            return results
        case .product:
            return results.filter { $0.kind == .product }
        case .shop:
            return results.filter { $0.kind == .shop }
        }
    }

    private var smartSuggestions: [SearchResultSuggestion] {
        guard mode.showsSmartSuggestions else {
            return []
        }

        return viewModel.items.first?.suggestions ?? []
    }

    var body: some View {
        Group {
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                emptyQueryView
            } else if viewModel.isLoading && viewModel.items.isEmpty {
                loadingView
            } else if let errorMessage = viewModel.errorMessage,
                      viewModel.items.isEmpty {
                errorView(errorMessage)
            } else if displayedResults.isEmpty {
                emptyResultView
            } else {
                resultList
            }
        }
        .task(id: "\(query)|\(mode.searchAPIMode)|\(schoolID ?? 0)") {
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return
            }

            await viewModel.load()
        }
    }

    // MARK: 搜索结果列表

    private var resultList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if mode.showsSmartSuggestions,
                   !smartSuggestions.isEmpty {
                    smartSummaryRow
                }

                ForEach(displayedResults) { item in
                    resultRow(item)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: 智能搜索总结

    /// 左边是总结图标，右边是横向排列的猜测胶囊。
    private var smartSummaryRow: some View {
        ZStack {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Rectangle()
                        .fill(.clear)
                        .frame(width: 36, height: 36)
                    ForEach(smartSuggestions) { suggestion in
                        suggestionCapsule(suggestion)
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
            HStack {
                VStack {
                    if #available(iOS 26.0, *) {
                        Image(systemName: "text.line.2.summary")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(width: 36, height: 36)
                    } else {
                        Image("compatible.text.line.2.summary")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding()
                    }
                }
                .shadow(color: .blue.opacity(0.6), radius: 8, x: 1, y: 1)
                .accessibilityLabel("可能的搜索内容")
                Spacer()
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }

    private func suggestionCapsule(
        _ suggestion: SearchResultSuggestion
    ) -> some View {
        Label {
            Text(suggestion.info.title)
                .fixedSize(horizontal: true, vertical: false)
        } icon: {
            Image(
                systemName: suggestion.info.categoryIcon
                ?? suggestion.info.kind.icon
            )
            .foregroundColor(
                categoryColor(suggestion.info.categoryColor)
            )
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background {
                Capsule()
                .fill(categoryColor(suggestion.info.categoryColor).opacity(0.3))
        }
        .contentShape(Capsule())
        .beButton {
            /// 后续使用 suggestion.info.kind 和 suggestion.info.targetID 打开详情。
            TapSoft()
        }
        .buttonStyle(.plain)
    }

    // MARK: 单条结果

    private func resultRow(
        _ item: SearchResultItem
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.categoryIcon ?? item.kind.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(categoryColor(item.categoryColor))
                .frame(width: 42, height: 42)
                .background(.regularMaterial, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 5) {
                    Label(item.kind.title, systemImage: item.kind.icon)

                    if let categoryName = item.categoryName,
                       !categoryName.isEmpty {
                        Text("·")
                        highlightedMetadataText(
                            categoryName,
                            for: item
                        )
                    }

                    if let subtitle = item.subtitle,
                       !subtitle.isEmpty {
                        Text("·")
                        highlightedMetadataText(
                            subtitle,
                            for: item
                        )
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .contentShape(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .beButton {
            /// 后续根据 item.kind 和 item.targetID 打开促销、商品或商户详情。
            TapSoft()
        }
        .buttonStyle(.plain)
    }

    // MARK: 搜索关键词高亮

    /// 只有当结果标题本身没有直接命中关键词时，
    /// 才在分类名、商户名或其他副标题信息中高亮真正命中的部分。
    /// 例如搜索“咖啡”得到“烤肠”，若副标题中的商户名包含“咖啡”，
    /// 只高亮副标题里的“咖啡”；标题本身命中时则不额外高亮。
    private func highlightedMetadataText(
        _ text: String,
        for item: SearchResultItem
    ) -> Text {
        let keyword = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !keyword.isEmpty,
              item.title.range(
                of: keyword,
                options: [.caseInsensitive, .diacriticInsensitive]
              ) == nil else {
            return Text(text)
        }

        var result = Text("")
        var remainingRange = text.startIndex..<text.endIndex
        var currentIndex = text.startIndex
        var foundMatch = false

        while let matchRange = text.range(
            of: keyword,
            options: [.caseInsensitive, .diacriticInsensitive],
            range: remainingRange
        ) {
            foundMatch = true

            if currentIndex < matchRange.lowerBound {
                result = result + Text(
                    String(text[currentIndex..<matchRange.lowerBound])
                )
            }

            result = result + Text(String(text[matchRange]))
                .foregroundColor(.accentColor)
                .bold()

            currentIndex = matchRange.upperBound
            remainingRange = currentIndex..<text.endIndex
        }

        guard foundMatch else {
            return Text(text)
        }

        if currentIndex < text.endIndex {
            result = result + Text(String(text[currentIndex...]))
        }

        return result
    }

    // MARK: 状态视图

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("正在搜索…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(
        _ message: String
    ) -> some View {
        ContentUnavailableView {
            Label("搜索失败", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("重新搜索") {
                Task {
                    await viewModel.load()
                }
            }
        }
    }

    private var emptyQueryView: some View {
        ContentUnavailableView(
            "输入关键词开始搜索",
            systemImage: "magnifyingglass"
        )
    }

    private var emptyResultView: some View {
        ContentUnavailableView(
            "没有找到相关内容",
            systemImage: "magnifyingglass",
            description: Text("试试更换关键词或搜索范围")
        )
    }

    // MARK: 分类颜色

    private func categoryColor(
        _ value: String?
    ) -> Color {
        switch value?.lowercased() {
        case "brown": return .brown
        case "orange": return .orange
        case "red": return .red
        case "pink": return .pink
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "cyan": return .cyan
        case "mint": return .mint
        case "yellow": return .yellow
        case "gray", "grey": return .gray
        default: return .accentColor
        }
    }
}
