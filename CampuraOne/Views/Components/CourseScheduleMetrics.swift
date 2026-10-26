import Foundation

/// Calculations use the resolved occurrences of one selected day, not raw RRULEs.
struct CourseDayInsights {
    let earlyHour: Int?
    let morningFree: Bool
    let afternoonFree: Bool
    let eveningStudy: Bool
    let napMinutes: Int

    init(events: [ICSEventItem], date: Date, calendar: Calendar = .current) {
        func time(_ hour: Int) -> Date {
            calendar.date(bySettingHour: hour, minute: 0, second: 0, of: date)!
        }
        let intervals = events.compactMap { event -> DateInterval? in
            guard let start = event.startDate else { return nil }
            let end = event.endDate ?? start.addingTimeInterval(3600)
            guard end > start else { return nil }
            return DateInterval(start: start, end: end)
        }.sorted { $0.start < $1.start }
        func occupied(_ start: Int, _ end: Int) -> Bool {
            intervals.contains { $0.start < time(end) && $0.end > time(start) }
        }
        if let first = intervals.first {
            let hour = calendar.component(.hour, from: first.start)
            earlyHour = (8..<10).contains(hour) ? 8 : ((10..<12).contains(hour) ? 10 : nil)
        } else {
            earlyHour = nil
        }
        morningFree = !occupied(6, 12)
        afternoonFree = !occupied(13, 18)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
        eveningStudy = intervals.contains { $0.start < dayEnd && $0.end > time(18) }

        // Noon separates morning/afternoon classes; it does not bound the break.
        // Without both endpoints there is no course-to-course lunch gap to show.
        let noon = time(12)
        let morningEnd = intervals.filter { $0.start < noon }.map(\.end).max()
        let afternoonStart = intervals.filter { $0.start >= noon && $0.start < time(18) }.map(\.start).min()
        if let morningEnd, let afternoonStart {
            napMinutes = max(0, Int(afternoonStart.timeIntervalSince(morningEnd) / 60))
        } else {
            napMinutes = 0
        }
    }
}

struct CourseTimelinePlacement: Identifiable {
    let event: ICSEventItem
    let column: Int
    let columnCount: Int
    var id: String { event.id }

    /// Overlapping events share horizontal space instead of drawing over each other.
    static func make(events: [ICSEventItem]) -> [Self] {
        let sorted = events.filter { $0.startDate != nil }.sorted {
            $0.startDate! < $1.startDate!
        }
        var result: [Self] = []
        var group: [(ICSEventItem, Int)] = []
        var laneEnds: [Date] = []
        var groupEnd = Date.distantPast
        func flush() {
            result += group.map { Self(event: $0.0, column: $0.1, columnCount: laneEnds.count) }
            group = []
            laneEnds = []
        }
        for event in sorted {
            let start = event.startDate!
            let end = max(event.endDate ?? start.addingTimeInterval(3600), start.addingTimeInterval(60))
            if start >= groupEnd {
                flush()
                groupEnd = end
            }
            let lane = laneEnds.firstIndex { $0 <= start } ?? laneEnds.count
            if lane == laneEnds.count { laneEnds.append(end) } else { laneEnds[lane] = end }
            group.append((event, lane))
            groupEnd = max(groupEnd, end)
        }
        flush()
        return result
    }
}
