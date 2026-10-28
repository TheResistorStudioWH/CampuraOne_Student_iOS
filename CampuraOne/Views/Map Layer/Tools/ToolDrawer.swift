//
//  ToolDrawer.swift
//  CampuraOne
//
//  Created by Lin Shay on 16/06/2026.
//

import SwiftUI
import SwiftData

#Preview("app - 已登录") {
    PreviewAppView()
}

// MARK: - “你刚看过”的数据类型

/// 最近浏览的内容有两种可能：
/// 1. 一个商品
/// 2. 一个促销事件
///
/// enum 的 case 可以携带不同类型的数据，这种写法叫“关联值”
/// 我之前居然还没用过这个带括号的语法,都傻愣愣的写返回类型然后在那对id…
/// 这样就不需要为了商品和促销分别再保存两个可选变量
enum RecentlyViewedItem: Identifiable {
    case product(Product)
    case sale(SaleEvent)
    
    
    var id: String {
        switch self {
        case .product(let product):
            return "product-\(product.productID)"
        case .sale(let sale):
            return "sale-\(sale.saleID)"
        }
    }
    
    var title: String {
        switch self {
        case .product(let product):
            return product.productName
        case .sale(let sale):
            return sale.saleRule ?? "促销活动"
        }
    }
    
    var description: String {
        switch self {
        case .product(let product):
            return product.category?.categoryName ?? "商品"
        case .sale:
            return "促销事件"
        }
    }
    
    var icon: String {
        switch self {
        case .product(let product):
            return product.category?.categoryIcon ?? "shippingbox.fill"
        case .sale:
            return "tag.fill"
        }
    }
}

// MARK: - 常驻工具的数据结构

/// 工具箱里一直存在的按钮。
///
/// 这里不再保存 AnyView。
/// AnyView 虽然方便，但会抹掉真实 View 类型，而且容易把导航逻辑塞进数据模型。
/// 现在改成保存 action，点击后由外层页面决定打开什么界面。
struct ToolsItem: Identifiable {
    enum Kind: String, Identifiable {
        case shoppingBag
        case lastPurchase
        case randomRecommendation
        case safetyCheckIn
        
        var id: String { rawValue }
    }
    
    let kind: Kind
    let name: String
    let description: String
    let icon: String
    let action: () -> Void
    
    var id: Kind { kind }
}

// MARK: - 工具抽屉

