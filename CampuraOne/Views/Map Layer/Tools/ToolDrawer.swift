//
//  ToolDrawer.swift
//  CampuraOne
//
//  Created by Lin Shay on 16/06/2026.
//

import SwiftUI
import SwiftData

#Preview("app - 已登录") {
    ContentView()
        .modelContainer(PreviewContainer.app)
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
    @Namespace var drawerSpace
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
        recentlyViewed: RecentlyViewedItem? = nil,
        onOpenShoppingBag: @escaping () -> Void = {},
        onOpenLastPurchase: @escaping () -> Void = {},
        onOpenRandomRecommendation: @escaping () -> Void = {},
        onOpenProduct: @escaping (Product) -> Void = { _ in },
        onOpenSale: @escaping (SaleEvent) -> Void = { _ in }
    ) {
        self._isExpand = isExpand
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
            )
        ]
    }
    
    var body: some View {
        if isExpand {
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("实用工具")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .beButton {
                            withAnimation(.snappy) {
                                isExpand = false
                            }
                        }
                }
                if let recentlyViewed {
                    recentlyViewedCard(recentlyViewed)
                }
                
                ForEachWithIndex(persistentItems) { index, item in
                    toolButton(item)
                    if index != persistentItems.count - 1 {
                        Divider()
                    }
                }
            }
            .padding(14)
            .background {
                RoundedRectangle(cornerRadius: 18,style: .continuous)
                    .fill(Material.ultraThin)
                    .matchedGeometryEffect(id: "tool_drawer", in: drawerSpace, properties: .frame, anchor: .bottomLeading)
            }
        } else {
            Image(systemName: "list.bullet")
                .font(.title2)
                .bold()
                .padding()
                .background {
                    Circle()
                        .fill(Material.ultraThin)
                        .matchedGeometryEffect(id: "tool_drawer", in: drawerSpace, properties: .frame, anchor: .bottomLeading)
                }
                .beButton {
                    withAnimation(.snappy) {
                        isExpand = true
                    }
                }
        }
        
    }
   
    
    // MARK: 你刚看过
    
    private func recentlyViewedCard(_ item: RecentlyViewedItem) -> some View {
        HStack(alignment: .center) {
            Image(systemName: item.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 3) {
                Text("你刚看过")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(item.title)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                
                Text(item.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 8)
            
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(.tertiary)
        }
        .beButton {
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
        HStack(alignment: .center) {
            Image(systemName: item.icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 30, height: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.callout)
                    .lineLimit(1)
                
                Text(item.description)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            
        }
        .beButton {
            item.action()
        }
        .buttonStyle(.plain)
    }
}
