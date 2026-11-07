import Foundation

nonisolated struct PriceWatchScope: Codable, Hashable {
    let userID: Int
    let schoolID: Int
    var storageKey: String { "u\(userID)-s\(schoolID)" }
}

nonisolated struct WatchedProduct: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let merchantName: String
    let priceAtFollow: Decimal
    let followedAt: Date
}

nonisolated struct WatchedPromotion: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let merchantName: String
    let startsAt: Date
    let endsAt: Date?
    let followedAt: Date
}

/// These are supplied records, never inferred from a promotion's free-form rules.
nonisolated struct PriceWatchNotice: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case priceDrop, promotion }
    let id: String
    let kind: Kind
    let targetID: Int
    let title: String
    let message: String
    let occurredAt: Date
}

nonisolated struct PriceWatchSnapshot: Codable, Equatable {
    var products: [WatchedProduct] = []
    var promotions: [WatchedPromotion] = []
    var notices: [PriceWatchNotice] = []
}

nonisolated enum PromotionCountdownEligibility: Equatable {
    case available, disabled, alreadyStarted, ended, tooFar
    var message: String? {
        switch self {
        case .available: nil
        case .disabled: "系统已关闭实时活动，可在设置中打开。"
        case .alreadyStarted: "计划开始时间已到。"
        case .ended: "活动已结束。"
        case .tooFar: "距离开始较远，请在开始前 8 小时内开启。"
        }
    }
    static func evaluate(startsAt: Date, endsAt: Date?, now: Date, enabled: Bool) -> Self {
        if let endsAt, endsAt <= now { return .ended }
        if startsAt <= now { return .alreadyStarted }
        if startsAt.timeIntervalSince(now) >= 8 * 3600 { return .tooFar }
        return enabled ? .available : .disabled
    }
}
