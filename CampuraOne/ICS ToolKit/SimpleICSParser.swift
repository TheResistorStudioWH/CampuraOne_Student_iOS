//
//  SimpleICSParser.swift
//  CampuraOne
//
//  Created by Lin Shay on 04/06/2026.
//

///把服务器返回的 ICS 字符串解析成 [ICSEventItem]。

import Foundation

/// 轻量级 ICS 解析器。
///
/// 第一版只解析 Campura One 当前需要的 VEVENT 字段：
/// UID / SUMMARY / DESCRIPTION / LOCATION / DTSTART / DTEND / RRULE。
/// 目标不是完整覆盖 RFC 5545，而是先稳定支撑课程表、校历和 Demo 页面。
enum SimpleICSParser {
    
    static func parseEvents(from icsText: String) -> [ICSEventItem] {
        let unfoldedLines = unfoldLines(from: icsText)
        var events: [ICSEventItem] = []
        var currentEventLines: [String] = []
        var isInsideEvent = false
        
        for line in unfoldedLines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmedLine == "BEGIN:VEVENT" {
                isInsideEvent = true
                currentEventLines = []
                continue
            }
            
            if trimmedLine == "END:VEVENT" {
                if let event = parseEvent(from: currentEventLines) {
                    events.append(event)
                }
                isInsideEvent = false
                currentEventLines = []
                continue
            }
            
            if isInsideEvent {
                currentEventLines.append(trimmedLine)
            }
        }
        
        return events
    }
    
    private static func parseEvent(from lines: [String]) -> ICSEventItem? {
        var uid: String?
        var summary: String?
        var description: String?
        var location: String?
        var startDate: Date?
        var endDate: Date?
        var recurrenceRule: String?
        
        for line in lines {
            let property = parseProperty(from: line)
            
            switch property.name {
                case "UID":
                    uid = unescapeICSValue(property.value)
                case "SUMMARY":
                    summary = unescapeICSValue(property.value)
                case "DESCRIPTION":
                    description = unescapeICSValue(property.value)
                case "LOCATION":
                    location = unescapeICSValue(property.value)
                case "DTSTART":
                    startDate = parseDate(property.value, parameters: property.parameters)
                case "DTEND":
                    endDate = parseDate(property.value, parameters: property.parameters)
                case "RRULE":
                    recurrenceRule = property.value
                default:
                    break
            }
        }
        
        guard let summary, !summary.isEmpty else {
            return nil
        }
        
        return ICSEventItem(
            id: uid ?? UUID().uuidString,
            title: summary,
            startDate: startDate,
            endDate: endDate,
            location: location,
            detail: description,
            recurrenceRule: recurrenceRule
        )
    }
    
    private static func unfoldLines(from icsText: String) -> [String] {
        let normalizedText = icsText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        
        let rawLines = normalizedText.components(separatedBy: "\n")
        var lines: [String] = []
        
        for rawLine in rawLines {
            if rawLine.hasPrefix(" ") || rawLine.hasPrefix("\t") {
                guard let lastLine = lines.popLast() else {
                    lines.append(rawLine.trimmingCharacters(in: .whitespacesAndNewlines))
                    continue
                }
                
                let continuation = rawLine.dropFirst()
                lines.append(lastLine + continuation)
            } else {
                lines.append(rawLine)
            }
        }
        
        return lines
    }
    
    private static func parseProperty(from line: String) -> ICSProperty {
        let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let leftPart = parts.first.map(String.init) ?? ""
        let value = parts.count > 1 ? String(parts[1]) : ""
        
        let leftComponents = leftPart.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
        let name = leftComponents.first?.uppercased() ?? ""
        var parameters: [String: String] = [:]
        
        for parameterText in leftComponents.dropFirst() {
            let parameterParts = parameterText.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parameterParts.count == 2 else { continue }
            
            let key = String(parameterParts[0]).uppercased()
            let value = String(parameterParts[1])
            parameters[key] = value
        }
        
        return ICSProperty(
            name: name,
            parameters: parameters,
            value: value
        )
    }
    
    private static func parseDate(_ text: String, parameters: [String: String]) -> Date? {
        if parameters["VALUE"]?.uppercased() == "DATE" {
            return dateOnlyFormatter.date(from: text)
        }
        
        if text.hasSuffix("Z") {
            return utcDateTimeFormatter.date(from: text)
        }
        
        return floatingDateTimeFormatter.date(from: text)
    }
    
    private static func unescapeICSValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
    
    private static let utcDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter
    }()
    
    private static let floatingDateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        return formatter
    }()
    
    private static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}

private struct ICSProperty {
    let name: String
    let parameters: [String: String]
    let value: String
}
