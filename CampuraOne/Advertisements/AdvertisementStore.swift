import SwiftUI
import PetaKitUIX
import Combine
import ImageIO
#if DEBUG
import SwiftyJSON
#endif

/// An image belongs to one verified ad revision and one signed-in account.
/// No advertisement image is read from or written to a persistent disk cache.
private struct AdvertisementSnapshotKey: Hashable {
    let userID: String
    let adID: Int
    let url: URL
    let revision: String
    let expiresAt: Date
}

@MainActor
final class AdvertisementStore: ObservableObject {
    static let shared = AdvertisementStore()

    @Published private(set) var items: [Advertisement] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private var snapshots: [AdvertisementSnapshotKey: UIImage] = [:]
    @Published private var failedImages: Set<Int> = []

    private var catalog: [Advertisement] = []
    private var descriptors: [Int: AdvertisementSnapshotKey] = [:]
    private var imageLoads: [Int: (key: AdvertisementSnapshotKey, task: Task<Void, Never>)] = [:]
    private var scope: String?
    private var snapshotOwner: String?
    private var generation = UUID()
    private var lastVerified: Date?
    private var refreshing = false

    private init() {
        #if DEBUG
        if PreviewAPI.isEnabled {
            items = PreviewAPI.advertisementRows.map { JSONMapper.makeAdvertisement(from: JSON($0)) }
        }
        #endif
    }

