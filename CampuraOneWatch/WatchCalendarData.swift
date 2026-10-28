import Foundation

private enum WatchDisplayText {
    static func clean(_ text: String) -> String {
        text.replacingOccurrences(
            of: #"(?:\[|【)\s*(?:演示|demo)\s*(?:\]|】)\s*"#,
            with: "", options: [.regularExpression, .caseInsensitive]
        ).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func notes(_ text: String?) -> String? {
        guard let text else { return nil }
        if text.contains("虚构示例课表") && text.contains("项目演示") { return nil }
        let result = clean(text)
        return result.isEmpty ? nil : result
    }
}

struct WatchCalendarEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    let notes: String?
    var recurrenceRule: String?

    func occurs(on day: Date, calendar: Calendar = .current) -> Bool {
        let startOfDay = calendar.startOfDay(for: day)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        if start == end { return start >= startOfDay && start < nextDay }
        return start < nextDay && end > startOfDay
    }

    var course: ICSEventItem {
        ICSEventItem(id: id, title: title, startDate: start, endDate: end,
                     location: location, detail: notes, recurrenceRule: recurrenceRule)
    }

    init?(course: ICSEventItem) {
        guard let start = course.startDate else { return nil }
        self.id = course.id
        self.title = WatchDisplayText.clean(course.title)
        self.start = start
        self.end = course.endDate ?? start.addingTimeInterval(3600)
        self.isAllDay = false
        self.location = course.location.map(WatchDisplayText.clean)
        self.notes = WatchDisplayText.notes(course.detail)
        self.recurrenceRule = course.recurrenceRule
    }

    init(calendarEvent event: RemoteSchoolCalendarEvent) {
        id = event.id
        title = WatchDisplayText.clean(event.title)
        start = event.startTime
        end = event.endTime ?? Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: event.startTime))!
        isAllDay = event.isAllDay
        location = nil
        notes = WatchDisplayText.notes(event.content)
    }
}

enum WatchCalendarData {
    static func validateICS(_ content: String) throws {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty || (text.hasPrefix("BEGIN:VCALENDAR") && text.hasSuffix("END:VCALENDAR")) else {
            throw WatchServiceError.invalidData
        }
    }

    static func parse(_ document: WatchCalendarDocument) -> [WatchCalendarEntry] {
        switch document.kind {
        case .courses:
            SimpleICSParser.parseEvents(from: document.content).compactMap(WatchCalendarEntry.init(course:)).sorted { $0.start < $1.start }
        case .school:
            SchoolCalendarICSParser.parse(document.content).map(WatchCalendarEntry.init(calendarEvent:))
        }
    }

    static func events(on date: Date, kind: WatchCalendarKind, entries: [WatchCalendarEntry], calendar: Calendar = .current) -> [WatchCalendarEntry] {
        if kind == .courses {
            return CourseScheduleResolver.events(on: date, from: entries.map(\.course), calendar: calendar)
                .compactMap(WatchCalendarEntry.init(course:))
        }
        return entries.filter { $0.occurs(on: date, calendar: calendar) }.sorted {
            if $0.isAllDay != $1.isAllDay { return $0.isAllDay }
            return $0.start < $1.start
        }
    }

    static func week(containing date: Date, calendar: Calendar = .current) -> [Date] {
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        let start = mondayCalendar.dateInterval(of: .weekOfYear, for: date)!.start
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func monthDays(containing date: Date, calendar: Calendar = .current) -> [Date?] {
        let start = calendar.dateInterval(of: .month, for: date)!.start
        let leading = (calendar.component(.weekday, from: start) + 5) % 7
        let count = calendar.range(of: .day, in: .month, for: date)!.count
        let total = ((leading + count + 6) / 7) * 7
        return (0..<total).map { index in
            guard index >= leading, index < leading + count else { return nil }
            return calendar.date(byAdding: .day, value: index - leading, to: start)
        }
    }

    static func agenda(kind: WatchCalendarKind, entries: [WatchCalendarEntry], around date: Date, calendar: Calendar = .current) -> [WatchCalendarEntry] {
        guard kind == .courses, entries.contains(where: { $0.recurrenceRule != nil }) else { return entries }
        // Expand older inline RRULE calendars around the visible date; current server calendars are already expanded.
        let start = calendar.date(byAdding: .day, value: -42, to: date)!
        return (0..<408).flatMap { offset -> [WatchCalendarEntry] in
            let day = calendar.date(byAdding: .day, value: offset, to: start)!
            return events(on: day, kind: kind, entries: entries, calendar: calendar)
        }
    }
}
