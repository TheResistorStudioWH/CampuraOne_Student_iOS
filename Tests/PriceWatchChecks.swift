import Foundation

@MainActor private final class MemoryRepository: PriceWatchRepository {
    var values: [PriceWatchScope: PriceWatchSnapshot] = [:]
    var failLoad = false, failSave = false
    enum Failure: Error { case unavailable }
    func load(scope: PriceWatchScope) throws -> PriceWatchSnapshot {
        if failLoad { throw Failure.unavailable }; return values[scope] ?? .init()
    }
    func save(_ value: PriceWatchSnapshot, scope: PriceWatchScope) throws {
        if failSave { throw Failure.unavailable }; values[scope] = value
    }
}

@main struct PriceWatchChecks {
    @MainActor static func main() throws {
        var count = 0
        func check(_ value: @autoclosure () -> Bool, _ label: String) {
            precondition(value(), label); count += 1
        }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let product = WatchedProduct(id: 6, title: "商品", merchantName: "商家", priceAtFollow: Decimal(string: "12.30")!, followedAt: now)
        let event = WatchedPromotion(id: 9, title: "活动", merchantName: "商家", startsAt: now.addingTimeInterval(1800), endsAt: now.addingTimeInterval(3600), followedAt: now)
        let repo = MemoryRepository()
        var removed: [(PriceWatchScope, Int)] = [], opened: [Int] = []
        let store = PriceWatchStore(repository: repo, promotionRemoved: { removed.append(($0, $1)) }, openPromotion: { opened.append($0) })
        store.bind(userID: 1, studentID: 11)
        let ticket = store.identity
        check(!store.canEdit, "School must be resolved before follow changes")
        store.resolveSchool(1, studentID: 11, for: ticket)
        check(store.canEdit && store.snapshot == PriceWatchSnapshot(), "New account starts without fixtures")
        store.toggleProduct(product); store.togglePromotion(event)
        check(store.snapshot.products == [product] && store.snapshot.promotions == [event], "Follows persist actual supplied snapshots")
        check(store.snapshot.notices.isEmpty, "Following creates no fake price or promotion notices")
        let restarted = PriceWatchStore(repository: repo)
        restarted.bind(userID: 1, studentID: 11)
        restarted.resolveSchool(1, studentID: 11, for: restarted.identity)
        check(restarted.snapshot.products.first?.priceAtFollow == Decimal(string: "12.30"), "Follow baseline survives restart without float conversion")
        repo.failSave = true; store.removeProduct(6)
        check(store.snapshot.products.count == 1 && store.errorMessage != nil, "Failed persistence does not pretend removal succeeded")
        store.removePromotion(9)
        check(removed.isEmpty && store.snapshot.promotions.count == 1, "Failed unfollow does not end countdown")
        repo.failSave = false; store.removePromotion(9)
        check(removed.count == 1 && removed.first?.0 == PriceWatchScope(userID: 1, schoolID: 1), "Successful removal ends only matching scope activity")
        store.bind(userID: nil, studentID: nil)
        check(store.snapshot == .init() && !store.canEdit, "Sign-out clears memory")
        store.bind(userID: 2, studentID: 22)
        store.resolveSchool(1, studentID: 11, for: ticket)
        check(store.scope == nil, "Old account profile completion is ignored")
        store.resolveSchool(1, studentID: 22, for: store.identity)
        check(store.snapshot.products.isEmpty, "Different users cannot read each other's follows")
        store.bind(userID: 1, studentID: 11)
        store.resolveSchool(2, studentID: 11, for: store.identity)
        check(store.snapshot.products.isEmpty, "Same user at a different school has separate follows")
        store.resolveSchool(1, studentID: 11, for: store.identity)
        check(store.snapshot.products == [product], "Returning to original scope restores its records")
        store.toggleProduct(product)
        check(store.snapshot.products.isEmpty, "Toggling watched product removes it")
        repo.failLoad = true
        store.bind(userID: 3, studentID: 33)
        store.resolveSchool(1, studentID: 33, for: store.identity)
        store.toggleProduct(product)
        check(!store.canEdit && store.snapshot.products.isEmpty && store.errorMessage != nil, "Failed load cannot overwrite stored data with an empty snapshot")
        repo.failLoad = false
        store.resolveSchool(1, studentID: 33, for: store.identity)
        check(store.canEdit && store.errorMessage == nil, "Existing profile refresh can recover a failed local read")
        store.bind(userID: nil, studentID: nil)
        store.handlePromotionURL(URL(string: "campuraone://promotion/9?scope=u1-s1")!, expectedScheme: "campuraone")
        check(opened.isEmpty, "Deep link waits for signed-in school scope")
        store.bind(userID: 1, studentID: 11); store.resolveSchool(1, studentID: 11, for: store.identity)
        check(opened == [9], "Pending link opens only after matching scope resolves")
        store.handlePromotionURL(URL(string: "campuraone://promotion/9?scope=u2-s1")!, expectedScheme: "campuraone")
        check(opened == [9], "Cross-account activity link cannot open under current user")
        store.handlePromotionURL(URL(string: "campuraone-demo://promotion/9?scope=u1-s1")!, expectedScheme: "campuraone")
        check(opened == [9], "Demo links are not handled by production scheme")
        func eligible(_ delta: Double, end: Double? = nil, enabled: Bool = true) -> PromotionCountdownEligibility {
            .evaluate(startsAt: now.addingTimeInterval(delta), endsAt: end.map { now.addingTimeInterval($0) }, now: now, enabled: enabled)
        }
        check(eligible(1) == .available, "Upcoming event permits local start")
        check(eligible(8 * 3600 - 1) == .available, "Just below eight hours remains permitted")
        check(eligible(8 * 3600) == .tooFar && eligible(9 * 3600) == .tooFar, "Eight-hour limit is enforced")
        check(eligible(0) == .alreadyStarted && eligible(-1) == .alreadyStarted, "Zero and negative countdowns cannot start")
        check(eligible(-60, end: -1) == .ended, "Finished event is explicit")
        check(eligible(1800, enabled: false) == .disabled, "System authorization prevents start")
        var revisedStops = 0
        let revisedStore = PriceWatchStore(repository: MemoryRepository(), promotionRemoved: { _, _ in revisedStops += 1 })
        revisedStore.bind(userID: 1, studentID: 11)
        revisedStore.resolveSchool(1, studentID: 11, for: revisedStore.identity)
        revisedStore.togglePromotion(event)
        let revised = WatchedPromotion(id: event.id, title: "改期活动", merchantName: event.merchantName,
            startsAt: event.startsAt.addingTimeInterval(60), endsAt: event.endsAt, followedAt: now.addingTimeInterval(60))
        revisedStore.refreshPromotion(revised)
        check(revisedStore.snapshot.promotions.first?.followedAt == event.followedAt && revisedStops == 1,
              "Detail refresh preserves follow time and stops obsolete countdown on reschedule")
        check(revisedStore.snapshot.notices.isEmpty, "Detail refresh never invents new-promotion notices")
        revisedStore.refreshPromotion(.init(id: 999, title: "未关注", merchantName: "", startsAt: now, endsAt: nil, followedAt: now))
        check(revisedStore.snapshot.promotions.count == 1, "Detail refresh does not silently follow another promotion")
        let suite = "campura.pricewatch.checks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let disk = LocalPriceWatchRepository(defaults: defaults), scope = PriceWatchScope(userID: 1, schoolID: 1)
        try disk.save(.init(products: [product], promotions: [event]), scope: scope)
        let saved = try disk.load(scope: scope)
        let other = try disk.load(scope: .init(userID: 2, schoolID: 1))
        check(saved.products == [product], "Local repository roundtrips Codable Decimal snapshots")
        check(other.products.isEmpty, "Disk keys are account scoped")
        print("Price watch checks passed: \(count)")
    }
}
