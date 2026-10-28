import SwiftUI

/// A native horizontal scroll view owns the drag; the center highlight never moves.
struct SchoolCalendarDateWheel: View {
    @Binding private var selection: Date
    private let calendar: Calendar
    private let hasEvents: (Date) -> Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .caption2) private var weekdaySize: CGFloat = 9
    @ScaledMetric(relativeTo: .body) private var daySize: CGFloat = 16
    @State private var window: SchoolCalendarDateWindow
    @State private var position: ScrollPosition
    @State private var visibleDay: Date
    @State private var presentedDay: Date
    @State private var itemWidth: CGFloat = 0
    @State private var isUserScrolling = false

    init(
        selection: Binding<Date>,
        calendar: Calendar = .current,
        hasEvents: @escaping (Date) -> Bool
    ) {
        self._selection = selection
        self.calendar = calendar
        self.hasEvents = hasEvents
        let day = calendar.startOfDay(for: selection.wrappedValue)
        _window = State(initialValue: SchoolCalendarDateWindow(centeredOn: day, calendar: calendar))
        _position = State(initialValue: ScrollPosition(x: 0))
        _visibleDay = State(initialValue: day)
        _presentedDay = State(initialValue: day)
    }

    private var selectedDay: Date { calendar.startOfDay(for: selection) }
    private var wheelHeight: CGFloat { weekdaySize + daySize + 25 }

    var body: some View {
        GeometryReader { proxy in
            let cellWidth = proxy.size.width / 5

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(window.days, id: \.self) { day in
                        dayCell(day)
                            .frame(width: cellWidth, height: wheelHeight)
                            .contentShape(Rectangle())
                            .onTapGesture { select(day) }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, cellWidth * 2)
            }
            .scrollIndicators(.hidden)
            .scrollTargetBehavior(SchoolCalendarDaySnapBehavior(dayWidth: cellWidth))
            .scrollPosition($position)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.13))
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1)
                    }
                    .frame(width: cellWidth, height: wheelHeight)
                    .allowsHitTesting(false)
            }
            .onScrollGeometryChange(for: Int.self) { geometry in
                guard cellWidth > 0 else { return 0 }
                return Int(((geometry.contentOffset.x + geometry.contentInsets.leading) / cellWidth).rounded())
            } action: { _, index in
                // Reading geometry keeps the event preview live during a drag. Do not write
                // scrollPosition here: doing so would keep restarting the native gesture.
                guard window.days.indices.contains(index) else { return }
                visibleDay = window.days[index]
                if isUserScrolling { updateSelection(visibleDay) }
            }
            .onScrollPhaseChange { _, phase in
                let wasUserScrolling = isUserScrolling
                isUserScrolling = phase == .tracking || phase == .interacting || phase == .decelerating
                if phase == .idle {
                    if wasUserScrolling { updateSelection(visibleDay) }
                    let oldCount = window.days.count
                    window.extendIfNeeded(around: selectedDay)
                    if window.days.count != oldCount {
                        scrollTo(selectedDay)
                    }
                }
            }
            .onChange(of: cellWidth, initial: true) { _, width in
                itemWidth = width
                scrollTo(selectedDay)
            }
        }
        .frame(height: wheelHeight)
        .onChange(of: selection) { _, date in
            let day = calendar.startOfDay(for: date)
            guard presentedDay != day else { return }
            presentedDay = day
            window.include(day)
            scrollTo(day)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("校历日期")
        .accessibilityValue(accessibilityTitle(selectedDay))
        .accessibilityHint("向上或向下轻扫切换日期")
        .accessibilityAdjustableAction { direction in
            let offset: Int
            switch direction {
            case .increment: offset = 1
            case .decrement: offset = -1
            @unknown default: return
            }
            if let day = calendar.date(byAdding: .day, value: offset, to: selectedDay) {
                select(day)
            }
        }
    }

    private func dayCell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selection)
        let isToday = calendar.isDateInToday(day)

        return VStack(spacing: 4) {
            Text(["日", "一", "二", "三", "四", "五", "六"][calendar.component(.weekday, from: day) - 1])
                .font(.system(size: weekdaySize, weight: .medium, design: .rounded))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)

            Text("\(calendar.component(.day, from: day))")
                .font(.system(size: daySize, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(isSelected || isToday ? Color.accentColor : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Circle()
                .fill(hasEvents(day) ? Color.accentColor : Color.clear)
                .frame(width: 3, height: 3)
        }
        .padding(.horizontal, 2)
        .opacity(isSelected ? 1 : 0.7)
    }

    private func select(_ date: Date) {
        let day = calendar.startOfDay(for: date)
        window.include(day)
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
            presentedDay = day
            selection = day
            scrollTo(day)
        }
    }

    private func updateSelection(_ day: Date) {
        guard selectedDay != day else { return }
        presentedDay = day
        selection = day
    }

    private func scrollTo(_ day: Date) {
        guard itemWidth > 0, let index = window.days.firstIndex(of: day) else { return }
        position.scrollTo(x: CGFloat(index) * itemWidth)
    }

    private func accessibilityTitle(_ day: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日 EEEE"
        return formatter.string(from: day) + (hasEvents(day) ? "，有校历事项" : "，暂无校历事项")
    }
}

/// Five equal slots plus two slots of end padding make each day's centered offset
/// an exact multiple of its width, including after resizing or extending the dates.
private struct SchoolCalendarDaySnapBehavior: ScrollTargetBehavior {
    let dayWidth: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard dayWidth > 0 else { return }
        let lastOffset = max(0, context.contentSize.width - context.containerSize.width)
        target.rect.origin.x = min(lastOffset, max(0, (target.rect.minX / dayWidth).rounded() * dayWidth))
    }
}