struct ToolDrawer: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var contentHeight: CGFloat = 0
    @State private var isRevealed = false
    let sourceBounds: CGRect
    let containerSize: CGSize
    let topInset: CGFloat
    /// 最近没有浏览商品或促销时，传 nil 即可。
    /// nil 时，“你刚看过”整张卡片都不会出现。
    let recentlyViewed: RecentlyViewedItem?
    
    /// 这些闭包由外层页面传入。
    /// ToolDrawer 只负责显示，不负责决定具体的导航方式。
    let onOpenShoppingBag: () -> Void
    let onOpenLastPurchase: () -> Void
    let onOpenRandomRecommendation: () -> Void
    let onOpenProduct: (Product) -> Void
    let onOpenSale: (SaleEvent) -> Void
    
    @Binding var isExpand: Bool
    
    init(
        isExpand: Binding<Bool>,
        sourceBounds: CGRect,
        containerSize: CGSize,
        topInset: CGFloat = 0,
        recentlyViewed: RecentlyViewedItem? = nil,
        onOpenShoppingBag: @escaping () -> Void = {},
        onOpenLastPurchase: @escaping () -> Void = {},
        onOpenRandomRecommendation: @escaping () -> Void = {},
        onOpenProduct: @escaping (Product) -> Void = { _ in },
        onOpenSale: @escaping (SaleEvent) -> Void = { _ in }
    ) {
        self._isExpand = isExpand
        self.sourceBounds = sourceBounds
        self.containerSize = containerSize
        self.topInset = topInset
        self.recentlyViewed = recentlyViewed
        self.onOpenShoppingBag = onOpenShoppingBag
        self.onOpenLastPurchase = onOpenLastPurchase
        self.onOpenRandomRecommendation = onOpenRandomRecommendation
        self.onOpenProduct = onOpenProduct
        self.onOpenSale = onOpenSale
    }
    
    /// 常驻按钮统一在这里生成。
    /// 以后想增加新工具，只需要：
    /// 1. 在 Kind 里增加一个 case
    /// 2. 在这个数组里增加一个 ToolsItem
    private var persistentItems: [ToolsItem] {
        [
            ToolsItem(
                kind: .randomRecommendation,
                name: "智能推荐",
                description: "不知道吃什么?根据你的课表信息推断你的可分配时间,为你推荐最合适的饮食",
                icon: "sparkles",
                action: onOpenRandomRecommendation
            ),
            ToolsItem(
                kind: .lastPurchase,
                name: "上次购买",
                description: "快速回到最近订单",
                icon: "clock.arrow.circlepath",
                action: onOpenLastPurchase
            ),
            ToolsItem(
                kind: .shoppingBag,
                name: "购物车",
                description: "查看已加入的商品",
                icon: "cart.fill",
                action: onOpenShoppingBag
            ),
            ToolsItem(
                kind: .safetyCheckIn,
                name: "平安确认",
                description: "功能待开放",
                icon: "checkmark.shield",
                action: {}
            )
        ]
    }
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.black.opacity(.colorScheme(light: 0.09, dark: 0.20, colorScheme))
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("实用工具")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 12)
                            .accessibilityAddTraits(.isHeader)

                        if let recentlyViewed {
                            recentlyViewedCard(recentlyViewed)
                                .modifier(ToolDrawerArrival(isRevealed: isRevealed, index: persistentItems.count))
                        }

                        ForEachWithIndex(persistentItems) { index, item in
                            toolButton(item)
                                .modifier(ToolDrawerArrival(isRevealed: isRevealed, index: persistentItems.count - index - 1))
                        }
                    }
                    .padding(.vertical, 4)
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .scrollClipDisabled()
                .frame(height: min(contentHeight, maximumContentHeight))
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .foregroundColorScheme(light: .white, dark: .black)
                                .opacity(.colorScheme(light: 0.34, dark: 0.28, colorScheme))
                        }
                        .blur(radius: 8)
                        .opacity(isRevealed ? 0.85 : 0)
                        .animation(.easeOut(duration: 0.25), value: isRevealed)
                }

                ToolDrawerButton(isExpand: $isExpand)
            }
            .frame(width: panelWidth, alignment: .leading)
            .padding(.leading, sourceBounds.minX)
            .padding(.bottom, max(0, containerSize.height - sourceBounds.maxY))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .accessibilityAction(.escape) { dismiss() }
        .onChange(of: contentHeight) { _, height in
            if height > 0 { isRevealed = true }
        }
    }

    private var panelWidth: CGFloat {
        min(280, max(0, containerSize.width - sourceBounds.minX * 2) * 0.76)
    }

    private var maximumContentHeight: CGFloat {
        max(1, sourceBounds.minY - topInset - 16)
    }

    private func dismiss() {
        withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .snappy(duration: 0.25)) {
            isExpand = false
        }
    }
    
    // MARK: 你刚看过
    
    private func recentlyViewedCard(_ item: RecentlyViewedItem) -> some View {
        ToolDrawerCard(title: item.title, description: "你刚看过 · \(item.description)", icon: item.icon)
            .beButton {
                dismiss()
                openRecentlyViewed(item)
            }
            .buttonStyle(.plain)
    }
    
    /// 根据最近浏览内容的实际类型，调用正确的外部闭包。
    private func openRecentlyViewed(
        _ item: RecentlyViewedItem
    ) {
        switch item {
        case .product(let product):
            onOpenProduct(product)
        case .sale(let sale):
            onOpenSale(sale)
        }
    }
    
    // MARK: 常驻工具按钮
    
    private func toolButton(_ item: ToolsItem) -> some View {
        ToolDrawerCard(title: item.name, description: item.description, icon: item.icon)
            .beButton {
                dismiss()
                item.action()
            }
            .buttonStyle(.plain)
    }
}

struct ToolDrawerAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? { nil }

    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = nextValue() ?? value
    }
}

struct ToolDrawerButton: View {
    @Binding var isExpand: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var diameter: CGFloat = 50

    var body: some View {
        Image(systemName: isExpand ? "xmark" : "list.bullet")
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: diameter, height: diameter)
            .background(.regularMaterial, in: Circle())
            .shadow(color: .black.opacity(0.16), radius: 8, x: 0, y: 4)
            .beButton {
                withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .snappy(duration: 0.3)) {
                    isExpand.toggle()
                }
                TapSoft()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpand ? "收起实用工具" : "展开实用工具")
            .accessibilityValue(isExpand ? "已展开" : "已收起")
    }
}

private struct ToolDrawerCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String
    let description: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .shadow(color: .black.opacity(.colorScheme(light: 0.15, dark: 0.4, colorScheme)), radius: 2, x: 0, y: 1)

            Spacer(minLength: 4)
            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint(description)
    }
}

private struct ToolDrawerArrival: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let isRevealed: Bool
    let index: Int

    func body(content: Content) -> some View {
        content
            .opacity(isRevealed ? 1 : 0)
            .offset(y: reduceMotion || isRevealed ? 0 : 16)
            .scaleEffect(reduceMotion || isRevealed ? 1 : 0.92, anchor: .bottomLeading)
            .animation(
                reduceMotion ? .easeOut(duration: 0.15) :
                    .spring(response: 0.32, dampingFraction: 0.86).delay(Double(index) * 0.035),
                value: isRevealed
            )
    }
}
