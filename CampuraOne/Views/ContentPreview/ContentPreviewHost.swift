import SwiftUI
import BottomSheet
import PetaKitUIX
import PetaToolKit

/// One sheet above the dashboard detail and custom tab bar. Content navigation
/// changes its page, rather than presenting sheets on top of other sheets.
struct ContentPreviewHost: View {
    @ObservedObject var browser: ContentBrowserStore
    @ObservedObject var route: RoutePreviewStore
    @ObservedObject private var navigation = StudentNavigationStore.shared
    @ObservedObject private var map = CampusMapStore.shared
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position: BottomSheetPosition = .hidden
    @State private var browsingPosition: BottomSheetPosition = .relative(0.5)
    @State private var routePosition: BottomSheetPosition = .relative(0.5)
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let openRoute: (RoutePreviewTarget) -> Void
    let returnFromRoute: () -> Void

    private var initialPosition: BottomSheetPosition {
        #if DEBUG
        if PreviewAPI.isEnabled, ProcessInfo.processInfo.arguments.contains("--campura-preview-expanded") { return .relativeTop(0.92) }
        #endif
        return typeSize.isAccessibilitySize ? .relativeTop(0.92) : .relative(0.5)
    }

    private var isPresented: Bool { browser.isPresented || route.isPresented }

    var body: some View {
        Color.clear
            .bottomSheet(bottomSheetPosition: $position,
                         switchablePositions: [.dynamicBottom, .relative(0.5), .relativeTop(0.92)],
                         headerContent: {
                             header
                                 .accessibilityAction(named: Text("展开卡片")) { position = .relativeTop(0.92) }
                                 .accessibilityAction(named: Text("收起卡片")) { position = .dynamicBottom }
                         }, mainContent: { content })
            .showDragIndicator(true)
            .enableSwipeToDismiss(true)
            .enableTapToDismiss(false)
            .enableContentDrag(false)
            .enableBackgroundBlur(false)
            .enableAccountingForKeyboardHeight(true)
            .customAnimation(reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.38, dampingFraction: 0.88))
            .customBackground(
                panelBackground
                    .readSize { size in
                        if abs(browser.panelHeight - size.height) > 1 { browser.panelHeight = size.height }
                        if abs(route.panelHeight - size.height) > 1 { route.panelHeight = size.height }
                    }
            )
            .onDismiss { close() }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                if isPresented { position = .relativeTop(0.92) }
            }
            .onChange(of: isPresented, initial: true) { _, shown in
                position = shown ? initialPosition : .hidden
            }
            .onChange(of: browser.current?.id) { old, _ in
                // Keep the user's chosen height while moving through the same
                // detail stack; a return should not collapse a long shop list.
                if old == nil, browser.isPresented, !route.isPresented { position = initialPosition }
            }
            .onChange(of: route.isPresented) { _, shown in
                if shown {
                    browsingPosition = position
                    position = initialPosition
                } else if browser.isPresented { position = browsingPosition }
            }
            .onChange(of: route.selectedSource?.id) { old, source in
                if source != nil {
                    if old == nil { routePosition = position }
                    position = .relativeTop(0.92)
                } else if route.isPresented { position = routePosition }
            }
            .onChange(of: route.isSelectingOrigin) { _, selecting in
                if selecting {
                    routePosition = position
                    position = .relativeTop(0.92)
                } else if route.isPresented { position = routePosition }
            }
            .onChange(of: typeSize) { _, size in
                if isPresented, size.isAccessibilitySize { position = .relativeTop(0.92) }
            }
            .onChange(of: map.focusRequest?.id) { _, _ in
                if map.focusRequest != nil, browser.isPresented, !route.isPresented { position = .dynamicBottom }
            }
            .onChange(of: navigation.isGuiding) { _, guiding in
                if !guiding, route.isPresented, route.selectedSource == nil, !route.isSelectingOrigin { position = .relative(0.5) }
            }
            .onChange(of: route.overviewRequest) { _, _ in
                if route.isPresented { position = .dynamicBottom }
            }
    }

    @ViewBuilder private var panelBackground: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Color(uiColor: .systemBackground))
        } else {
            RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.regularMaterial)
        }
    }

    @ViewBuilder private var header: some View {
        if route.isPresented {
            RoutePreviewHeader(route: route, onBack: routeBack, onClose: close)
        } else if let page = browser.current {
            if case .place(let id) = page.reference {
                CampusPlaceHeader(placeID: id, browser: browser, onClose: close, openRoute: openRoute)
            } else {
                ContentDetailHeader(page: page, browser: browser, onClose: close, openRoute: openRoute)
            }
        }
    }

    @ViewBuilder private var content: some View {
        if route.isPresented {
            RoutePreviewPanel(route: route)
                .id(route.requestID)
        } else if let page = browser.current {
            if case .place(let id) = page.reference {
                CampusPlaceContent(placeID: id, page: page, browser: browser)
                    .id(page.id)
            } else {
                ContentPreviewDetailView(page: page, browser: browser)
                    .id(page.id)
            }
        }
    }

    private func routeBack() {
        if route.selectedSource != nil { route.selectedSource = nil }
        else if route.isSelectingOrigin, route.origin != nil { route.isSelectingOrigin = false }
        else { returnFromRoute() }
    }

    private func close() {
        if route.isPresented { returnFromRoute() }
        browser.close()
        position = .hidden
    }
}

