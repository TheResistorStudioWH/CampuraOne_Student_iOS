//
//  SearchBar.swift
//  CampuraOne
//
//  Created by Lin Shay on 10/06/2026.
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
// MARK: - 搜索模式

/// smart：搜索促销、商品和商户，并显示顶部智能猜测内容。
/// all：搜索促销、商品和商户，普通列表顺序为促销 > 商品 > 商户。
/// product：只显示商品结果。
/// shop：只显示商户结果。
enum SearchPickerItem: CaseIterable, Identifiable, Hashable {
    case all, smart, product, shop
    
    var id: Self { self }
    
    var icon: String {
        switch self {
            case .all:
                return "rhombus.fill"
            case .smart:
                return "sparkles"
            case .product:
                return "bag.fill"
            case .shop:
                return "basket.fill"
        }
    }
    
    
    var name: String {
        switch self {
            case .all:
                return "全局"
            case .product:
                return "按商品"
            case .shop:
                return "按商户"
            case .smart:
                return "智能全局"
        }
    }
    
    
    var color: Color {
        switch self {
            case .all:
                return .cyan
            case .product:
                return .yellow
            case .shop:
                return .indigo
            case .smart:
                return .mint
        }
    }
    
    
}

struct SearchBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace var bgTransitionContainer
    @Namespace var SearchBarTransitionContainer
    
    
    @State var searchText = ""
    
    @State var showPickerBar = false
    @State var showResultList = false
    @State var showLargeBar = false
    
    /// 每次真正执行搜索时更新这个 ID。
    /// SearchResultList 使用新的 identity 重新创建并重新请求服务器。
    @State private var searchRefreshID = UUID()

    /// 最近一次真正提交搜索时使用的文本。
    /// 输入内容与它不同时，说明用户正在继续输入，应显示实时搜索建议。
    @State private var submittedSearchText = ""

    /// 用户停止输入后，真正交给建议列表请求的关键词。
    @State private var inputSuggestionQuery = ""

    /// 历史记录只保存搜索词，不保存服务器返回的用户或商户数据。
    @AppStorage("campura.search.history") private var encodedSearchHistory = "[]"
    
    @State var PickerSelection: SearchPickerItem = .smart

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var shouldShowInputSuggestions: Bool {
        !inputSuggestionQuery.isEmpty
        && normalizedSearchText != submittedSearchText
        && !showPickerBar
    }

    private var searchHistory: [String] {
        guard let data = encodedSearchHistory.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return values
    }

    private var shouldShowHistory: Bool {
        showLargeBar
        && normalizedSearchText.isEmpty
        && !showPickerBar
        && !showResultList
        && !searchHistory.isEmpty
    }
    
    var body: some View {
        ZStack(alignment: .top) {
            if showLargeBar {
                
                VStack(alignment: .leading) {
                    HStack(spacing: 7) {
                        SearchPickerPlaceholder()
                        SearchFieldPlaceholder()
                    }
                    .opacity(0)
                    .allowsHitTesting(false)
                    
                    
                    if showPickerBar {
                        PickerBar()
                            .transition(reduceMotion ? .opacity : .scale(scale: 0.72, anchor: .topLeading).combined(with: .opacity))
                    }
                }
                .zIndex(showPickerBar ? 30 : 0)
                
                VStack(alignment: .trailing) {
                    HStack(spacing: 7) {
                        SearchPickerPlaceholder()
                        SearchFieldPlaceholder()
                    }
                    .opacity(0)
                    .allowsHitTesting(false)

                    SearchCollapseButtonPlaceholder()

                    if shouldShowInputSuggestions {
                        SearchInputSuggestionList(
                            query: inputSuggestionQuery,
                            mode: PickerSelection
                        ) { suggestion in
                            selectInputSuggestion(suggestion)
                        }
                    }

                    if shouldShowHistory {
                        SearchHistoryList(
                            items: searchHistory,
                            onSelect: selectHistory,
                            onDelete: deleteHistory,
                            onDeleteAll: clearHistory
                        )
                        .transition(reduceMotion ? .opacity : .scale(scale: 0.95, anchor: .top).combined(with: .opacity))
                    }

                    if showResultList {
                        SearchResultList(
                            query: submittedSearchText,
                            mode: PickerSelection
                        )
                        .id(searchRefreshID)
                        .transition(.scale(scale: 0.82, anchor: .topTrailing).combined(with: .opacity))
                    }
                }
                .zIndex(10)
                
                VStack(alignment: .leading) {
                    HStack(spacing: 7) {
                        SearchPicker(
                            selection: $PickerSelection,
                            showPickerBar: $showPickerBar
                        )
                        SearchField(
                            SearchBarTransitionContainer: SearchBarTransitionContainer,
                            showLargeBar: $showLargeBar,
                            text: $searchText,
                            onSearch: performSearch,
                            onClear: clearSearchText
                        )
                    }
                    
                    HStack {
                        Spacer()
                        SearchCollapseButton {
                            collapseSearchBar()
                        }
                    }
                }
                .zIndex(40)
            } else {
                HStack {
                    SearchButton(
                        showLargeBar: $showLargeBar
                    )
                        .matchedGeometryEffect(id: "SearchBar_magnifyingglass", in: SearchBarTransitionContainer, properties: .frame)
                    Spacer()
                }
            }
            
        }
        .padding()
        .shadow(color: .black.opacity(0.3), radius: 6, x: 1, y: 1)
        
        .animation(.smooth, value: showPickerBar)
        .animation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.88), value: encodedSearchHistory)
        .animation(reduceMotion ? .linear(duration: 0.15) : .spring(response: 0.48, dampingFraction: 0.78), value: inputSuggestionQuery)
        .task(id: "\(normalizedSearchText)|\(PickerSelection)|\(showLargeBar)") {
            await listenForSearchInput()
        }
        
    }
    
    /// 监听输入变化。用户停止输入 350 毫秒后，才更新建议查询词。
    /// 当 searchText 再次变化时，`.task(id:)` 会自动取消上一次等待。
    @MainActor
    private func listenForSearchInput() async {
        inputSuggestionQuery = ""
        if normalizedSearchText != submittedSearchText {
            showResultList = false
        }

        let trimmedText = normalizedSearchText

        guard showLargeBar, !trimmedText.isEmpty,
              trimmedText != submittedSearchText else {
            return
        }

        do {
            try await Task.sleep(nanoseconds: 350_000_000)
            try Task.checkCancellation()
            inputSuggestionQuery = trimmedText
        } catch {
            // 用户继续输入导致任务取消，不需要处理。
        }
    }

    /// 展开状态下点击放大镜，真正刷新一次搜索结果。
    private func performSearch() {
        let trimmedText = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedText.isEmpty else {
            showResultList = false
            return
        }

        withAnimation(reduceMotion ? .linear(duration: 0.15) : .spring(response: 0.5, dampingFraction: 0.78)) {
            searchText = trimmedText
            submittedSearchText = trimmedText
            inputSuggestionQuery = ""
            searchRefreshID = UUID()

            showResultList = true
            showPickerBar = false
        }

        saveToHistory(trimmedText)

        TapSoft()
    }

    /// 点击实时建议后，把建议标题放回输入框并立即执行正式搜索。
    private func selectInputSuggestion(_ suggestion: SearchResultItem) {
        searchText = suggestion.title
        performSearch()
    }

    private func selectHistory(_ query: String) {
        searchText = query
        performSearch()
    }

    private func clearSearchText() {
        withAnimation(.smooth) {
            searchText = ""
            submittedSearchText = ""
            inputSuggestionQuery = ""
            showResultList = false
        }
        TapSoft()
    }

    private func saveToHistory(_ query: String) {
        var values = searchHistory.filter {
            $0.localizedCaseInsensitiveCompare(query) != .orderedSame
        }
        values.insert(query, at: 0)
        persistHistory(Array(values.prefix(8)))
    }

    private func deleteHistory(_ query: String) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.88)) {
            persistHistory(searchHistory.filter { $0 != query })
        }
    }

    private func clearHistory() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .spring(response: 0.35, dampingFraction: 0.88)) {
            persistHistory([])
        }
    }

    private func persistHistory(_ values: [String]) {
        guard let data = try? JSONEncoder().encode(values),
              let text = String(data: data, encoding: .utf8) else { return }
        encodedSearchHistory = text
    }
    
    /// 收起搜索栏，并关闭当前展开的附属内容。
    private func collapseSearchBar() {
        withAnimation(.smooth) {
            showLargeBar = false
            showPickerBar = false
            showResultList = false
            inputSuggestionQuery = ""
        }
        
        TapSoft()
    }
    
    /// 搜索类型选择列表。
    /// 使用 VStack，所以四个选项会纵向排列。
    @ViewBuilder
    func PickerBar() -> some View {
        VStack(alignment: .leading) {
            ForEach(Array(SearchPickerItem.allCases.enumerated()), id: \.element) { index, item in
                PickerBarItem(item)
                    .modifier(SearchModeArrival(index: index))
            }
        }
        .padding(5)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        }
    }
    
    
    /// 单个搜索类型选项。
    /// 只有当前选中的项目才会放入 PickerBarBG，
    /// matchedGeometryEffect 会负责把背景平滑移动到新选项。
    @ViewBuilder
    func PickerBarItem(_ item: SearchPickerItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .frame(width: 20)
                .foregroundStyle(
                    PickerSelection == item
                    ? PickerSelection.color
                    : Color.secondary
                )
            
            Text(item.name)
                .font(.subheadline.weight(.semibold))
            
                .foregroundStyle(
                    PickerSelection == item
                    ? Color.primary
                    : Color.secondary
                )
            
        }
        .frame(width: screen.width/4.2, alignment: .leading)
        .padding(10)
        
        .background {
            if PickerSelection == item {
                PickerBarBG()
            }
        }
        .contentShape(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .onTapGesture {
            withAnimation(.smooth) {
                PickerSelection = item
                showResultList = false
                submittedSearchText = ""
                inputSuggestionQuery = ""
                showPickerBar = false
            }
            TapSoft()
        }
    }
    
    @ViewBuilder func PickerBarBG() -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Material.regular)
            .matchedGeometryEffect(id: "SearchPickerBG", in: bgTransitionContainer, properties: .position)
    }
    
    
   
}

