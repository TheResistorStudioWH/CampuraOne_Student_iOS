import Foundation

/// Stable day IDs let the wheel grow without resetting its selection at a week or month boundary.
struct SchoolCalendarDateWindow {
    let calendar: Calendar
    private(set) var days: [Date]

    private let pageSize = 90
    private let extensionThreshold = 21

    init(centeredOn date: Date, calendar: Calendar = .current) {
        self.calendar = calendar
        let day = calendar.startOfDay(for: date)
        days = (-90...90).compactMap {
            calendar.date(byAdding: .day, value: $0, to: day)
        }
    }

    mutating func include(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        guard !days.contains(day) else { return }
        self = Self(centeredOn: day, calendar: calendar)
    }

    /// Only called after scrolling stops, so prepending days cannot interrupt a drag.
    mutating func extendIfNeeded(around date: Date) {
        let day = calendar.startOfDay(for: date)
        guard let index = days.firstIndex(of: day),
              let first = days.first,
              let last = days.last else { return }

        if index < extensionThreshold {
            let earlier = (-pageSize ..< 0).compactMap {
                calendar.date(byAdding: .day, value: $0, to: first)
            }
            days.insert(contentsOf: earlier, at: 0)
        }
        if days.count - 1 - (days.firstIndex(of: day) ?? index) < extensionThreshold {
            days += (1...pageSize).compactMap {
                calendar.date(byAdding: .day, value: $0, to: last)
            }
        }
    }
}