struct PreviewPanelHeader<Actions: View>: View {
    let title: String
    let subtitle: String?
    let showBack: Bool
    let onBack: () -> Void
    let onClose: () -> Void
    @ViewBuilder var actions: Actions

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                if showBack {
                    MapPanelIconButton(title: "返回", symbol: "chevron.left", action: onBack)
                        .accessibilityIdentifier("content.preview.back")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title2.bold()).lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                MapPanelIconButton(title: "关闭预览", symbol: "xmark", action: onClose)
                    .accessibilityIdentifier("content.preview.close")
            }
            .accessibilityElement(children: .contain)
            actions
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .buttonStyle(.plain)
    }
}

private struct ContentDetailHeader: View {
    @ObservedObject var page: ContentPreviewPage
    @ObservedObject var model: LoadableListViewModel<ContentPreviewDetail>
    @ObservedObject var browser: ContentBrowserStore
    @ObservedObject private var map = CampusMapStore.shared
    let onClose: () -> Void
    let openRoute: (RoutePreviewTarget) -> Void

    init(page: ContentPreviewPage, browser: ContentBrowserStore, onClose: @escaping () -> Void,
         openRoute: @escaping (RoutePreviewTarget) -> Void) {
        self.page = page; self.model = page.model; self.browser = browser
        self.onClose = onClose; self.openRoute = openRoute
    }

    var body: some View {
        let detail = model.items.first
        PreviewPanelHeader(title: detail?.title ?? "内容预览", subtitle: detail?.subtitle,
                           showBack: browser.pages.count > 1, onBack: browser.back, onClose: onClose) {
            if let detail {
                if let shop = detail.merchants.first, detail.merchants.count == 1 {
                    let target = browser.repository.boundPlace(for: shop)
                    if let target {
                        HStack(spacing: 10) {
                            MapPanelAction(title: "路线", symbol: "arrow.triangle.turn.up.right.diamond.fill", prominent: true) { openRoute(target) }
                                .accessibilityIdentifier("content.preview.route")
                            MapPanelIconButton(title: "在地图上查看商家", symbol: "scope", tint: .accentColor) {
                                if let id = target.destination { map.focus(on: [id]) }
                            }
                            .accessibilityIdentifier("content.preview.map")
                        }
                    } else {
                        Label(map.isLoading ? "正在读取商家位置…" : map.merchantError != nil ? "商家位置暂不可用" : "商家暂未设置位置",
                              systemImage: map.isLoading ? "location.magnifyingglass" : "mappin.slash")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                } else {
                    Text(detail.merchants.isEmpty ? "暂未关联商家" : "请在下方选择适用商家")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .task { await map.loadIfNeeded() }
    }
}