/// Brief, staggered zoom from the mode button; the existing layout stays unchanged.
private struct SearchModeArrival: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    let index: Int

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion || visible ? 1 : 0.58, anchor: .topLeading)
            .opacity(visible ? 1 : 0)
            .offset(y: reduceMotion || visible ? 0 : -CGFloat(index + 1) * 5)
            .onAppear {
                withAnimation(reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.22, dampingFraction: 0.82).delay(Double(index) * 0.022)) {
                    visible = true
                }
            }
    }
}

/// 搜索框展开且输入为空时显示。
private struct SearchHistoryList: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let items: [String]
    let onSelect: (String) -> Void
    let onDelete: (String) -> Void
    let onDeleteAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("历史搜索", systemImage: "clock.arrow.circlepath")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("全部清除", action: onDeleteAll)
                    .font(.caption)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            ForEach(items, id: \.self) { item in
                HStack(spacing: 10) {
                    Button {
                        onSelect(item)
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            Text(item)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDelete(item)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("删除历史搜索 \(item)")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}



/// 输入过程中显示的实时搜索建议。
/// 它只负责帮助用户补全搜索词，不属于正式搜索结果列表。
private struct SearchInputSuggestionList: View {
    let query: String
    let mode: SearchPickerItem
    let onSelect: (SearchResultItem) -> Void

    @State private var suggestions: [SearchResultItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var requestID: String {
        "\(mode)-\(query)"
    }

    var body: some View {
        // Keep a concrete task host even before the first response arrives.
        // A conditional empty Group has no rendered child to start its task on.
                VStack(alignment: .leading, spacing: 0) {
                    if isLoading {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)

                            Text("正在查找可能的搜索内容")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                    }

                    if let errorMessage {
                        Text(errorMessage).font(.caption).foregroundStyle(.secondary).padding(14)
                    }

                    ForEach(suggestions) { suggestion in
                        Button {
                            onSelect(suggestion)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20)

                                Text(suggestion.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                Spacer(minLength: 8)

                                Label(
                                    suggestion.kind.title,
                                    systemImage: suggestion.categoryIcon
                                    ?? suggestion.kind.icon
                                )
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if suggestion.id != suggestions.last?.id {
                            Divider()
                                .padding(.leading, 44)
                        }
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.scale(scale: 0.9, anchor: .topTrailing).combined(with: .opacity))
        .task(id: requestID) {
            await loadSuggestions()
        }
        .animation(reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.42, dampingFraction: 0.86), value: suggestions.map(\.id))
    }

    @MainActor
    private func loadSuggestions() async {
        suggestions = []
        errorMessage = nil

        let trimmedQuery = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !trimmedQuery.isEmpty else {
            isLoading = false
            return
        }

        do {
            isLoading = true

            /// `.smart` 始终代表智能全局。
            /// 普通全局本身不返回建议，因此仅在输入建议阶段借用 smart；
            /// 商品和商户模式继续遵循当前选择范围。
            let requestMode: SearchPickerItem

            switch mode {
            case .all, .smart:
                requestMode = .smart
            case .product:
                requestMode = .product
            case .shop:
                requestMode = .shop
            }

            let response = try await RemoteDataService.shared.search(
                query: trimmedQuery,
                mode: requestMode
            )

            try Task.checkCancellation()

            let candidateItems: [SearchResultItem]

            if requestMode == .smart {
                candidateItems = response.suggestions.isEmpty ? response.results : response.suggestions.map(\.info)
            } else {
                candidateItems = response.results
            }

            suggestions = Array(candidateItems.prefix(8))
            if suggestions.isEmpty { errorMessage = "没有匹配的候选词，可以继续输入或点击搜索。" }
            isLoading = false
        } catch is CancellationError {
            isLoading = false
        } catch {
            guard !Task.isCancelled else { return }
            errorMessage = "暂时无法获取候选词，请点击搜索重试。"
            suggestions = []
            isLoading = false
        }
    }
}

struct SearchPicker: View {
    @Binding var selection: SearchPickerItem
    @Binding var showPickerBar: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "increase.indent")
            Image(systemName: selection.icon)
                .frame(width: 20, height: 20)
                .padding(2)
                .background(alignment: .center) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(selection.color.opacity(0.4))
                }
        }
            .font(.subheadline.weight(.semibold))
            .fixedSize(horizontal: true, vertical: false)
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .onTapGesture {
                withAnimation(.smooth) {
                    showPickerBar.toggle()
                }
                TapSoft()
            }
            .accessibilityLabel("搜索范围：\(selection.name)")
            .accessibilityHint("点击展开搜索范围选择")
    }
}

