import Foundation

/// 把 ICS 中的单次、每日和每周重复课程统一展开为指定日期的实际课程。
/// 所有课表 UI 必须通过这里计算，保证对 RRULE 的理解一致。
enum CourseScheduleResolver {
    static func events(
        on selectedDate: Date,
        from sourceEvents: [ICSEventItem],
        calendar: Calendar = .current
    ) -> [ICSEventItem] {
        sourceEvents
            .compactMap {
                occurrence(of: $0, on: selectedDate, calendar: calendar)
            }
            .sorted {
                ($0.startDate ?? .distantFuture)
                < ($1.startDate ?? .distantFuture)
            }
    }

    static func nextEvent(
        after now: Date,
        from sourceEvents: [ICSEventItem],
        searchDays: Int = 180,
        calendar: Calendar = .current
    ) -> ICSEventItem? {
        for offset in 0...searchDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else {
                continue
            }

            if let event = events(on: day, from: sourceEvents, calendar: calendar)
                .first(where: { ($0.startDate ?? .distantPast) > now }) {
                return event
            }
        }
        return nil
    }

    private static func occurrence(
        of event: ICSEventItem,
        on selectedDate: Date,
        calendar: Calendar
    ) -> ICSEventItem? {
        guard let originalStart = event.startDate else { return nil }
        let originalEnd = event.endDate ?? originalStart.addingTimeInterval(60 * 60)
        let duration = max(originalEnd.timeIntervalSince(originalStart), 0)

        if calendar.isDate(originalStart, inSameDayAs: selectedDate) {
            return event
        }

        guard let rule = event.recurrenceRule,
              matches(rule: rule, originalStart: originalStart, selectedDate: selectedDate, calendar: calendar),
              let displayedStart = date(selectedDate, usingTimeFrom: originalStart, calendar: calendar) else {
            return nil
        }

        return ICSEventItem(
            id: "\(event.id)-\(Int(displayedStart.timeIntervalSince1970))",
            title: event.title,
            startDate: displayedStart,
            endDate: displayedStart.addingTimeInterval(duration),
            location: event.location,
            detail: event.detail,
            recurrenceRule: nil
        )
    }

    private static func matches(
        rule: String,
        originalStart: Date,
        selectedDate: Date,
        calendar: Calendar
    ) -> Bool {
        let values: [String: String] = Dictionary(
            uniqueKeysWithValues: rule.split(separator: ";").compactMap { component -> (String, String)? in
                let pair = component.split(separator: "=", maxSplits: 1)
                guard pair.count == 2 else { return nil }
                return (String(pair[0]).uppercased(), String(pair[1]).uppercased())
            }
        )
        let selectedDay = calendar.startOfDay(for: selectedDate)
        let originalDay = calendar.startOfDay(for: originalStart)
        guard selectedDay >= originalDay else { return false }

        if let untilText = values["UNTIL"],
           let untilDate = parseUntilDate(untilText),
           selectedDay > calendar.startOfDay(for: untilDate) {
            return false
        }

        let interval = max(Int(values["INTERVAL"] ?? "1") ?? 1, 1)
        switch values["FREQ"] {
        case "DAILY":
            let days = calendar.dateComponents([.day], from: originalDay, to: selectedDay).day ?? 0
            return days % interval == 0
        case "WEEKLY":
            let allowedWeekdays = values["BYDAY"]?
                .split(separator: ",")
                .compactMap { weekdayNumber(for: String($0)) }
                ?? [calendar.component(.weekday, from: originalStart)]
            guard allowedWeekdays.contains(calendar.component(.weekday, from: selectedDate)) else {
                return false
            }
            let weeks = calendar.dateComponents([.weekOfYear], from: originalDay, to: selectedDay).weekOfYear ?? 0
            return weeks % interval == 0
        default:
            return false
        }
    }

    private static func date(_ day: Date, usingTimeFrom source: Date, calendar: Calendar) -> Date? {
        let time = calendar.dateComponents([.hour, .minute, .second], from: source)
        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: day
        )
    }

    private static func weekdayNumber(for token: String) -> Int? {
        switch String(token.suffix(2)) {
        case "SU": return 1
        case "MO": return 2
        case "TU": return 3
        case "WE": return 4
        case "TH": return 5
        case "FR": return 6
        case "SA": return 7
        default: return nil
        }
    }

    private static func parseUntilDate(_ text: String) -> Date? {
        for format in ["yyyyMMdd'T'HHmmss'Z'", "yyyyMMdd'T'HHmmss", "yyyyMMdd"] {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = text.hasSuffix("Z") ? TimeZone(secondsFromGMT: 0) : .current
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }
}

