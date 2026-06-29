//
//  SimpleICSGenerator.swift
//  CampuraOne
//
//  Created by Lin Shay on 04/06/2026.
//

///把 [ICSEventItem] 重新生成 ICS 字符串。


import Foundation

/// 轻量级 ICS 生成器。
///
/// 用于把 `[ICSEventItem]` 重新生成 `.ics` 文本，后续可用于导出文件或分享给用户导入系统日历。
enum SimpleICSGenerator {
    
    static func generateCalendar(
        events: [ICSEventItem],
        calendarName: String = "Campura One Calendar"
    ) -> String {
        var lines: [String] = []
        
        lines.append("BEGIN:VCALENDAR")
        lines.append("VERSION:2.0")
        lines.append("PRODID:-//Campura One//ICS ToolKit//CN")
        lines.append("CALSCALE:GREGORIAN")
        lines.append("METHOD:PUBLISH")
        lines.append("X-WR-CALNAME:\(escapeICSValue(calendarName))")
        
        for event in events {
            lines.append(contentsOf: generateEventLines(from: event))
        }
        
        lines.append("END:VCALENDAR")
        
        return lines
            .map(foldLineIfNeeded)
            .joined(separator: "\r\n") + "\r\n"
    }
    
    static func generateCalendar(
        event: ICSEventItem,
        calendarName: String = "Campura One Calendar"
    ) -> String {
        generateCalendar(events: [event], calendarName: calendarName)
    }
    
    private static func generateEventLines(from event: ICSEventItem) -> [String] {
        var lines: [String] = []
        
        lines.append("BEGIN:VEVENT")
        lines.append("UID:\(escapeICSValue(event.id))")
        lines.append("DTSTAMP:\(utcDateTimeFormatter.string(from: Date()))")
        
        if let startDate = event.startDate {
            lines.append("DTSTART:\(utcDateTimeFormatter.string(from: startDate))")
        }
        
        if let endDate = event.endDate {
            lines.append("DTEND:\(utcDateTimeFormatter.string(from: endDate))")
        }
        
        lines.append("SUMMARY:\(escapeICSValue(event.title))")
        
        if let location = event.location, !location.isEmpty {
            lines.append("LOCATION:\(escapeICSValue(location))")
        }
        
        if let detail = event.detail, !detail.isEmpty {
            lines.append("DESCRIPTION:\(escapeICSValue(detail))")
        }
        
        if let recurrenceRule = event.recurrenceRule, !recurrenceRule.isEmpty {
            lines.append("RRULE:\(recurrenceRule)")
        }
        
        lines.append("END:VEVENT")
        
        return lines
    }
    
    private static func escapeICSValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: ";", with: "\\;")
    }
    
    private static func foldLineIfNeeded(_ line: String) -> String {
        let maxLength = 75
        guard line.count > maxLength else {
            return line
        }
        
        var result = ""
        var currentLine = ""
        
        for character in line {
            currentLine.append(character)
            
            if currentLine.count >= maxLength {
                if result.isEmpty {
                    result += currentLine
                } else {
                    result += "\r\n " + currentLine
                }
                currentLine = ""
            }
        }
        
        if !currentLine.isEmpty {
            if result.isEmpty {
                result += currentLine
            } else {
                result += "\r\n " + currentLine
            }
        }
        
        return result
    }
    
    private static let utcDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter
    }()
}
