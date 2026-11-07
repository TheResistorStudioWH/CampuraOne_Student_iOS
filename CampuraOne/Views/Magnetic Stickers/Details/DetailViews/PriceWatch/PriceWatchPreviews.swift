#if DEBUG
import SwiftUI

@MainActor
private final class PriceWatchPreviewRepository: PriceWatchRepository {
    var value: PriceWatchSnapshot
    init(_ value: PriceWatchSnapshot) { self.value = value }
    func load(scope: PriceWatchScope) throws -> PriceWatchSnapshot { value }
    func save(_ snapshot: PriceWatchSnapshot, scope: PriceWatchScope) throws { value = snapshot }
}

@MainActor
private enum PriceWatchPreviewData {
    static func store(populated: Bool) -> PriceWatchStore {
        let data = populated ? PriceWatchSnapshot(
            products: [.init(id: 1, title: "经典拿铁", merchantName: "校园咖啡", priceAtFollow: 16, followedAt: .now)],
            promotions: [.init(id: 1, title: "课间限时饮品活动", merchantName: "校园饮品店",
                              startsAt: .now.addingTimeInterval(1800), endsAt: .now.addingTimeInterval(5400), followedAt: .now)],
            notices: [.init(id: "preview-drop", kind: .priceDrop, targetID: 1, title: "经典拿铁降价", message: "标价由 ¥16 调整为 ¥14", occurredAt: .now),
                      .init(id: "preview-promotion", kind: .promotion, targetID: 1, title: "新的促销活动", message: "课间限时饮品活动即将开始", occurredAt: .now)]) : .init()
        let store = PriceWatchStore(repository: PriceWatchPreviewRepository(data))
        store.bind(userID: 1, studentID: 1)
        store.resolveSchool(1, studentID: 1, for: store.identity)
        return store
    }
}

#Preview("降价监控 · 空列表") {
    ScrollView { PriceWatchDetailView(store: PriceWatchPreviewData.store(populated: false)).padding() }
}
#Preview("降价监控 · 关注与消息") {
    ScrollView { PriceWatchDetailView(store: PriceWatchPreviewData.store(populated: true)).padding() }
}
#endif
