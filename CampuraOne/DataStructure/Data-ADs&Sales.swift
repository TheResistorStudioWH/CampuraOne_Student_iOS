//
//  DataTable.swift
//  CampuraOne
//
//  Created by LShayc1own on 21/05/2026.
//

import SwiftUI


// 数据模型：促销事件
struct SaleEvent: Codable, Identifiable, Hashable {
    let saleID: Int // 促销事件ID
    let productID: Int? // 促销商品ID，可为空
    let saleRule: String? // 促销规则
    let startTime: Date // 开始时间
    let endTime: Date? // 结束时间，可为空

    var id: Int {
        saleID
    }

    /// 促销在搜索结果和列表中显示的标题。
    /// 有促销规则时直接显示规则；规则为空时使用统一标题兜底。
    var displayTitle: String {
        let trimmedRule = saleRule?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let trimmedRule, !trimmedRule.isEmpty else {
            return "促销活动"
        }

        return trimmedRule
    }

    /// 当前时间下促销是否正在进行。
    func isActive(at date: Date = Date()) -> Bool {
        startTime <= date && (endTime == nil || date <= endTime!)
    }

    /// 当前时间下促销是否已经结束。
    func isExpired(at date: Date = Date()) -> Bool {
        guard let endTime else {
            return false
        }

        return endTime < date
    }
}

// 数据模型：广告
struct Advertisement: Codable, Identifiable, Hashable {
    let adID: Int // 广告ID
    let saleID: Int // 促销ID
    let startTime: Date // 开始时间
    let endTime: Date? // 结束时间，可为空
    let type: String // 广告类型（"S"或"L"）
    let img: String // 广告图片链接
    
    var id: Int { adID }
    
    /// 广告图片 URL。
    /// 后台测试数据为空或格式不对时会返回 nil，View 层可以再使用 debug 图片兜底。
    var imageURL: URL? {
        URL(string: img)
    }
    
    /// 给 RemoteImageView 使用的固定缓存坑位。
    /// 同一个广告 ID 下，如果 img URL 改了，磁盘缓存会自动清掉旧图并换成新图。
    var imageCacheKey: String {
        "advertisement-\(adID)"
    }
    
    /// 当前时间下广告是否有效。
    /// 规则：开始时间 <= 当前时间，且结束时间为空或还没过期。
    func isActive(at date: Date = Date()) -> Bool {
        startTime <= date && (endTime == nil || date <= endTime!)
    }
    
    /// 当前时间下广告是否已经过期。
    func isExpired(at date: Date = Date()) -> Bool {
        guard let endTime else {
            return false
        }
        return endTime < date
    }
    
    /// 根据广告类型判断是否是小广告位。
    var isSmallAd: Bool {
        type.uppercased() == "S"
    }
    
    /// 根据广告类型判断是否是大广告位。
    var isLargeAd: Bool {
        type.uppercased() == "L"
    }
}

extension Array where Element == Advertisement {
    /// 筛选出当前可展示的广告，并按开始时间从新到旧排序。
    func activeAdvertisements(at date: Date = Date()) -> [Advertisement] {
        filter { $0.isActive(at: date) }
            .sorted { $0.startTime > $1.startTime }
    }
    
    /// 筛选出当前可展示的小广告。
    func activeSmallAdvertisements(at date: Date = Date()) -> [Advertisement] {
        activeAdvertisements(at: date)
            .filter { $0.isSmallAd }
    }
    
    /// 筛选出当前可展示的大广告。
    func activeLargeAdvertisements(at date: Date = Date()) -> [Advertisement] {
        activeAdvertisements(at: date)
            .filter { $0.isLargeAd }
    }
    
}
