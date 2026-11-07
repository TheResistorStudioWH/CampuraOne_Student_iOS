import Foundation
import Combine
import ActivityKit

@MainActor
final class PromotionLiveActivityController: ObservableObject {
    static let shared = PromotionLiveActivityController()
    @Published private(set) var activeSaleIDs: Set<Int> = []
    @Published private(set) var startingSaleIDs: Set<Int> = []
    @Published private(set) var errorMessage: String?
    private var scope: PriceWatchScope?
    private var generation = UUID()
    static var urlScheme: String { Bundle.main.bundleIdentifier?.hasSuffix(".demo") == true ? "campuraone-demo" : "campuraone" }
    var isEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    func bind(scope: PriceWatchScope?) {
        self.scope = scope; generation = UUID(); activeSaleIDs = []; startingSaleIDs = []; errorMessage = nil
        Task { await reconcile() }
    }
    func eligibility(_ event: WatchedPromotion, now: Date = .now) -> PromotionCountdownEligibility {
        .evaluate(startsAt: event.startsAt, endsAt: event.endsAt, now: now, enabled: isEnabled)
    }
    func start(_ event: WatchedPromotion) async {
        guard let scope, PriceWatchStore.shared.scope == scope,
              PriceWatchStore.shared.snapshot.promotions.contains(where: { $0.id == event.id }),
              !startingSaleIDs.contains(event.id) else { return }
        guard eligibility(event) == .available else { errorMessage = eligibility(event).message; return }
        let ticket = generation
        startingSaleIDs.insert(event.id)
        defer { if ticket == generation { startingSaleIDs.remove(event.id) } }
        errorMessage = nil
        await reconcile()
        guard ticket == generation, !activeSaleIDs.contains(event.id) else { return }
        var components = URLComponents()
        components.scheme = Self.urlScheme; components.host = "promotion"; components.path = "/\(event.id)"
        components.queryItems = [URLQueryItem(name: "scope", value: scope.storageKey)]
        guard let url = components.url else { return }
        let attributes = PromotionActivityAttributes(scopeID: scope.storageKey, saleID: event.id,
            title: event.title, merchantName: event.merchantName, detailURL: url)
        do {
            let activity = try Activity<PromotionActivityAttributes>.request(attributes: attributes,
                content: ActivityContent(state: .init(countdownFrom: .now, startsAt: event.startsAt), staleDate: event.startsAt), pushType: nil)
            guard ticket == generation,
                  PriceWatchStore.shared.snapshot.promotions.contains(where: { $0.id == event.id }) else {
                await activity.end(nil, dismissalPolicy: .immediate); return
            }
            activeSaleIDs.insert(event.id)
        } catch { errorMessage = "暂时无法开启实时活动，请检查系统设置或稍后重试。" }
    }
    func stop(scope: PriceWatchScope, saleID: Int) async {
        for activity in Activity<PromotionActivityAttributes>.activities
        where activity.attributes.scopeID == scope.storageKey && activity.attributes.saleID == saleID {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        if self.scope == scope { activeSaleIDs.remove(saleID) }
    }
    func reconcile() async {
        let ticket = generation, scope = scope
        let follows = PriceWatchStore.shared.snapshot.promotions
        var active: Set<Int> = []
        for activity in Activity<PromotionActivityAttributes>.activities {
            guard ticket == generation else { return }
            // A restored login is still resolving its school. Keep its own
            // countdown alive until the existing profile response arrives.
            if scope == nil, let identity = PriceWatchStore.shared.identity,
               activity.attributes.scopeID.hasPrefix("u\(identity.userID)-"),
               activity.content.state.startsAt > .now { continue }
            let event = follows.first { $0.id == activity.attributes.saleID }
            if activity.attributes.scopeID != scope?.storageKey || event == nil
                || activity.content.state.startsAt <= .now
                || event?.startsAt != activity.content.state.startsAt {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else if activity.activityState == .active || activity.activityState == .stale {
                active.insert(activity.attributes.saleID)
            }
        }
        if ticket == generation { activeSaleIDs = active }
    }
}
