import Foundation

@main struct CourseScheduleChecks {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26))!
        func time(_ hour: Int, _ minute: Int = 0) -> Date {
            calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)!
        }
        func event(_ id: String, _ start: Date, _ end: Date) -> ICSEventItem {
            ICSEventItem(id: id, title: id, startDate: start, endDate: end)
        }
        func insights(_ events: [ICSEventItem]) -> CourseDayInsights {
            CourseDayInsights(events: events, date: date, calendar: calendar)
        }

        let empty = insights([])
        precondition(empty.earlyHour == nil && empty.morningFree && empty.afternoonFree)
        precondition(!empty.eveningStudy && empty.napMinutes == 0)
        let early = insights([event("early", time(8, 20), time(10))])
        precondition(early.earlyHour == 8 && !early.morningFree && early.afternoonFree)
        precondition(insights([event("ten", time(10), time(12))]).earlyHour == 10)
        precondition(insights([event("morning-only", time(10), time(12))]).napMinutes == 0)
        precondition(insights([event("late", time(17), time(18))]).eveningStudy == false)
        precondition(insights([event("evening", time(18), time(20))]).eveningStudy)
        precondition(insights([event("afternoon", time(13), time(15))]).afternoonFree == false)
        let lunch = insights([
            event("morning1", time(8), time(9, 40)),
            event("morning2", time(10), time(11, 40)),
            event("afternoon1", time(13, 50), time(15, 30)),
            event("afternoon2", time(16), time(17))
        ])
        precondition(lunch.napMinutes == 130, "Lunch gap must use the last morning end and first afternoon start")
        precondition(insights([
            event("early-end", time(8), time(10)),
            event("late-start", time(15), time(17))
        ]).napMinutes == 300, "The gap must not be capped at 12:00–14:00")
        precondition(insights([event("afternoon-only", time(14), time(16))]).napMinutes == 0)
        precondition(insights([event("full-lunch", time(11), time(15))]).napMinutes == 0)
        precondition(insights([
            event("cross-noon", time(11), time(13, 30)),
            event("overlap", time(13), time(14))
        ]).napMinutes == 0)
        precondition(insights([
            event("long-morning", time(8), time(12, 30)),
            event("short-morning", time(10), time(11)),
            event("afternoon", time(14), time(16))
        ]).napMinutes == 90, "Use the latest morning end even when morning courses overlap")
        precondition(insights([
            event("morning", time(10), time(11, 50)),
            event("noon-course", time(12), time(13))
        ]).napMinutes == 10)
        precondition(insights([
            event("morning", time(10), time(12)),
            event("evening-only", time(19), time(21))
        ]).napMinutes == 0, "Evening classes are not an afternoon endpoint")

        let placements = CourseTimelinePlacement.make(events: [
            event("a", time(8), time(10)),
            event("b", time(8, 30), time(9, 30)),
            event("c", time(9), time(11)),
            event("d", time(11), time(12))
        ])
        precondition(placements.prefix(3).allSatisfy { $0.columnCount == 3 })
        precondition(Set(placements.prefix(3).map(\.column)).count == 3)
        precondition(placements.last?.columnCount == 1, "Adjacent courses must not share overlap columns")
        precondition(CourseTimelinePlacement.make(events: []).isEmpty)
        print("PASS: course tags, lunch gaps, boundary times and overlap placement (offline)")
    }
}
