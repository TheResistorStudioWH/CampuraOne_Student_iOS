import SwiftUI

/// Continuous date scrubber. Tick geometry stays fixed while the touch lens grows,
/// so magnification never changes the date under the finger.
struct CourseDateRail: View {
    @Binding var selectedDate: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var touch: CGPoint?
    @State private var lastWeekJump = Date.distantPast
    private let calendar = Calendar.current
    private let inset: CGFloat = 24

    private var dates: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start
            ?? calendar.startOfDay(for: selectedDate)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button { moveWeek(-1) } label: { Image(systemName: "chevron.up") }
                .frame(width: 60, height: 44).accessibilityLabel("上一周")
            GeometryReader { geometry in
                let span = max(1, geometry.size.height - inset * 2)
                ZStack(alignment: .topLeading) {
                    Capsule().fill(.secondary.opacity(0.07))
                    Capsule().fill(.secondary.opacity(0.14))
                        .frame(width: 2, height: span)
                        .position(x: 30, y: geometry.size.height / 2)
                    ForEach(0..<25, id: \.self) { tick in
                        let y = inset + span * CGFloat(tick) / 24
                        tickMark(tick, y: y)
                            .position(x: 30, y: y)
                    }
                }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0)
                    .updating($touch) { value, state, _ in state = value.location }
                    .onChanged { value in
                        let y = value.location.y
                        if y < 0 || y > geometry.size.height {
                            if Date().timeIntervalSince(lastWeekJump) > 0.65 {
                                moveWeek(y < 0 ? -1 : 1)
                                lastWeekJump = Date()
                            }
                        } else {
                            let index = min(6, max(0, Int(((y - inset) / span * 6).rounded())))
                            select(dates[index])
                        }
                    }
                    .onEnded { _ in lastWeekJump = .distantPast })
                .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.85), value: touch != nil)
            }
            .frame(maxHeight: 380)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("课表日期时间轴")
            .accessibilityValue(selectedDate.formatted(date: .complete, time: .omitted))
            .accessibilityHint("上下调整一天；也可使用上下方按钮切换周")
            .accessibilityAdjustableAction { direction in
                let offset = direction == .increment ? 1 : -1
                if let date = calendar.date(byAdding: .day, value: offset, to: selectedDate) { select(date) }
            }
            Button { moveWeek(1) } label: { Image(systemName: "chevron.down") }
                .frame(width: 60, height: 44).accessibilityLabel("下一周")
        }
        .frame(width: 60)
        .frame(maxHeight: 468)
    }

    @ViewBuilder private func tickMark(_ tick: Int, y: CGFloat) -> some View {
        let influence = touch.map { max(0, 1 - abs($0.y - y) / 44) } ?? 0
        let isDay = tick.isMultiple(of: 4)
        let date = dates[min(6, tick / 4)]
        let isToday = isDay && calendar.isDateInToday(date)
        let isSelected = isDay && calendar.isDate(date, inSameDayAs: selectedDate)
        let isKey = isDay && (tick == 0 || tick == 24 || isToday || isSelected)
        if isKey {
            VStack(spacing: 1) {
                Text(isToday ? "今天" : date.formatted(.dateTime.weekday(.narrow)))
                    .font(.system(size: 9, weight: .medium))
                Text(date.formatted(.dateTime.day())).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isToday ? Color.accentColor : Color.primary)
            .frame(width: 32, height: 30)
            .background(isSelected ? Color.accentColor.opacity(0.16) : Color.clear, in: Capsule())
            .scaleEffect(reduceMotion ? 1 : 1 + influence * 0.35)
            .zIndex(1)
        } else {
            Capsule()
                .fill(influence > 0.5 ? Color.accentColor : Color.secondary.opacity(isDay ? 0.7 : 0.3))
                .frame(width: (isDay ? 14 : 7) + (reduceMotion ? 0 : influence * 12), height: isDay ? 2 : 1.5)
        }
    }

    private func select(_ date: Date) {
        guard !calendar.isDate(date, inSameDayAs: selectedDate) else { return }
        selectedDate = date
        TapSoft()
    }

    private func moveWeek(_ offset: Int) {
        if let date = calendar.date(byAdding: .weekOfYear, value: offset, to: selectedDate) { select(date) }
    }
}

private struct CourseDateRailPreview: View {
    @State private var date = Date()
    var body: some View {
        HStack {
            CourseDateRail(selectedDate: $date)
            Text(date.formatted(date: .complete, time: .omitted))
        }.padding()
    }
}

#Preview("日期刻度轴") { CourseDateRailPreview() }
