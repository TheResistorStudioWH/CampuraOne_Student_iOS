import Foundation
import CryptoKit

/// Only immutable values cross into the image-cache actor.
nonisolated struct AdvertisementAsset: Codable, Hashable, Sendable {
    let scope: String
    let adID: Int
    let url: URL
    let revision: String
    let expiresAt: Date

    var key: String {
        SHA256.hash(data: Data("\(scope)|\(adID)|\(url.absoluteString)|\(revision)".utf8))
            .map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated enum AdvertisementAssetError: Error { case withdrawn, invalidResponse, tooLarge }

/// Separate from avatar/product caches. Reconciliation is authoritative, not a
/// TTL-only cache: removed/revised ads cancel downloads and delete their files.
actor AdvertisementAssets {
    static let shared = AdvertisementAssets()
    private let directory: URL
    private var allowed: [String: AdvertisementAsset] = [:]
    private var pending: [String: (UUID, Task<Data, Error>)] = [:]
    private let download: @Sendable (URL) async throws -> Data
    private let budget = 60 * 1024 * 1024

    init(directory: URL? = nil,
         download: @escaping @Sendable (URL) async throws -> Data = { try await AdvertisementAssets.fetch($0) }) {
        self.directory = directory ?? FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CampuraAdvertisementAssets-v2", isDirectory: true)
        self.download = download
    }

    func reconcile(_ assets: [AdvertisementAsset], now: Date = .now) throws {
        allowed = Dictionary(assets.filter { $0.expiresAt > now }.map { ($0.key, $0) },
                             uniquingKeysWith: { _, new in new })
        for (key, entry) in pending where allowed[key] == nil {
            entry.1.cancel()
            pending.removeValue(forKey: key)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        where allowed[file.lastPathComponent] == nil {
            try FileManager.default.removeItem(at: file)
        }
    }

    func data(for asset: AdvertisementAsset) async throws -> Data {
        let key = asset.key
        guard allowed[key] == asset, asset.expiresAt > .now else { throw AdvertisementAssetError.withdrawn }
        let file = directory.appendingPathComponent(key)
        if let data = try? Data(contentsOf: file), data.count <= 8 * 1024 * 1024 {
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)
            return data
        }
        let entry: (UUID, Task<Data, Error>)
        if let existing = pending[key] { entry = existing }
        else {
            let fetch = download
            entry = (UUID(), Task { try await fetch(asset.url) })
            pending[key] = entry
        }
        defer { if pending[key]?.0 == entry.0 { pending.removeValue(forKey: key) } }
        let data = try await entry.1.value
        // An old request may finish after withdrawal, logout, or image revision.
        guard !entry.1.isCancelled, allowed[key] == asset, asset.expiresAt > .now else {
            throw AdvertisementAssetError.withdrawn
        }
        guard data.count <= 8 * 1024 * 1024 else { throw AdvertisementAssetError.tooLarge }
        try data.write(to: file, options: .atomic)
        trimDisk()
        return data
    }

    func discard(_ asset: AdvertisementAsset) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(asset.key))
    }

    func suspend() {
        for entry in pending.values { entry.1.cancel() }
        pending.removeAll()
        allowed.removeAll()
    }

    private func trimDisk() {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys))) ?? []
        let entries = files.compactMap { url -> (URL, Int, Date)? in
            guard let values = try? url.resourceValues(forKeys: keys) else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }.sorted { $0.2 < $1.2 }
        var total = entries.reduce(0) { $0 + $1.1 }
        for entry in entries where total > budget {
            if (try? FileManager.default.removeItem(at: entry.0)) != nil { total -= entry.1 }
        }
    }

    nonisolated private static func fetch(_ url: URL) async throws -> Data {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.timeoutIntervalForRequest = 15
        let session = URLSession(configuration: config)
        defer { session.invalidateAndCancel() }
        let request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200,
              ["image/jpeg", "image/png", "image/webp"].contains(http.mimeType ?? "") else {
            throw AdvertisementAssetError.invalidResponse
        }
        guard response.expectedContentLength <= 8 * 1024 * 1024 else { throw AdvertisementAssetError.tooLarge }
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count > 8 * 1024 * 1024 { throw AdvertisementAssetError.tooLarge }
        }
        return data
    }
}
