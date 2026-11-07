import Foundation
import Combine

@MainActor
protocol PriceWatchRepository {
    func load(scope: PriceWatchScope) throws -> PriceWatchSnapshot
    func save(_ snapshot: PriceWatchSnapshot, scope: PriceWatchScope) throws
}

@MainActor
struct LocalPriceWatchRepository: PriceWatchRepository {
    var defaults: UserDefaults = .standard
    func load(scope: PriceWatchScope) throws -> PriceWatchSnapshot {
        guard let data = defaults.data(forKey: key(scope)) else { return .init() }
        return try JSONDecoder().decode(PriceWatchSnapshot.self, from: data)
    }
    func save(_ snapshot: PriceWatchSnapshot, scope: PriceWatchScope) throws {
        defaults.set(try JSONEncoder().encode(snapshot), forKey: key(scope))
    }
    private func key(_ scope: PriceWatchScope) -> String { "campura.price-watch.v1.\(scope.storageKey)" }
}

@MainActor
final class PriceWatchStore: ObservableObject {
    struct Identity: Equatable { let userID: Int; let studentID: Int; let generation: UUID }
    @Published private(set) var snapshot = PriceWatchSnapshot()
    @Published private(set) var scope: PriceWatchScope?
    @Published private(set) var errorMessage: String?
    private(set) var identity: Identity?
    private var didLoad = false
    private var pendingLink: (scope: String, saleID: Int)?
    private let repository: any PriceWatchRepository
    private let scopeChanged: (PriceWatchScope?) -> Void
    private let promotionRemoved: (PriceWatchScope, Int) -> Void
    private let openPromotion: (Int) -> Void

    init(repository: any PriceWatchRepository, scopeChanged: @escaping (PriceWatchScope?) -> Void = { _ in },
         promotionRemoved: @escaping (PriceWatchScope, Int) -> Void = { _, _ in },
         openPromotion: @escaping (Int) -> Void = { _ in }) {
        self.repository = repository; self.scopeChanged = scopeChanged
        self.promotionRemoved = promotionRemoved; self.openPromotion = openPromotion
    }

    var canEdit: Bool { scope != nil && didLoad }
    func bind(userID: Int?, studentID: Int?) {
        guard identity?.userID != userID || identity?.studentID != studentID else { return }
        identity = userID.flatMap { user in studentID.map { Identity(userID: user, studentID: $0, generation: UUID()) } }
        scope = nil; snapshot = .init(); didLoad = false; errorMessage = nil
        scopeChanged(nil)
    }

    /// Called by the existing profile request; never starts another request.
    func resolveSchool(_ schoolID: Int, studentID: Int, for ticket: Identity?) {
        guard let ticket, ticket == identity, ticket.studentID == studentID, schoolID > 0 else { return }
        let next = PriceWatchScope(userID: ticket.userID, schoolID: schoolID)
        guard scope != next || !didLoad else { return }
        scope = next; snapshot = .init(); didLoad = false
        do {
            snapshot = try repository.load(scope: next)
            snapshot.products.sort { $0.followedAt > $1.followedAt }
            snapshot.promotions.sort { $0.followedAt > $1.followedAt }
            didLoad = true; errorMessage = nil
        } catch { errorMessage = "暂时无法读取关注记录，请稍后重试。" }
        scopeChanged(next)
        deliverPendingLink()
    }

    func toggleProduct(_ product: WatchedProduct) {
        var next = snapshot
        if next.products.contains(where: { $0.id == product.id }) { next.products.removeAll { $0.id == product.id } }
        else { next.products.insert(product, at: 0) }
        persist(next)
    }
    func togglePromotion(_ event: WatchedPromotion) {
        if snapshot.promotions.contains(where: { $0.id == event.id }) { removePromotion(event.id); return }
        var next = snapshot; next.promotions.insert(event, at: 0); persist(next)
    }
    /// Refresh only when an already-viewed detail supplies authoritative data.
    /// This never polls, creates a new follow, or synthesizes a promotion notice.
    func refreshPromotion(_ event: WatchedPromotion) {
        guard let scope, let index = snapshot.promotions.firstIndex(where: { $0.id == event.id }) else { return }
        let previous = snapshot.promotions[index]
        let updated = WatchedPromotion(id: event.id, title: event.title, merchantName: event.merchantName,
            startsAt: event.startsAt, endsAt: event.endsAt, followedAt: previous.followedAt)
        guard updated != previous else { return }
        var next = snapshot; next.promotions[index] = updated
        if persist(next), previous.startsAt != updated.startsAt || previous.endsAt != updated.endsAt {
            promotionRemoved(scope, event.id)
        }
    }
    func removeProduct(_ id: Int) {
        var next = snapshot; next.products.removeAll { $0.id == id }; persist(next)
    }
    func removePromotion(_ id: Int) {
        guard let scope else { return }
        var next = snapshot; next.promotions.removeAll { $0.id == id }
        if persist(next) { promotionRemoved(scope, id) }
    }
    @discardableResult
    private func persist(_ next: PriceWatchSnapshot) -> Bool {
        guard let scope, didLoad else { return false }
        do {
            try repository.save(next, scope: scope)
            snapshot = next; errorMessage = nil; return true
        } catch { errorMessage = "保存失败，关注状态尚未更改。"; return false }
    }

    func handlePromotionURL(_ url: URL, expectedScheme: String) {
        guard url.scheme == expectedScheme, url.host == "promotion",
              let id = Int(url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))), id > 0,
              let key = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "scope" })?.value else { return }
        pendingLink = (key, id); deliverPendingLink()
    }
    private func deliverPendingLink() {
        guard let pendingLink, let scope else { return }
        self.pendingLink = nil
        guard pendingLink.scope == scope.storageKey else {
            errorMessage = "此活动属于其他账号或学校，请切换后查看。"; return
        }
        openPromotion(pendingLink.saleID)
    }
}
