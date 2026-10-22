import Foundation

@MainActor private final class Clock {
    var date = APIDate.parse("2026-10-22 12:00:00")!
    func advance(_ seconds: TimeInterval) { date.addTimeInterval(seconds) }
}

private enum FixtureError: Error { case unavailable }

@MainActor private func notice(
    _ id: Int, type: AnnouncementType = .importantMarkdown,
    start: Date? = nil, end: Date? = nil, content: String = "测试通知"
) -> AnnouncementItem {
    AnnouncementItem(announceID: id, schoolID: 1, content: content, type: type,
                     target: nil, startTime: start, endTime: end,
                     createdAt: nil, updatedAt: nil)
}

@MainActor private final class Fixture {
    let clock = Clock()
    var items = [notice(1)]
    var listCalls = 0
    var summaryCalls = 0
    var failList = false
    var failSummary = false
    var response = AnnouncementSummary(summary: "今晚查寝。", sourceIDs: [1], isAI: true)

    func makeStore() -> AnnouncementStore {
        AnnouncementStore(
            fetchAnnouncements: { _ in
                self.listCalls += 1
                if self.failList { throw FixtureError.unavailable }
                return self.items
            },
            fetchSummary: {
                self.summaryCalls += 1
                if self.failSummary { throw FixtureError.unavailable }
                return self.response
            },
            now: { self.clock.date }
        )
    }
}

/// Deliberately ignores cancellation, as a response already in transit might.
@MainActor private final class HeldSummary {
    var continuation: CheckedContinuation<AnnouncementSummary, Never>?
    func fetch() async -> AnnouncementSummary {
        await withCheckedContinuation { continuation = $0 }
    }
    func finish(_ response: AnnouncementSummary) {
        continuation?.resume(returning: response)
        continuation = nil
    }
}