    func run(userID: Int) async {
        #if DEBUG
        if PreviewAPI.isEnabled {
            await refresh()
            return
        }
        #endif
        guard !Task.isCancelled else { return }
        let owner = String(userID)
        let runID = UUID()
        generation = runID
        if snapshotOwner != owner {
            snapshots = [:]
            snapshotOwner = owner
        }
        scope = owner
        items = []
        catalog = []
        descriptors = [:]
        failedImages = []
        lastVerified = nil
        refreshing = false

        // Expiration continues while a slow metadata request is in flight.
        let expiration = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(1)) } catch { break }
                guard let self, self.generation == runID else { break }
                self.expire()
            }
        }
        defer { expiration.cancel() }
        await refresh()
        while !Task.isCancelled, generation == runID {
            do { try await Task.sleep(for: .seconds(1)) } catch { break }
            guard generation == runID, !Task.isCancelled else { break }
            if Date().timeIntervalSince(lastVerified ?? .distantPast) >= 30 {
                await refresh()
                if errorMessage != nil { try? await Task.sleep(for: .seconds(5)) }
            }
        }
        if generation == runID { await pause() }
    }

    /// Stop background activity, retaining only in-memory photos for this login.
    /// Nothing is shown again until the next foreground catalog verification.
    func pause() async {
        generation = UUID()
        scope = nil
        items = []
        catalog = []
        descriptors = [:]
        for entry in imageLoads.values { entry.task.cancel() }
        imageLoads = [:]
        failedImages = []
        refreshing = false
        isLoading = false
    }

    func clearSession() async {
        await pause()
        snapshotOwner = nil
        snapshots = [:]
        lastVerified = nil
    }

    func refresh() async {
        #if DEBUG
        if PreviewAPI.isEnabled {
            items = PreviewAPI.advertisementRows.map { JSONMapper.makeAdvertisement(from: JSON($0)) }
            errorMessage = nil
            isLoading = false
            return
        }
        #endif
        guard let scope, !refreshing else { return }
        let runID = generation
        refreshing = true
        isLoading = items.isEmpty
        defer {
            if generation == runID { refreshing = false; isLoading = false }
        }
        do {
            // The full list, not a delta, is authoritative for withdrawals.
            let result = try await RemoteDataService.shared.fetchAdvertisements(onlyActive: true)
            try Task.checkCancellation()
            guard generation == runID else { return }
            let now = Date()
            let current = result.activeAdvertisements(at: now)
            let updated = Dictionary(current.compactMap { ad -> (Int, AdvertisementSnapshotKey)? in
                guard let url = ad.imageURL,
                      ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
                let revision = ad.imageRevision ?? "day-\(Int(now.timeIntervalSince1970 / 86400))"
                return (ad.adID, AdvertisementSnapshotKey(
                    userID: scope, adID: ad.adID, url: url,
                    revision: "\(revision)|\(ad.startTime.timeIntervalSince1970)|\(ad.endTime?.timeIntervalSince1970 ?? 0)",
                    expiresAt: ad.endTime ?? .distantFuture
                ))
            }, uniquingKeysWith: { _, new in new })

            for (id, load) in imageLoads where updated[id] != load.key {
                load.task.cancel()
                imageLoads.removeValue(forKey: id)
            }
            // Withdrawn or replaced images disappear before the new list is shown.
            snapshots = snapshots.filter { updated[$0.key.adID] == $0.key }
            failedImages = failedImages.filter { updated[$0] == descriptors[$0] }
            descriptors = updated
            catalog = current.filter { updated[$0.adID] != nil }
            lastVerified = now
            errorMessage = nil
            items = catalog
            for ad in catalog { preload(ad) }
        } catch {
            guard generation == runID, !Task.isCancelled else { return }
            errorMessage = "暂时无法核对广告状态"
            expire()
        }
    }

    private func expire() {
        let now = Date()
        for (id, key) in descriptors where key.expiresAt <= now {
            descriptors.removeValue(forKey: id)
            imageLoads.removeValue(forKey: id)?.task.cancel()
            snapshots.removeValue(forKey: key)
            failedImages.remove(id)
        }
        catalog.removeAll { !$0.isActive(at: now) || descriptors[$0.adID] == nil }
        // A failed network check is not evidence of withdrawal, but an old
        // verification must not keep advertising indefinitely while offline.
        items = now.timeIntervalSince(lastVerified ?? .distantPast) < 60 ? catalog : []
    }

    func image(for ad: Advertisement) -> UIImage? {
        #if DEBUG
        if PreviewAPI.isEnabled {
            return PreviewAPI.image(index: ad.adID, banner: ad.type == "L")
        }
        #endif
        guard items.contains(ad), ad.isActive(), let key = descriptors[ad.adID] else { return nil }
        return snapshots[key]
    }

    func imageFailed(for ad: Advertisement) -> Bool {
        failedImages.contains(ad.adID) && descriptors[ad.adID] != nil
    }

    func retryImage(for ad: Advertisement) {
        failedImages.remove(ad.adID)
        preload(ad)
    }

    private func preload(_ ad: Advertisement) {
        guard let key = descriptors[ad.adID], snapshots[key] == nil,
              imageLoads[ad.adID] == nil, !failedImages.contains(ad.adID) else { return }
        let task = Task { [weak self] in
            do {
                let image = try await Self.downloadImage(from: key.url)
                try Task.checkCancellation()
                guard let self, self.descriptors[key.adID] == key,
                      self.scope == key.userID, key.expiresAt > .now else { return }
                self.snapshots[key] = image
                self.imageLoads.removeValue(forKey: key.adID)
            } catch {
                guard let self, !Task.isCancelled,
                      self.descriptors[key.adID] == key else { return }
                self.failedImages.insert(key.adID)
                self.imageLoads.removeValue(forKey: key.adID)
            }
        }
        imageLoads[ad.adID] = (key, task)
    }

    nonisolated private static func downloadImage(from url: URL) async throws -> UIImage {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              ["image/jpeg", "image/png", "image/webp"].contains(http.mimeType ?? ""),
              data.count <= 8 * 1024 * 1024,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 1600,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else {
            throw APIClientError.invalidResponse
        }
        return UIImage(cgImage: thumbnail)
    }
}

/// A display-only view. Swiping the stack never starts an image request.
struct AdvertisementImage: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let advertisement: Advertisement
    var contentMode: ContentMode = .fit
    @ObservedObject private var store = AdvertisementStore.shared

    var body: some View {
        let image = store.image(for: advertisement)
        ZStack {
            Rectangle().fill(.quaternary)
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else if store.imageFailed(for: advertisement) {
                Label("重新加载图片", systemImage: "arrow.clockwise")
                    .font(.caption).foregroundStyle(.secondary)
                    .beButton { store.retryImage(for: advertisement) }
            } else {
                ProgressView()
            }
        }
        .clipped()
        .animation(.easeInOut(duration: reduceMotion ? 0.1 : 0.25), value: image != nil)
        .accessibilityLabel("广告 \(advertisement.adID)")
    }
}
