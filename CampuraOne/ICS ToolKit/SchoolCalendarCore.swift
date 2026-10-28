import Foundation

struct RemoteSchoolCalendarEvent: Identifiable, Codable {
    let uid: String
    let title: String
    let content: String?
    let startTime: Date
    let endTime: Date?
    let isAllDay: Bool
    
    var id: String { uid }
    
    init(
        uid: String,
        title: String,
        content: String? = nil,
        startTime: Date,
        endTime: Date? = nil,
        isAllDay: Bool = true
    ) {
        self.uid = uid
        self.title = title
        self.content = content
        self.startTime = startTime
        self.endTime = endTime
        self.isAllDay = isAllDay
    }
    
    func occurs(on date: Date) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let defaultEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: startTime)) ?? startTime
        let eventEnd = endTime ?? defaultEnd
        
        return startTime < dayEnd && eventEnd > dayStart
    }
}


enum SchoolCalendarICSParser {
    static func parse(_ content: String) -> [RemoteSchoolCalendarEvent] {
        let lines = unfoldedLines(content)
        var events: [RemoteSchoolCalendarEvent] = []
        var currentEvent: [String: String]?
        
        for line in lines {
            if line == "BEGIN:VEVENT" {
                currentEvent = [:]
                continue
            }
            
            if line == "END:VEVENT" {
                if let currentEvent,
                   let event = makeEvent(from: currentEvent) {
                    events.append(event)
                }
                currentEvent = nil
                continue
            }
            
            guard currentEvent != nil else {
                continue
            }
            
            let parsedLine = parseLine(line)
            currentEvent?[parsedLine.key] = parsedLine.value
        }
        
        return events.sortedByStartTime
    }
    
    private static func unfoldedLines(_ content: String) -> [String] {
        let rawLines = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        
        var lines: [String] = []
        
        for rawLine in rawLines {
            guard !rawLine.isEmpty else { continue }
            
            if rawLine.hasPrefix(" ") || rawLine.hasPrefix("\t") {
                if let last = lines.indices.last {
                    lines[last] += String(rawLine.dropFirst())
                }
            } else {
                lines.append(rawLine)
            }
        }
        
        return lines
    }
    
    private static func parseLine(_ line: String) -> (key: String, value: String) {
        guard let colonIndex = line.firstIndex(of: ":") else {
            return (line, "")
        }
        
        let keyPart = String(line[..<colonIndex])
        let value = String(line[line.index(after: colonIndex)...])
        let key = keyPart.components(separatedBy: ";").first ?? keyPart
        
        return (key, unescaped(value))
    }
    
    private static func makeEvent(from dictionary: [String: String]) -> RemoteSchoolCalendarEvent? {
        guard let startRaw = dictionary["DTSTART"],
              let startTime = parseICSDate(startRaw) else {
            return nil
        }
        
        let endTime = dictionary["DTEND"].flatMap { parseICSDate($0) }
        let uid = dictionary["UID"] ?? UUID().uuidString
        let title = dictionary["SUMMARY"] ?? "校历事项"
        let content = dictionary["DESCRIPTION"]
        
        return RemoteSchoolCalendarEvent(
            uid: uid,
            title: title,
            content: content,
            startTime: startTime,
            endTime: endTime,
            isAllDay: startRaw.count == 8
        )
    }
    
    private static func parseICSDate(_ rawValue: String) -> Date? {
        if rawValue.count == 8 {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = Calendar.current.timeZone
            formatter.dateFormat = "yyyyMMdd"
            return formatter.date(from: rawValue)
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = rawValue.hasSuffix("Z") ? "yyyyMMdd'T'HHmmss'Z'" : "yyyyMMdd'T'HHmmss"
        return formatter.date(from: rawValue)
    }
    
    private static func unescaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}


extension Array where Element == RemoteSchoolCalendarEvent {
    var sortedByStartTime: [RemoteSchoolCalendarEvent] {
        sorted { $0.startTime < $1.startTime }
    }
    
    func events(on date: Date) -> [RemoteSchoolCalendarEvent] {
        filter { event in
            event.occurs(on: date)
        }
        .sortedByStartTime
    }
}

