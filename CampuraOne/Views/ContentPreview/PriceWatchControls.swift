import SwiftUI
import PetaKitUIX
import PetaToolKit

struct ProductPriceWatchButton: View {
    let product: Product
    let merchantName: String
    @ObservedObject private var store = PriceWatchStore.shared
    private var isWatched: Bool { store.snapshot.products.contains { $0.id == product.productID } }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(isWatched ? "已监控" : "监控降价", systemImage: isWatched ? "bell.badge.fill" : "bell.badge")
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color.green.opacity(0.12), in: Capsule()).foregroundStyle(.green)
                .beButton {
                    guard product.productPrice.isFinite, product.productPrice >= 0,
                          let price = Decimal(string: String(product.productPrice), locale: Locale(identifier: "en_US_POSIX")) else { return }
                    store.toggleProduct(.init(id: product.productID, title: product.productName,
                        merchantName: merchantName, priceAtFollow: price, followedAt: .now))
                    Haptics.play(.soft)
                }
                .buttonStyle(.plain).disabled(!store.canEdit)
                .accessibilityIdentifier("price-watch.product.toggle")
            if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct PromotionWatchControls: View {
    let event: SaleEvent
    let merchantName: String
    @ObservedObject private var store = PriceWatchStore.shared
    private var followed: WatchedPromotion? { store.snapshot.promotions.first { $0.id == event.saleID } }
    private var snapshot: WatchedPromotion {
        .init(id: event.saleID, title: event.displayTitle, merchantName: merchantName,
              startsAt: event.startTime, endsAt: event.endTime, followedAt: .now)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(followed == nil ? "关注活动" : "已关注", systemImage: followed == nil ? "star" : "star.fill")
                .font(.subheadline.weight(.semibold)).foregroundStyle(.orange)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color.orange.opacity(0.12), in: Capsule())
                .beButton {
                    store.togglePromotion(snapshot)
                    Haptics.play(.soft)
                }
                .buttonStyle(.plain).disabled(!store.canEdit)
                .accessibilityIdentifier("price-watch.promotion.toggle")
            if let followed { PromotionCountdownButton(event: followed) }
            if let error = store.errorMessage { Text(error).font(.caption).foregroundStyle(.secondary) }
        }
        .onAppear { store.refreshPromotion(snapshot) }
        .onChange(of: event) { _, _ in store.refreshPromotion(snapshot) }
    }
}

struct PromotionCountdownButton: View {
    let event: WatchedPromotion
    @ObservedObject private var controller = PromotionLiveActivityController.shared
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let eligibility = controller.eligibility(event, now: context.date)
            let active = controller.activeSaleIDs.contains(event.id)
            let starting = controller.startingSaleIDs.contains(event.id)
            VStack(alignment: .leading, spacing: 5) {
                Label(active ? "锁屏倒计时已开启" : "开启锁屏倒计时", systemImage: "hourglass")
                    .font(.subheadline.weight(.medium)).foregroundStyle(.orange)
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Color.orange.opacity(0.1), in: Capsule())
                    .beButton { Task { await controller.start(event) } }
                    .buttonStyle(.plain).disabled(active || starting || eligibility != .available)
                    .accessibilityIdentifier("price-watch.countdown.start")
                if let message = eligibility.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                if let message = controller.errorMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .task { await controller.reconcile() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await controller.reconcile() } }
        }
    }
}