/// 仅用于占位对齐，不包含 Binding、手势或任何可刷新状态。
private struct SearchPickerPlaceholder: View {
    var body: some View {
        HStack {
            Image(systemName: "increase.indent")
            Image(systemName: "rhombus.fill")
                .frame(width: 20, height: 20)
                .padding(2)
        }
        .font(.subheadline.weight(.semibold))
        .fixedSize(horizontal: true, vertical: false)
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .hidden()
        .accessibilityHidden(true)
    }
}

/// 只复制 SearchField 的尺寸，不创建 TextField，也不会参与视图刷新。
private struct SearchFieldPlaceholder: View {
    var body: some View {
        HStack {
            Text("聚焦搜索校园内容")
                .font(.subheadline)
                .padding(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Image(systemName: "magnifyingglass")
                .padding(8)
                .background {
                    Circle()
                        .fill(Material.thick)
                }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: .infinity, style: .continuous)
                .fill(Material.bar)
        }
        .hidden()
        .accessibilityHidden(true)
    }
}

private struct SearchCollapseButton: View {
    let action: () -> Void
    
    var body: some View {
        Image(systemName: "chevron.up")
            .font(.headline.bold())
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(.ultraThinMaterial, in: Capsule())
            .contentShape(Capsule())
            .beButton {
                action()
            }
            .accessibilityLabel("收起搜索栏")
    }
}

