import Combine
import Foundation

@MainActor
final class WatchScheduleStore: ObservableObject {
    @Published private(set) var updatedAt: [WatchCalendarKind: Date] = [:]
    @Published private(set) var hasStarted = false
    private let api: WatchAPI
    private let cache: WatchDocumentCache
    private var subscriptions: Set<AnyCancellable> = []
    private var lastRefresh: Date?
    private var refreshing = false

    lazy var courses = makeList(.courses)
    lazy var school = makeList(.school)

    init(api: WatchAPI, cache: WatchDocumentCache = WatchDocumentCache()) {
        self.api = api
        self.cache = cache
        for list in [courses, school] {
            list.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &subscriptions)
        }
    }

    func list(_ kind: WatchCalendarKind) -> LoadableListViewModel<WatchCalendarEntry> {
        kind == .courses ? courses : school
    }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        for kind in WatchCalendarKind.allCases {
            if let document = await cache.load(kind) {
                list(kind).items = WatchCalendarData.parse(document)
                updatedAt[kind] = document.fetchedAt
            }
        }
        await refresh()
    }

    func refreshIfNeeded() async {
        guard hasStarted, !refreshing else { return }
        guard lastRefresh == nil || Date().timeIntervalSince(lastRefresh!) > 300 else { return }
        await refresh()
    }

    func refresh() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false; lastRefresh = Date() }
        async let first: Void = courses.load()
        async let second: Void = school.load()
        _ = await (first, second)
    }

    private func makeList(_ kind: WatchCalendarKind) -> LoadableListViewModel<WatchCalendarEntry> {
        LoadableListViewModel { [weak self] in
            guard let self else { return [] }
            let document = try await self.api.fetch(kind)
            try Task.checkCancellation()
            let entries = WatchCalendarData.parse(document)
            // A cache write failure must not hide successfully fetched events.
            try? await self.cache.save(document)
            self.updatedAt[kind] = document.fetchedAt
            return entries
        }
    }
}
