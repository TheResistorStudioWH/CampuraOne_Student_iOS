//
//  RemoteImageCache.swift
//  CampuraOne
//
//  Created by LShayc1own on 25/05/2026.
//

import UIKit

final class RemoteImageCache {
    
    static let shared = RemoteImageCache()
    
    private struct DiskRecord: Codable {
        let urlString: String
        let fileName: String
    }
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let recordsDirectory: URL
    private let imagesDirectory: URL
    
    private init() {
        memoryCache.countLimit = 200
        
        let baseDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        cacheDirectory = baseDirectory.appendingPathComponent("CampuraOneRemoteImageCache", isDirectory: true)
        recordsDirectory = cacheDirectory.appendingPathComponent("Records", isDirectory: true)
        imagesDirectory = cacheDirectory.appendingPathComponent("Images", isDirectory: true)
        
        createCacheDirectoriesIfNeeded()
    }
    
    // MARK: - Public: CacheKey based cache
    
    func image(for cacheKey: String, url: URL) -> UIImage? {
        let memoryKey = memoryKey(for: cacheKey)
        
        if let image = memoryCache.object(forKey: memoryKey) {
            return image
        }
        
        guard let record = diskRecord(for: cacheKey),
              record.urlString == url.absoluteString else {
            removeDiskImageAndRecord(for: cacheKey)
            return nil
        }
        
        let imageFileURL = imagesDirectory.appendingPathComponent(record.fileName)
        guard let data = try? Data(contentsOf: imageFileURL),
              let image = UIImage(data: data) else {
            removeDiskImageAndRecord(for: cacheKey)
            return nil
        }
        
        memoryCache.setObject(image, forKey: memoryKey)
        return image
    }
    
    func setImage(_ image: UIImage, for cacheKey: String, url: URL) {
        let memoryKey = memoryKey(for: cacheKey)
        memoryCache.setObject(image, forKey: memoryKey)
        
        removeDiskImageAndRecord(for: cacheKey)
        
        let fileName = safeFileName(for: cacheKey) + ".jpg"
        let imageFileURL = imagesDirectory.appendingPathComponent(fileName)
        
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            return
        }
        
        do {
            try data.write(to: imageFileURL, options: .atomic)
            let record = DiskRecord(
                urlString: url.absoluteString,
                fileName: fileName
            )
            try saveDiskRecord(record, for: cacheKey)
        } catch {
            try? fileManager.removeItem(at: imageFileURL)
        }
    }
    
    func removeImage(for cacheKey: String) {
        memoryCache.removeObject(forKey: memoryKey(for: cacheKey))
        removeDiskImageAndRecord(for: cacheKey)
    }
    
    func removeAllImages() {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        createCacheDirectoriesIfNeeded()
    }
    
    // MARK: - Public: URL based compatibility cache
    
    func image(for url: URL) -> UIImage? {
        image(for: url.absoluteString, url: url)
    }
    
    func setImage(_ image: UIImage, for url: URL) {
        setImage(image, for: url.absoluteString, url: url)
    }
    
    func removeImage(for url: URL) {
        removeImage(for: url.absoluteString)
    }
    
    // MARK: - Private
    
    private func createCacheDirectoriesIfNeeded() {
        try? fileManager.createDirectory(
            at: recordsDirectory,
            withIntermediateDirectories: true
        )
        try? fileManager.createDirectory(
            at: imagesDirectory,
            withIntermediateDirectories: true
        )
    }
    
    private func memoryKey(for cacheKey: String) -> NSString {
        cacheKey as NSString
    }
    
    private func recordURL(for cacheKey: String) -> URL {
        recordsDirectory.appendingPathComponent(safeFileName(for: cacheKey) + ".json")
    }
    
    private func diskRecord(for cacheKey: String) -> DiskRecord? {
        let url = recordURL(for: cacheKey)
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(DiskRecord.self, from: data)
    }
    
    private func saveDiskRecord(_ record: DiskRecord, for cacheKey: String) throws {
        let data = try JSONEncoder().encode(record)
        try data.write(to: recordURL(for: cacheKey), options: .atomic)
    }
    
    private func removeDiskImageAndRecord(for cacheKey: String) {
        if let record = diskRecord(for: cacheKey) {
            let imageFileURL = imagesDirectory.appendingPathComponent(record.fileName)
            try? fileManager.removeItem(at: imageFileURL)
        }
        
        try? fileManager.removeItem(at: recordURL(for: cacheKey))
    }
    
    private func safeFileName(for cacheKey: String) -> String {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = cacheKey.unicodeScalars.map { scalar -> Character in
            allowedCharacters.contains(scalar) ? Character(scalar) : "_"
        }
        let result = String(scalars)
        return result.isEmpty ? UUID().uuidString : result
    }
}

// 兼容旧代码：之前头像专用的 AvatarImageCache 现在指向通用图片缓存。
typealias AvatarImageCache = RemoteImageCache
