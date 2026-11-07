import SwiftUI
import PetaKitUIX

struct PriceWatchDetailView: DashboardDetailContent {
    static let tileDescriptor = DashboardTileDescriptor(id: "priceWatch", title: "降价监控", systemImage: "chart.line.downtrend.xyaxis")
    @ObservedObject var store: PriceWatchStore
    @State private var section = Section.products
    enum Section: String, CaseIterable { case products = "关注商品", promotions = "关注活动" }
    @MainActor init() { self.store = .shared }
    init(store: PriceWatchStore) { self.store = store }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Picker("关注类型", selection: $section) {
                ForEach(Section.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            if let message = store.errorMessage {
                Label(message, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.secondary)
            }
            if section == .products {
                if store.snapshot.products.isEmpty { empty("还没有关注的商品", detail: "在商品详情中点击“监控降价”，即可加入这里。", symbol: "bag") }
                ForEach(store.snapshot.products) { product in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(product.title).font(.headline)
                            Text(product.merchantName).font(.caption).foregroundStyle(.secondary)
                            Text("关注时 \(product.priceAtFollow.formatted(.currency(code: "CNY")))")
                                .font(.subheadline).foregroundStyle(.green)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .beButton { ContentBrowserStore.shared.open(.product(product.id)) }
                        removeButton(product.title) { store.removeProduct(product.id) }
                    }.padding(14).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 18))
                }
                noticeSection(kind: .priceDrop, title: "降价提醒", emptyText: "暂无价格变化记录")
            } else {
                if store.snapshot.promotions.isEmpty { empty("还没有关注的活动", detail: "在促销详情中关注活动，临近开始时可开启锁屏倒计时。", symbol: "tag") }
                ForEach(store.snapshot.promotions) { event in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(event.title).font(.headline).lineLimit(3)
                                Text(event.merchantName).font(.caption).foregroundStyle(.secondary)
                                Text(event.startsAt, format: .dateTime.month().day().hour().minute())
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .beButton { ContentBrowserStore.shared.open(.promotion(event.id)) }
                            removeButton(event.title) { store.removePromotion(event.id) }
                        }
                        PromotionCountdownButton(event: event)
                    }.padding(14).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 18))
                }
                noticeSection(kind: .promotion, title: "新促销提醒", emptyText: "暂无新促销记录")
            }
        }
        .buttonStyle(.plain)
    }

    private func empty(_ title: String, detail: String, symbol: String) -> some View {
        ContentUnavailableView(title, systemImage: symbol, description: Text(detail))
    }
    private func removeButton(_ title: String, action: @escaping () -> Void) -> some View {
        Image(systemName: "minus.circle").font(.title3).foregroundStyle(.secondary)
            .padding(6).contentShape(Rectangle()).beButton(action)
            .accessibilityLabel("取消关注\(title)")
    }
    private func noticeSection(kind: PriceWatchNotice.Kind, title: String, emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            let notices = store.snapshot.notices.filter { $0.kind == kind }.sorted { $0.occurredAt > $1.occurredAt }
            if notices.isEmpty { Text(emptyText).font(.subheadline).foregroundStyle(.secondary) }
            ForEach(notices) { notice in
                VStack(alignment: .leading, spacing: 5) {
                    Label(notice.title, systemImage: kind == .priceDrop ? "arrow.down.right" : "tag.fill")
                        .foregroundStyle(kind == .priceDrop ? .green : .orange)
                    Text(notice.message).font(.subheadline).foregroundStyle(.secondary)
                    Text(notice.occurredAt, style: .date).font(.caption2).foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .beButton {
                    ContentBrowserStore.shared.open(kind == .priceDrop ? .product(notice.targetID) : .promotion(notice.targetID))
                }
            }
        }
    }
}