/// 与真正的收起按钮保持相同尺寸，只负责占位对齐。
private struct SearchCollapseButtonPlaceholder: View {
    var body: some View {
        HStack {
            Spacer()
            Image(systemName: "chevron.up")
                .font(.caption.bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.ultraThinMaterial, in: Capsule())
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

struct SearchField: View {
    let SearchBarTransitionContainer: Namespace.ID
    @Binding var showLargeBar: Bool
    @Binding var text: String
    let onSearch: () -> Void
    let onClear: () -> Void
    
    var body: some View {
        HStack {
            inputField()
                .padding(.leading)

            if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜索内容")
            }
            
            SearchButton(
                showLargeBar: $showLargeBar,
                onSearch: onSearch
            )
            .matchedGeometryEffect(
                id: "SearchBar_magnifyingglass",
                in: SearchBarTransitionContainer,
                properties: .frame
            )
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: .infinity, style: .continuous)
                .fill(Material.bar)
        }
    }
    
    @ViewBuilder
    func inputField() -> some View {
        TextField(
            "聚焦搜索校园内容",
            text: $text
        )
        .font(.subheadline)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.search)
        .lineLimit(1)
        .onSubmit {
            onSearch()
        }
    }
}

struct SearchButton: View {
    @Binding var showLargeBar: Bool
    var onSearch: (() -> Void)? = nil
    
    var body: some View {
        Image(systemName: "magnifyingglass")
            .foregroundStyle(.blue)
            .padding(8)
            .background(alignment: .center) {
                Circle()
                    .fill(Material.thick)
            }
            .beButton {
                if showLargeBar {
                    onSearch?()
                } else {
                    withAnimation(.smooth) {
                        showLargeBar = true
                    }
                    TapSoft()
                }
            }
    }
}
