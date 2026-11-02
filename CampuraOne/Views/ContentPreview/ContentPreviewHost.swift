import SwiftUI
import BottomSheet
import PetaKitUIX
import PetaToolKit

/// One sheet above the dashboard detail and custom tab bar. Content navigation
/// changes its page, rather than presenting sheets on top of other sheets.
struct ContentPreviewHost: View {
    @ObservedObject var browser: ContentBrowserStore
    @ObservedObject var route: RoutePreviewStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var position: BottomSheetPosition = .hidden
    let openRoute: (RoutePreviewTarget) -> Void
    let returnFromRoute: () -> Void

    private var isPresented: Bool { browser.isPresented || route.isPresented }

    var body: some View {
        Color.clear
            .bottomSheet(bottomSheetPosition: $position,
                         switchablePositions: [.dynamicBottom, .relative(0.5), .relativeTop(0.92)],
                         headerContent: { header }, mainContent: { content })
            .showDragIndicator(true)
            .enableSwipeToDismiss(true)
            .enableTapToDismiss(false)
            .enableContentDrag(false)
            .enableBackgroundBlur(false)
            .customAnimation(reduceMotion ? .linear(duration: 0.12) : .spring(response: 0.38, dampingFraction: 0.88))
            .customBackground(
                RoundedRectangle(cornerRadius: 28, style: .continuous).fill(.regularMaterial)
                    .readSize { size in
                        if abs(browser.panelHeight - size.height) > 1 { browser.panelHeight = size.height }
                        if abs(route.panelHeight - size.height) > 1 { route.panelHeight = size.height }
                    }
            )
            .onDismiss { close() }
            .onChange(of: isPresented, initial: true) { _, shown in
                position = shown ? .relative(0.5) : .hidden
            }
            .onChange(of: browser.current?.id) { _, _ in
                if browser.isPresented { position = .relative(0.5) }
            }
            .onChange(of: route.isPresented) { _, shown in
                if shown { position = .relative(0.5) }
            }
            .onChange(of: route.overviewRequest) { _, _ in
                if route.isPresented { position = .dynamicBottom }
            }
    }

    @ViewBuilder private var header: some View {
        if route.isPresented {
            RoutePreviewHeader(route: route, onBack: routeBack, onClose: close)
        } else if let page = browser.current {
            if case .place(let id) = page.reference {
                CampusPlaceHeader(placeID: id, onClose: close, openRoute: openRoute)
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
                CampusPlaceContent(placeID: id)
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
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .padding(10)
                        .background(.quaternary, in: Circle())
                        .beButton(onBack)
                        .accessibilityLabel("返回")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.title2.bold()).lineLimit(2)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "xmark")
                    .font(.subheadline.bold())
                    .padding(10)
                    .background(.quaternary, in: Circle())
                    .beButton(onClose)
                    .accessibilityLabel("关闭预览")
                    .accessibilityIdentifier("content.preview.close")
            }
            actions
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .buttonStyle(.plain)
    }
}

private struct ContentDetailHeader: View {
    @ObservedObject var page: ContentPreviewPage
    @ObservedObject var model: LoadableListViewModel<ContentPreviewDetail>
    @ObservedObject var browser: ContentBrowserStore
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
                    Label(target == nil ? "商家暂未设置位置" : "路线 · \(shop.name)", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(target == nil ? Color.secondary : Color.accentColor)
                        .background(Color.accentColor.opacity(target == nil ? 0.05 : 0.12), in: RoundedRectangle(cornerRadius: 14))
                        .beButton { if let target { openRoute(target) } }
                        .disabled(target == nil)
                        .accessibilityIdentifier("content.preview.route")
                } else {
                    Text(detail.merchants.isEmpty ? "暂未关联商家" : "请在下方选择适用商家")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
