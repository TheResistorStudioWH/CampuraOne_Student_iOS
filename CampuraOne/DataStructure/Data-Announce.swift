//
//  Data-Announce.swift
//  CampuraOne
//
//  Created by LShayc1own on 26/05/2026.
//

import Foundation

// MARK: - 通知类型

/// 通知类型。
/// 数据库 announcements.type 使用 tinyint：
/// 0 = 日常短通知，rawText
/// 1 = 紧急短通知，rawText
/// 2 = 重要通知，Markdown
enum AnnouncementType: Int, Codable, CaseIterable, Identifiable {
    case dailyShort = 0
    case emergencyShort = 1
    case importantMarkdown = 2
    
    var id: Int { rawValue }
    
    var title: String {
        switch self {
        case .dailyShort:
            return "日常通知"
        case .emergencyShort:
            return "紧急通知"
        case .importantMarkdown:
            return "重要通知"
        }
    }
    
    var systemImage: String {
        switch self {
        case .dailyShort:
            return "bell"
        case .emergencyShort:
            return "exclamationmark.triangle"
        case .importantMarkdown:
            return "exclamationmark.circle"
        }
    }
    
    /// 是否需要按 Markdown 渲染。
    var isMarkdown: Bool {
        self == .importantMarkdown
    }
    
    /// 是否是 Dashboard 短公告栏可直接展示的短通知。
    var isShortAnnouncement: Bool {
        self == .dailyShort || self == .emergencyShort
    }
}

// MARK: - 通知分发目标

/// 通知分发目标。
/// 对应数据库 announcement_targets.targetJSON。
/// 约定 JSON 格式：
/// {
///   "allSchool": false,
///   "areaIDs": [1],
///   "departmentIDs": [2, 3],
///   "classIDs": [101],
///   "studentIDs": [20001]
/// }
struct AnnouncementTarget: Codable, Equatable {
    let allSchool: Bool
    let areaIDs: [Int]
    let departmentIDs: [Int]
    let classIDs: [Int]
    let studentIDs: [Int]
    
    static let empty = AnnouncementTarget(
        allSchool: false,
        areaIDs: [],
        departmentIDs: [],
        classIDs: [],
        studentIDs: []
    )
}

// MARK: - 通知总结请求

/// 发给 AI 总结接口时使用的请求体。
struct AnnouncementSummaryRequest: Codable {
    let announcements: [AnnouncementItem]
    let summaryContent: String
    let dateArray: String
}

struct AnnouncementSummary {
    let summary: String
    let sourceIDs: [Int]
    let isAI: Bool
}

// MARK: - 通知条目

/// 学校通知条目。
/// 这个模型直接对应 `/api/announcements.php` 返回的单条通知。
struct AnnouncementItem: Codable, Identifiable, Equatable {
    let announceID: Int
    let schoolID: Int
    let content: String
    let type: AnnouncementType
    let target: AnnouncementTarget?
    let startTime: Date?
    let endTime: Date?
    let createdAt: Date?
    let updatedAt: Date?
    
    var id: Int { announceID }
    
    /// UI 显示用标题。
    var typeTitle: String {
        type.title
    }
    
    /// UI 显示用图标。
    var systemImage: String {
        type.systemImage
    }
    
    /// 是否需要按 Markdown 渲染。
    var isMarkdown: Bool {
        type.isMarkdown
    }

    /// Matches the API's inclusive start/end bounds; nil means unbounded.
    func isActive(at date: Date) -> Bool {
        (startTime.map { $0 <= date } ?? true)
            && (endTime.map { date <= $0 } ?? true)
    }
}

extension Array where Element == AnnouncementItem {
    func active(at date: Date) -> [AnnouncementItem] {
        filter { $0.isActive(at: date) }
    }

    /// Shared by the red badge, the floating toolbar and the full Markdown sheet.
    func activeMarkdown(at date: Date) -> [AnnouncementItem] {
        filter { $0.type.isMarkdown && $0.isActive(at: date) }
            .sorted {
                if $0.createdAt != $1.createdAt {
                    return ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast)
                }
                return $0.announceID > $1.announceID
            }
    }
}
