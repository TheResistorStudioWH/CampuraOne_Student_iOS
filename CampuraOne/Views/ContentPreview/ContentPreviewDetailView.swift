import SwiftUI
import PetaKitUIX

struct ContentPreviewDetailView: View {
    @ObservedObject var page: ContentPreviewPage
    @ObservedObject var browser: ContentBrowserStore
    @ObservedObject private var model: LoadableListViewModel<ContentPreviewDetail>
    @ObservedObject private var advertisements = AdvertisementStore.shared
    @State private var showsPhoto = false

    init(page: ContentPreviewPage, browser: ContentBrowserStore) {
        self.page = page; self.browser = browser; self.model = page.model
    }

    var body: some View {
        Group {
            if let detail = model.items.first {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        if page.advertisement != nil || detail.imageURL?.isEmpty == false {
                            hero(detail).id("photo")
                        }
                        if let event = detail.promotion {
                            promotionInfo(event).id("promotion")
                            PromotionWatchControls(event: event, merchantName: detail.merchants.map(\.name).joined(separator: "、"))
                        }
                        if let product = detail.product {
                            VStack(alignment: .leading, spacing: 8) {
                                priceSummary(product, merchants: detail.merchants)
                                if detail.promotion != nil {
                                    contentRow(product.productName, subtitle: "查看商品", symbol: "bag") {
                                        browser.push(.product(product.productID))
                                    }
                                }
                            }.id("price")
                        }
                        if let intro = detail.introduction, !intro.isEmpty {
                            Text(intro).font(.body).textSelection(.enabled).id("introduction")
                        }
                        merchantSection(detail).id("merchants")
                        if let parent = detail.parent {
                            contentRow(parent.name, subtitle: "所属商家", symbol: "building.2") { browser.push(parent.reference) }
                                .id("parent")
                        }
                        if !detail.children.isEmpty {
                            Text("店铺与档口").font(.headline).id("children")
                            ForEach(detail.children) { merchant in
                                contentRow(merchant.name, subtitle: merchant.address, symbol: "storefront") { browser.push(merchant.reference) }
                                    .id(merchant.id)
                            }
                        }
                        if !detail.promotions.isEmpty {
                            Text("正在进行的促销").font(.headline).id("promotions")
                            ForEach(detail.promotions.filter { $0.isActive() }) { event in
                                contentRow(event.displayTitle, subtitle: "查看活动规则", symbol: "tag") { browser.push(.promotion(event.saleID)) }
                                    .id("promotion-\(event.saleID)")
                            }
                        }
                        if isShop { productSection(detail) }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $page.scrollID, anchor: .top)
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            } else if model.isLoading {
                ProgressView("正在加载…").frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label("暂时无法查看", systemImage: "exclamationmark.bubble")
                } description: { Text(model.errorMessage ?? "内容已移除") }
                actions: { Text("重新加载").beButton { Task { await model.load(); browser.didLoad(page) } } }
            }
        }
        .task(id: page.id) {
            if model.items.isEmpty { await model.load() }
            browser.didLoad(page)
        }
        .fullScreenCover(isPresented: $showsPhoto) {
            ContentPhotoViewer(imageURL: model.items.first?.imageURL, advertisement: page.advertisement)
        }
    }

    private var isShop: Bool {
        switch page.reference { case .mainShop, .subShop: return true; default: return false }
    }

    private func priceSummary(_ product: Product, merchants: [ContentMerchant]) -> some View {
        let price = Text(product.productPrice, format: .currency(code: "CNY"))
            .font(.title2.bold()).foregroundStyle(Color.accentColor)
        let watch = ProductPriceWatchButton(product: product, merchantName: merchants.map(\.name).joined(separator: "、"))
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                price.fixedSize()
                Spacer(minLength: 0)
                watch.fixedSize(horizontal: true, vertical: false)
            }
            VStack(alignment: .leading, spacing: 12) {
                price
                watch
            }
        }
    }

    private func hero(_ detail: ContentPreviewDetail) -> some View {
        Group {
            if let advertisement = page.advertisement {
                if let current = advertisements.items.first(where: { $0.adID == advertisement.adID }) {
                    AdvertisementImage(advertisement: current, contentMode: .fit)
                } else {
                    Label("宣传图片已下架", systemImage: "photo.badge.exclamationmark").foregroundStyle(.secondary)
                }
            } else {
                RemoteImageView(url: detail.imageURL.flatMap(URL.init(string:)), contentMode: .fit) {
                    ZStack {
                        Color.accentColor.opacity(0.07)
                        Image(systemName: isShop ? "storefront" : "photo").font(.largeTitle).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .contentShape(RoundedRectangle(cornerRadius: 20))
        .beButton { showsPhoto = true }
        .buttonStyle(.plain)
        .accessibilityLabel("放大查看图片")
    }

    private func promotionInfo(_ event: SaleEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(event.isExpired() ? "活动已结束" : event.isActive() ? "正在进行" : "即将开始", systemImage: "tag.fill")
                .font(.subheadline.bold())
                .foregroundStyle(event.isExpired() ? .secondary : Color.accentColor)
            Text(event.saleRule ?? "暂未填写活动规则").textSelection(.enabled)
            Text("\(event.startTime.formatted(date: .abbreviated, time: .shortened)) 至 \(event.endTime?.formatted(date: .abbreviated, time: .shortened) ?? "长期有效")")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func merchantSection(_ detail: ContentPreviewDetail) -> some View {
        if !isShop {
            Text("\(detail.merchants.count > 1 ? "适用" : "所属")商家").font(.headline)
            if detail.merchants.isEmpty {
                Label("暂未关联商家", systemImage: "storefront").foregroundStyle(.secondary)
            }
            ForEach(detail.merchants) { merchant in
                contentRow(merchant.name, subtitle: merchant.address, symbol: "storefront") { browser.push(merchant.reference) }
            }
        } else if let address = detail.merchants.first?.address, !address.isEmpty {
            Label(address, systemImage: "mappin.and.ellipse").font(.subheadline).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private func productSection(_ detail: ContentPreviewDetail) -> some View {
        Text("商品").font(.headline).id("products")
        if detail.products.isEmpty { Text("暂无商品").foregroundStyle(.secondary) }
        else {
            let categories = Dictionary(detail.products.compactMap { product in
                product.category.map { ($0.categoryID, $0.categoryName) }
            }, uniquingKeysWith: { first, _ in first }).sorted { $0.key < $1.key }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    categoryButton("全部", id: nil)
                    ForEach(categories, id: \.key) { category in categoryButton(category.value, id: category.key) }
                }
            }.scrollIndicators(.hidden)
            ForEach(detail.products.filter { page.categoryID == nil || $0.categoryID == page.categoryID }) { product in
                contentRow(product.productName, subtitle: product.productPrice.formatted(.currency(code: "CNY")), symbol: product.category?.categoryIcon ?? "bag") {
                    browser.push(.product(product.productID))
                }.id("product-\(product.productID)")
            }
        }
    }

    private func categoryButton(_ title: String, id: Int?) -> some View {
        Text(title).font(.subheadline.weight(.medium))
            .foregroundStyle(page.categoryID == id ? Color.accentColor : .secondary)
            .padding(.horizontal, 13).padding(.vertical, 8)
            .background(Color.accentColor.opacity(page.categoryID == id ? 0.12 : 0.04), in: Capsule())
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .beButton { page.categoryID = id }
            .buttonStyle(.plain)
            .accessibilityAddTraits(page.categoryID == id ? .isSelected : [])
    }

    private func contentRow(_ title: String, subtitle: String?, symbol: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).font(.system(size: 18)).foregroundStyle(Color.accentColor).frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.subheadline.weight(.semibold))
                if let subtitle, !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .beButton(action).buttonStyle(.plain)
    }
}

private struct ContentPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    let imageURL: String?
    let advertisement: Advertisement?
    @ObservedObject private var advertisements = AdvertisementStore.shared
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Group {
                if let advertisement {
                    if let current = advertisements.items.first(where: { $0.adID == advertisement.adID }) {
                        AdvertisementImage(advertisement: current, contentMode: .fit)
                    } else { Label("宣传图片已下架", systemImage: "photo").foregroundStyle(.white) }
                }
                else {
                    RemoteImageView(url: imageURL.flatMap(URL.init(string:)), contentMode: .fit) {
                        Image(systemName: "photo").foregroundStyle(.white.opacity(0.6))
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            Image(systemName: "xmark.circle.fill").font(.largeTitle).foregroundStyle(.white)
                .padding().beButton { dismiss() }.accessibilityLabel("关闭图片")
        }
    }
}
