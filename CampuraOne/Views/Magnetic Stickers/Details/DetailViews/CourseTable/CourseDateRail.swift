import SwiftUI

/// Continuous date scrubber. Tick geometry stays fixed while the touch lens grows,
/// so magnification never changes the date under the finger.
struct CourseDateRail: View {
    @Binding var selectedDate: Date
    var width: CGFloat = 60
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var touch: CGPoint?
    @State private var lastWeekJump = Date.distantPast
    @State private var centerDate = Calendar.current.startOfDay(for: Date())
    private let calendar = Calendar.current

    private var dates: [Date] {
        // Keep a stable window during a drag: today starts at the middle tick,
        // regardless of which weekday it is. Selecting a tick must not move it.
        return (-3...3).compactMap { calendar.date(byAdding: .day, value: $0, to: centerDate) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Button { moveWeek(-1) } label: { Image(systemName: "chevron.up") }
                .frame(width: width, height: 44, alignment: .leading).accessibilityLabel("上一周")
            GeometryReader { geometry in
                let inset = min(24, geometry.size.height * 0.08)
                let span = max(1, geometry.size.height - inset * 2)
                ZStack(alignment: .topLeading) {
                    ForEach(0..<25, id: \.self) { tick in
                        let y = inset + span * CGFloat(tick) / 24
                        tickMark(tick, y: y)
                            .frame(width: width, height: 30, alignment: .leading)
                            .position(x: width / 2, y: y)
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("课表日期时间轴")
            .accessibilityValue(selectedDate.formatted(date: .complete, time: .omitted))
            .accessibilityHint("上下调整一天；也可使用上下方按钮切换周")
            .accessibilityAdjustableAction { direction in
                let offset = direction == .increment ? 1 : -1
                if let date = calendar.date(byAdding: .day, value: offset, to: selectedDate) { select(date) }
            }
            Button { moveWeek(1) } label: { Image(systemName: "chevron.down") }
                .frame(width: width, height: 44, alignment: .leading).accessibilityLabel("下一周")
        }
        .frame(width: width)
        .onAppear {
            centerDate = calendar.startOfDay(for: Date())
            selectedDate = centerDate
        }
        .onChange(of: selectedDate) { _, date in
            if (touch == nil && calendar.isDateInToday(date)) || !dates.contains(where: { calendar.isDate($0, inSameDayAs: date) }) {
                centerDate = calendar.startOfDay(for: date)
            }
        }
    }

    @ViewBuilder private func tickMark(_ tick: Int, y: CGFloat) -> some View {
        let influence = touch.map { max(0, 1 - abs($0.y - y) / 44) } ?? 0
        let isDay = tick.isMultiple(of: 4)
        let date = dates[min(6, tick / 4)]
        let isToday = isDay && calendar.isDateInToday(date)
        let isSelected = isDay && calendar.isDate(date, inSameDayAs: selectedDate)
        let isKey = isDay && (tick == 0 || tick == 24 || isToday || isSelected)
        if isKey {
            VStack(alignment: .leading, spacing: 1) {
                Text(isToday ? "今天" : date.formatted(.dateTime.weekday(.narrow)))
                    .font(.system(size: 9, weight: .medium))
                Text(date.formatted(.dateTime.day())).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isToday ? Color.accentColor : Color.primary)
            .frame(width: 32, height: 30, alignment: .leading)
            .fontWeight(isSelected ? .bold : .regular)
            .scaleEffect(reduceMotion ? 1 : 1 + influence * 0.35, anchor: .leading)
            .offset(x: 8)
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
        if let date = calendar.date(byAdding: .weekOfYear, value: offset, to: selectedDate),
           let center = calendar.date(byAdding: .weekOfYear, value: offset, to: centerDate) {
            centerDate = center
            select(date)
        }
    }
}

private struct CourseDateRailPreview: View {
    @State private var date = Date()
    var body: some View {
        HStack {
            CourseDateRail(selectedDate: $date)
                .frame(height: 520)
            Text(date.formatted(date: .complete, time: .omitted))
        }.padding()
    }
}

#Preview("日期刻度轴") { CourseDateRailPreview() }
