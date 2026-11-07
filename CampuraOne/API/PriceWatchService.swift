import Foundation

extension PriceWatchStore {
    static let shared = PriceWatchStore(repository: LocalPriceWatchRepository(),
        scopeChanged: { PromotionLiveActivityController.shared.bind(scope: $0) },
        promotionRemoved: { scope, id in Task { await PromotionLiveActivityController.shared.stop(scope: scope, saleID: id) } },
        openPromotion: { ContentBrowserStore.shared.open(.promotion($0)) })
}
