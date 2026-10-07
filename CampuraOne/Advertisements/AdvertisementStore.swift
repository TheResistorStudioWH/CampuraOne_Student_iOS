import SwiftUI
import Combine
import ImageIO

/// One authority for both placements. Never restore an unverified ad list from disk.
@MainActor
final class AdvertisementStore: ObservableObject {
    static let shared = AdvertisementStore()
    @Published private(set) var items: [Advertisement] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    private var catalog: [Advertisement] = []
    private var assets: [Int: AdvertisementAsset] = [:]
    private var scope: String?
    private var generation = UUID()
    private var lastVerified: Date?
    private var refreshing = false
    private let images = NSCache<NSString, UIImage>()

    init() { images.totalCostLimit = 24 * 1024 * 1024 }

    func run(userID: Int) async {
        guard !Task.isCancelled else { return }
        let runID = UUID()
        generation = runID
        scope = "\(userID)"
        items = []
        catalog = []
        assets = [:]
        lastVerified = nil
        refreshing = false
        images.removeAllObjects()
        // Expiration must keep running while a slow metadata request is in flight.
        let expiration = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
                guard let self, self.generation == runID else { break }
                await self.expire()
            }
        }
        defer { expiration.cancel() }
        await refresh()
        while !Task.isCancelled, generation == runID {
            do { try await Task.sleep(for: .seconds(1)) } catch { break }
            guard generation == runID, !Task.isCancelled else { break }
            if Date().timeIntervalSince(lastVerified ?? .distantPast) >= 30 {
                await refresh()
                // Avoid a tight retry loop when offline.
                if errorMessage != nil { try? await Task.sleep(for: .seconds(5)) }
            }
        }
        if generation == runID { await pause() }
    }

    func pause() async {
        generation = UUID()
        scope = nil
        items = []
        catalog = []
        assets = [:]
        images.removeAllObjects()
        refreshing = false
        isLoading = false
        await AdvertisementAssets.shared.suspend()
    }

    func clearSession() async {
        await pause()
        guard !Task.isCancelled, scope == nil else { return }
        try? await AdvertisementAssets.shared.reconcile([])
    }

    func refresh() async {
        guard let scope, !refreshing else { return }
        let runID = generation
        refreshing = true
        isLoading = items.isEmpty
        defer {
            if generation == runID { refreshing = false; isLoading = false }
        }
        do {
            let result = try await RemoteDataService.shared.fetchAdvertisements(onlyActive: true)
            try Task.checkCancellation()
            guard generation == runID else { return }
            let now = Date()
            let current = result.activeAdvertisements(at: now)
            let newAssets = Dictionary(current.compactMap { ad -> (Int, AdvertisementAsset)? in
                guard let url = ad.imageURL, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
                // Legacy servers also return updatedAt; missing revisions revalidate daily.
                let revision = ad.imageRevision ?? "day-\(Int(now.timeIntervalSince1970 / 86400))"
                return (ad.adID, AdvertisementAsset(scope: scope, adID: ad.adID, url: url,
                    revision: "\(revision)|\(ad.startTime.timeIntervalSince1970)|\(ad.endTime?.timeIntervalSince1970 ?? 0)",
                    expiresAt: ad.endTime ?? Date(timeIntervalSince1970: (floor(now.timeIntervalSince1970 / 86400) + 1) * 86400)))
            }, uniquingKeysWith: { _, new in new })
            // Remove stale UI immediately, before asynchronous disk reconciliation.
            items.removeAll { ad in newAssets[ad.adID] != assets[ad.adID] }
            catalog = items
            for (id, old) in assets where newAssets[id] != old { images.removeObject(forKey: old.key as NSString) }
            assets = newAssets
            try await AdvertisementAssets.shared.reconcile(Array(newAssets.values))
            guard generation == runID, !Task.isCancelled else { return }
            catalog = current.filter { newAssets[$0.adID] != nil }
            lastVerified = now
            errorMessage = nil
            items = catalog
        } catch {
            guard generation == runID, !Task.isCancelled else { return }
            errorMessage = "暂时无法核对广告状态"
            await expire()
        }
    }

    private func expire() async {
        let runID = generation
        let now = Date()
        let expired = assets.filter { $0.value.expiresAt <= now }
        if !expired.isEmpty {
            for (id, asset) in expired { assets.removeValue(forKey: id); images.removeObject(forKey: asset.key as NSString) }
            catalog.removeAll { !$0.isActive(at: now) || assets[$0.adID] == nil }
            try? await AdvertisementAssets.shared.reconcile(Array(assets.values))
        }
        // Offline is not evidence of withdrawal: keep reusable disk bytes, but
        // stop displaying after a short verified lease, even for endless campaigns.
        guard generation == runID, !Task.isCancelled else { return }
        items = Date().timeIntervalSince(lastVerified ?? .distantPast) < 60 ? catalog : []
    }

    func asset(for ad: Advertisement) -> AdvertisementAsset? {
        guard items.contains(ad), ad.isActive() else { return nil }
        return assets[ad.adID]
    }

    func image(for asset: AdvertisementAsset) async throws -> UIImage {
        guard assets[asset.adID] == asset else { throw AdvertisementAssetError.withdrawn }
        if let cached = images.object(forKey: asset.key as NSString) { return cached }
        let data = try await AdvertisementAssets.shared.data(for: asset)
        try Task.checkCancellation()
        guard assets[asset.adID] == asset, asset.expiresAt > .now else { throw AdvertisementAssetError.withdrawn }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1600,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else {
            await AdvertisementAssets.shared.discard(asset)
            throw AdvertisementAssetError.invalidResponse
        }
        let image = UIImage(cgImage: thumbnail)
        images.setObject(image, forKey: asset.key as NSString, cost: thumbnail.bytesPerRow * thumbnail.height)
        return image
    }
}

struct AdvertisementImage: View {
    let advertisement: Advertisement
    var contentMode: ContentMode = .fit
    @ObservedObject private var store = AdvertisementStore.shared
    @State private var image: UIImage?
    @State private var loadedKey: String?
    @State private var failed = false
    @State private var attempt = 0

    var body: some View {
        let asset = store.asset(for: advertisement)
        ZStack {
            Rectangle().fill(.quaternary)
            if let image, let asset, loadedKey == asset.key {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else if failed {
                Button { attempt += 1 } label: {
                    Label("重新加载图片", systemImage: "arrow.clockwise")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else if asset != nil {
                ProgressView()
            }
        }
        .clipped()
        .task(id: "\(asset?.key ?? "none")-\(attempt)") {
            image = nil
            loadedKey = nil
            failed = false
            guard let asset else { return }
            do {
                let loaded = try await store.image(for: asset)
                try Task.checkCancellation()
                guard store.asset(for: advertisement) == asset else { return }
                image = loaded
                loadedKey = asset.key
            } catch {
                if !Task.isCancelled, store.asset(for: advertisement) == asset { failed = true }
            }
        }
        .accessibilityLabel("广告 \(advertisement.adID)")
    }
}