@main @MainActor struct AnnouncementStoreChecks {
    static var checks = 0

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        precondition(condition(), message)
        checks += 1
    }

    static func waitUntil(_ ready: () -> Bool) async {
        for _ in 0..<10_000 {
            if ready() { return }
            await Task.yield()
        }
        fatalError("Offline fixture did not reach expected state")
    }

    static func main() async {
        datesAndVisibility()
        await retryAndCache()
        await retryBudgetAndForeground()
        await listFailureAndEmptyList()
        await expiryAndSourceChanges()
        await invalidSummaries()
        await lateResultsAndAccountSwitch()
        print("PASS: \(checks) announcement checks (offline, no API/AI calls)")
    }

    static func datesAndVisibility() {
        let date = APIDate.parse("2026-10-22T04:00:00Z")!
        for value in ["2026-10-22 12:00:00", "2026-10-22T12:00:00+08:00",
                      "2026-10-22T04:00:00.000Z", "2026/10/22 12:00:00",
                      " 2026-10-22T12:00:00 \n"] {
            check(APIDate.parse(value) == date, "Timezone/format mismatch: \(value)")
        }
        let deviceZone = NSTimeZone.default
        NSTimeZone.default = TimeZone(identifier: "America/New_York")!
        check(APIDate.parse("2026-10-22 12:00:00") == date, "Server dates must not use device timezone")
        NSTimeZone.default = deviceZone
        check(APIDate.parse("2026-10-22") == APIDate.parse("2026-10-21T16:00:00Z"), "Date-only uses Beijing midnight")
        check(APIDate.parse("2024-02-29") != nil, "Leap day")
        for value in ["2026-02-30 12:00:00", "2026-02-29", "", "not a date", "2026-13-01"] {
            check(APIDate.parse(value) == nil, "Invalid date must not normalize")
        }
        check(APIDate.parse(nil) == nil, "Nil date")
        check(notice(1).isActive(at: date), "Unbounded notice")
        check(notice(1, start: date, end: date).isActive(at: date), "Inclusive API bounds")
        check(!notice(1, start: date.addingTimeInterval(1)).isActive(at: date), "Scheduled notice")
        check(!notice(1, end: date.addingTimeInterval(-1)).isActive(at: date), "Expired notice")
        check(!notice(1, start: date.addingTimeInterval(1), end: date).isActive(at: date), "Inverted range")
        let items = [notice(1), notice(2), notice(3, type: .dailyShort),
                     notice(4, type: .emergencyShort), notice(5, end: date.addingTimeInterval(-1)),
                     notice(6, start: date.addingTimeInterval(1))]
        check(items.activeMarkdown(at: date).map(\.announceID) == [2, 1],
              "Badge and sheet must include ALL and ONLY active Markdown notices")
    }

    static func retryAndCache() async {
        let fixture = Fixture()
        fixture.failSummary = true
        let store = fixture.makeStore()
        await store.load(for: 1)
        check(fixture.summaryCalls == 1 && store.aiSummary == nil, "Initial AI failure")
        await store.load(for: 1)
        fixture.clock.advance(4)
        await store.load(for: 1)
        check(fixture.summaryCalls == 1, "No immediate retry storm")
        fixture.clock.advance(1)
        await store.load(for: 1)
        check(fixture.summaryCalls == 2 && fixture.listCalls == 1, "Retry even with a cached list")
        fixture.clock.advance(29)
        await store.load(for: 1)
        check(fixture.summaryCalls == 2, "Second backoff is 30 seconds")
        fixture.failSummary = false
        fixture.clock.advance(1)
        await store.load(for: 1)
        check(fixture.summaryCalls == 3 && store.aiSummary == "今晚查寝。", "Retry recovers without relogin")
        fixture.clock.advance(25)
        await store.load(for: 1)
        check(fixture.listCalls == 2 && fixture.summaryCalls == 3, "List refresh reuses unchanged valid summary")
    }

    static func retryBudgetAndForeground() async {
        let fixture = Fixture()
        fixture.failSummary = true
        let store = fixture.makeStore()
        await store.load(for: 1)
        fixture.clock.advance(5)
        await store.load(for: 1)
        fixture.clock.advance(30)
        await store.load(for: 1)
        fixture.clock.advance(3600)
        await store.load(for: 1)
        check(fixture.summaryCalls == 3, "Stop after three attempts for unchanged sources")
        fixture.failSummary = false
        let foreground = Task { await store.run(for: 1) }
        await waitUntil { store.aiSummary != nil }
        check(fixture.summaryCalls == 4, "Foreground return grants a new retry budget")
        foreground.cancel()
        await foreground.value
        check(!store.isLoading, "Cancelled lifecycle cleans up loading state")

        let rapidFixture = Fixture()
        rapidFixture.failSummary = true
        let rapidStore = rapidFixture.makeStore()
        await rapidStore.load(for: 1)
        rapidFixture.clock.advance(2)
        let rapidForeground = Task { await rapidStore.run(for: 1) }
        await waitUntil { rapidFixture.listCalls == 2 }
        rapidForeground.cancel()
        await rapidForeground.value
        check(rapidFixture.summaryCalls == 1, "Rapid foreground toggles respect a 30-second cooldown")
        rapidFixture.clock.advance(28)
        await rapidStore.load(for: 1)
        check(rapidFixture.summaryCalls == 2, "Retry resumes after foreground cooldown")
    }

    static func listFailureAndEmptyList() async {
        let fixture = Fixture()
        fixture.failList = true
        let store = fixture.makeStore()
        await store.load(for: 1)
        await store.load(for: 1)
        check(fixture.listCalls == 1 && fixture.summaryCalls == 0, "List failure backs off too")
        fixture.clock.advance(30)
        fixture.failList = false
        fixture.items = []
        await store.load(for: 1)
        await store.load(for: 1)
        check(fixture.listCalls == 2 && fixture.summaryCalls == 0, "Empty list is cached; no paid summary")
        fixture.items = [notice(1)]
        fixture.clock.advance(60)
        await store.load(for: 1)
        check(store.announces.count == 1 && store.errorMessage == nil, "New notices appear after an empty list")
    }

    static func expiryAndSourceChanges() async {
        let fixture = Fixture()
        fixture.items = [
            notice(1, end: fixture.clock.date.addingTimeInterval(10)),
            notice(2, start: fixture.clock.date.addingTimeInterval(60)),
            notice(3, end: fixture.clock.date.addingTimeInterval(-1))
        ]
        let store = fixture.makeStore()
        await store.load(for: 1)
        check(store.announces.map(\.announceID) == [1], "Filter expired/future data from the API")
        fixture.clock.advance(11)
        store.refreshValidity()
        check(store.announces.isEmpty && store.aiSummary == nil, "Expiry removes notice and invalidates summary without network")
        fixture.clock.advance(49)
        fixture.response = AnnouncementSummary(summary: "领取材料。", sourceIDs: [2], isAI: true)
        await store.load(for: 1)
        check(store.announces.map(\.announceID) == [2], "Newly active notice appears on refresh")
        fixture.items = [notice(2, content: "更新后的正文")]
        fixture.response = AnnouncementSummary(summary: "明天领取材料。", sourceIDs: [2], isAI: true)
        fixture.clock.advance(60)
        await store.load(for: 1)
        check(store.aiSummary == "明天领取材料。", "Same ID with edited content invalidates summary")
        fixture.items = []
        fixture.clock.advance(60)
        await store.load(for: 1)
        check(store.announces.isEmpty && store.aiSummary == nil, "Authoritative withdrawal removes cached sources")
    }

    static func invalidSummaries() async {
        for response in [
            AnnouncementSummary(summary: "正文", sourceIDs: [1], isAI: false),
            AnnouncementSummary(summary: "正文", sourceIDs: [], isAI: true),
            AnnouncementSummary(summary: "正文", sourceIDs: [99], isAI: true),
            AnnouncementSummary(summary: "[1] \n ", sourceIDs: [1], isAI: true)
        ] {
            let fixture = Fixture()
            fixture.response = response
            let store = fixture.makeStore()
            await store.load(for: 1)
            check(store.aiSummary == nil, "Untrusted/empty summary must remain unavailable")
        }
        let fixture = Fixture()
        fixture.response = AnnouncementSummary(summary: "[1] 今晚\n 查寝。 ", sourceIDs: [1], isAI: true)
        let store = fixture.makeStore()
        await store.load(for: 1)
        check(store.aiSummary == "今晚 查寝。", "Keep existing compact text normalization")
    }

    static func lateResultsAndAccountSwitch() async {
        let clock = Clock()
        let held = HeldSummary()
        var calls = 0
        let store = AnnouncementStore(
            fetchAnnouncements: { id in [notice(id, end: clock.date.addingTimeInterval(10))] },
            fetchSummary: {
                calls += 1
                if calls == 1 { return await held.fetch() }
                return AnnouncementSummary(summary: "新账号通知。", sourceIDs: [2], isAI: true)
            },
            now: { clock.date }
        )
        let first = Task { await store.load(for: 1) }
        await waitUntil { held.continuation != nil }
        await store.load(for: 1)
        check(calls == 1, "Concurrent load shares in-flight work")
        await store.load(for: 2)
        held.finish(AnnouncementSummary(summary: "旧账号通知。", sourceIDs: [1], isAI: true))
        await first.value
        check(store.aiSummary == "新账号通知。" && store.announces.map(\.announceID) == [2],
              "Late response cannot overwrite a different account")
        let cancelledLoad = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            await store.load(for: nil)
            await store.run(for: 1)
        }
        await cancelledLoad.value
        check(store.aiSummary == "新账号通知。" && store.announces.map(\.announceID) == [2],
              "Already-cancelled work must not reset the current account")
        await store.load(for: nil)
        check(store.announces.isEmpty && store.aiSummary == nil, "Signed-out state clears sources")

        let expiredResponse = HeldSummary()
        let expiryStore = AnnouncementStore(
            fetchAnnouncements: { _ in [notice(1, end: clock.date.addingTimeInterval(1))] },
            fetchSummary: { await expiredResponse.fetch() }, now: { clock.date }
        )
        let pending = Task { await expiryStore.load(for: 1) }
        await waitUntil { expiredResponse.continuation != nil }
        clock.advance(2)
        expiryStore.refreshValidity()
        expiredResponse.finish(AnnouncementSummary(summary: "已经过期。", sourceIDs: [1], isAI: true))
        await pending.value
        check(expiryStore.aiSummary == nil && expiryStore.announces.isEmpty,
              "Expiry during a slow request rejects the stale summary")

        let pausedResponse = HeldSummary()
        let pausedStore = AnnouncementStore(
            fetchAnnouncements: { _ in [notice(1)] },
            fetchSummary: { await pausedResponse.fetch() }, now: { clock.date }
        )
        let background = Task { await pausedStore.load(for: 1) }
        await waitUntil { pausedResponse.continuation != nil }
        pausedStore.pause()
        pausedResponse.finish(AnnouncementSummary(summary: "后台迟到响应。", sourceIDs: [1], isAI: true))
        await background.value
        check(pausedStore.aiSummary == nil && !pausedStore.isLoading, "Pause rejects non-cooperative late responses")
    }
}
