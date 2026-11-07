import Foundation
import ActivityKit

/// Shared only by the iPhone and widget targets. No credentials are included.
nonisolated struct PromotionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let countdownFrom: Date
        let startsAt: Date
    }
    let scopeID: String
    let saleID: Int
    let title: String
    let merchantName: String
    let detailURL: URL
}
