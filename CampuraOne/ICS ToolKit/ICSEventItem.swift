//
//  ICSEventItem.swift
//  CampuraOne
//
//  Created by Lin Shay on 04/06/2026.
//

///解析后的事件模型，比如标题、开始时间、结束时间、地点、描述、重复规则。

import Foundation

/// 解析后的 ICS 事件模型。
///
/// 第一版只覆盖 Campura One 当前需要的字段：
/// - UID
/// - SUMMARY
/// - DESCRIPTION
/// - LOCATION
/// - DTSTART
/// - DTEND
/// - RRULE
struct ICSEventItem: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date?
    let endDate: Date?
    let location: String?
    let detail: String?
    let recurrenceRule: String?
    
    init(
        id: String = UUID().uuidString,
        title: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        location: String? = nil,
        detail: String? = nil,
        recurrenceRule: String? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.detail = detail
        self.recurrenceRule = recurrenceRule
    }
    
    /// 是否是全天事件。
    ///
    /// 目前用于区分校历中的日期事件和课程表中的具体时间事件。
    var isAllDay: Bool {
        guard let startDate, let endDate else {
            return false
        }
        
        let calendar = Calendar.current
        return calendar.isDate(startDate, inSameDayAs: calendar.startOfDay(for: startDate))
            && calendar.isDate(endDate, inSameDayAs: calendar.startOfDay(for: endDate))
    }
    
    /// 列表显示用的地点文本。
    var locationText: String {
        guard let location, !location.isEmpty else {
            return "暂无地点"
        }
        return location
    }
    
    /// 列表显示用的说明文本。
    var detailText: String {
        guard let detail, !detail.isEmpty else {
            return "暂无说明"
        }
        return detail
    }
}
