import Foundation

actor Downloads {
    private(set) var count = 0
    func fetch(_ url: URL) async throws -> Data {
        count += 1
        try await Task.sleep(for: .milliseconds(30))
        return Data(url.absoluteString.utf8)
    }
}

/// Deliberately ignores Task cancellation, like an already-completed transport.
actor HeldDownload {
    private var continuation: CheckedContinuation<Data, Never>?
    var started: Bool { continuation != nil }
    func fetch() async -> Data {
        await withCheckedContinuation { continuation = $0 }
    }
    func finish() { continuation?.resume(returning: Data([1, 2, 3])); continuation = nil }
}

@main struct AdvertisementCacheChecks {
    static func main() async throws {
        precondition(AdvertisementDate.parse("2026-10-06 08:00:00") == AdvertisementDate.parse("2026-10-06T00:00:00Z"))
        precondition(AdvertisementDate.parse("2026-02-30 08:00:00") == nil)
        precondition(AdvertisementDate.parse("not a date") == nil)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("campura-cache-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at: folder) }
        let downloads = Downloads()
        let cache = AdvertisementAssets(directory: folder, download: { try await downloads.fetch($0) })
        let url = URL(string: "https://example.invalid/ad.png")!
        func asset(_ revision: String = "1", scope: String = "student-a", expiry: Date = .now.addingTimeInterval(60)) -> AdvertisementAsset {
            AdvertisementAsset(scope: scope, adID: 1, url: url, revision: revision, expiresAt: expiry)
        }
        let first = asset()
        try await cache.reconcile([first])
        async let a = cache.data(for: first)
        async let b = cache.data(for: first)
        let (one, two) = try await (a, b)
        precondition(one == two)
        let count = await downloads.count
        precondition(count == 1, "Concurrent requests must share one download")
        _ = try await cache.data(for: first)
        let hitCount = await downloads.count
        precondition(hitCount == 1, "Disk cache hit must avoid download")
        await cache.suspend()
        try await cache.reconcile([first])
        _ = try await cache.data(for: first)
        let resumedCount = await downloads.count
        precondition(resumedCount == 1, "Resume must reuse revalidated bytes")
        let revised = asset("2")
        try await cache.reconcile([revised])
        precondition(!FileManager.default.fileExists(atPath: folder.appendingPathComponent(first.key).path))
        _ = try await cache.data(for: revised)
        precondition(first.key != revised.key && first.key != asset(scope: "student-b").key)
        try await cache.reconcile([])
        let withdrawnFiles = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        precondition(withdrawnFiles.isEmpty)
        do { _ = try await cache.data(for: revised); fatalError("Withdrawn asset must be rejected") }
        catch AdvertisementAssetError.withdrawn { }
        let expired = asset(expiry: .now.addingTimeInterval(-1))
        try await cache.reconcile([expired])
        do { _ = try await cache.data(for: expired); fatalError("Expired asset must be rejected") }
        catch AdvertisementAssetError.withdrawn { }
        try await cache.reconcile([first])
        let pending = Task { try await cache.data(for: first) }
        try await Task.sleep(for: .milliseconds(10))
        try await cache.reconcile([])
        do { _ = try await pending.value; fatalError("Late result must not survive withdrawal") }
        catch { }
        let lateFiles = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        precondition(lateFiles.isEmpty)
        try await cache.reconcile([first])
        _ = try await cache.data(for: first)
        let held = HeldDownload()
        let lateFolder = folder.appendingPathComponent("late")
        let lateCache = AdvertisementAssets(directory: lateFolder, download: { _ in await held.fetch() })
        try await lateCache.reconcile([first])
        let late = Task { try await lateCache.data(for: first) }
        while !(await held.started) { await Task.yield() }
        try await lateCache.reconcile([])
        // Re-adding the same key must not authorize the cancelled old request.
        try await lateCache.reconcile([first])
        await held.finish()
        do { _ = try await late.value; fatalError("Non-cooperative late transport must be rejected") }
        catch AdvertisementAssetError.withdrawn { }
        let staleFiles = try FileManager.default.contentsOfDirectory(atPath: lateFolder.path)
        precondition(staleFiles.isEmpty)
        print("PASS: date/timezone, shared download, disk hit, resume, revision, account isolation, withdrawal, expiry, cancellation, re-add, non-cooperative late result")
    }
}
