import SwiftUI
import UIKit

struct CourseScheduleTags: View {
    let insights: CourseDayInsights

    var body: some View {
        CourseTagLayout(spacing: 7) {
            if insights.earlyHour == 8 {
                tag("早8", color: .orange)
            }
            if insights.earlyHour == 10 {
                tag("早10", color: .yellow)
            }
            if insights.morningFree {
                tag("上午空闲", color: .green)
            }
            if insights.afternoonFree {
                tag("下午空闲", color: .green)
            }
            if insights.eveningStudy {
                tag("晚自习", color: .purple)
            }
            if insights.napMinutes >= 30 {
                (Text("可午休约").foregroundColor(.primary)
                 + Text("\(insights.napMinutes / 60)").foregroundColor(.pink)
                 + Text("小时").foregroundColor(.primary)
                 + Text("\(insights.napMinutes % 60)").foregroundColor(.pink)
                 + Text("分钟").foregroundColor(.primary))
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.pink.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
            }
        }
    }

    private func tag(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct CourseTagLayout: Layout {
    var spacing: CGFloat

    private func arrangement(width: CGFloat, subviews: Subviews) -> (positions: [CGPoint], height: CGFloat) {
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (positions, y + rowHeight)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 300
        return CGSize(width: width, height: arrangement(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let positions = arrangement(width: bounds.width, subviews: subviews).positions
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + positions[index].x, y: bounds.minY + positions[index].y),
                          anchor: .topLeading, proposal: .unspecified)
        }
    }
}

/// Seven weekday columns, with one row per actual course start time in this week.
struct CourseWeekGrid: View {
    let dates: [Date]
    let events: [[ICSEventItem]]
    @Binding var selectedDate: Date
    private let calendar = Calendar.current
    @ScaledMetric(relativeTo: .caption) private var rowHeight: CGFloat = 74
    private let headerHeight: CGFloat = 60

    private var slots: [Int] {
        Set(events.flatMap { $0 }.compactMap { $0.startDate }.map { minute(of: $0) }).sorted()
    }

    var body: some View {
        GeometryReader { geometry in
            let gutterWidth = max(32, geometry.size.width * 0.1)
            let viewportWidth = max(1, geometry.size.width - gutterWidth - 6)
            let columnWidth = max(64, (viewportWidth - 6 * 5) / 7)
            ScrollViewReader { proxy in
                HStack(alignment: .top, spacing: 6) {
                    VStack(spacing: 0) {
                        Text("时间").frame(height: headerHeight)
                        if slots.isEmpty {
                            Color.clear.frame(height: rowHeight)
                        } else {
                            ForEach(slots, id: \.self) { slot in
                                Text(String(format: "%02d:%02d", slot / 60, slot % 60))
                                    .padding(.top, 6)
                                    .frame(height: rowHeight, alignment: .top)
                            }
                        }
                    }
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .frame(width: gutterWidth)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 5) {
                            ForEachWithIndex(dates, id: \.self) { index, date in
                                dayColumn(date, events: events.indices.contains(index) ? events[index] : [], width: columnWidth)
                                    .id(calendar.startOfDay(for: date))
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
                .padding(.vertical, 3)
                .task(id: calendar.startOfDay(for: selectedDate)) {
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    withAnimation(.smooth(duration: 0.22)) {
                        proxy.scrollTo(calendar.startOfDay(for: selectedDate), anchor: .center)
                    }
                }
            }
        }
        .frame(height: headerHeight + CGFloat(max(1, slots.count)) * rowHeight + 6)
    }

    private func dayColumn(_ date: Date, events: [ICSEventItem], width: CGFloat) -> some View {
        let today = calendar.isDateInToday(date)
        let selected = calendar.isDate(date, inSameDayAs: selectedDate)
        return Button {
            selectedDate = calendar.startOfDay(for: date)
            TapSoft()
        } label: {
            VStack(spacing: 0) {
                VStack(spacing: 6) {
                    Text(date.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "en_US"))).uppercased())
                        .font(.caption2.weight(.semibold))
                    daySymbol(date)
                        .font(.title2.weight(.semibold))
                }
                .foregroundStyle(today ? Color.accentColor : Color.primary)
                .frame(height: headerHeight)

                if slots.isEmpty {
                    Text("无课").font(.caption2).foregroundStyle(.secondary)
                        .frame(height: rowHeight)
                } else {
                    ForEach(slots, id: \.self) { slot in
                        let courses = events.filter { $0.startDate.map { minute(of: $0) == slot } ?? false }
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(courses) { event in
                                Text(event.title)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(courses.count > 1 ? 1 : 3)
                                if courses.count == 1, let location = event.location, !location.isEmpty {
                                    Text(location).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(6)
                        .frame(width: width, height: rowHeight, alignment: .topLeading)
                        .background(alignment: .top) {
                            Rectangle().fill(.secondary.opacity(0.12)).frame(height: 0.5)
                        }
                    }
                }
            }
            .frame(width: width)
            .background(today ? Color.accentColor.opacity(0.13) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(date.formatted(date: .complete, time: .omitted))，共\(events.count)节课")
    }

    @ViewBuilder private func daySymbol(_ date: Date) -> some View {
        let day = calendar.component(.day, from: date)
        let symbol = "\(day).calendar"
        if UIImage(systemName: symbol) != nil {
            Image(systemName: symbol)
        } else {
            Image(systemName: "dock.rectangle")
                .rotationEffect(.degrees(180), anchor: .center)
                .overlay(alignment: .bottom) {
                    Text("\(day)")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.bottom, 3)
                }
        }
    }

    private func minute(of date: Date) -> Int {
        calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }
}

struct CourseScheduleDayTimeline: View {
    let events: [ICSEventItem]
    let date: Date
    let onAddEvent: (ICSEventItem) -> Void
    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 58
    private let gutter: CGFloat = 44
    private let topInset: CGFloat = 10

    private var startHour: Int {
        min(8, events.compactMap(\.startDate).map { calendar.component(.hour, from: $0) }.min() ?? 8)
    }
    private var endHour: Int {
        let day = calendar.startOfDay(for: date)
        let latest = events.compactMap { event -> Date? in
            event.endDate ?? event.startDate?.addingTimeInterval(3600)
        }.map { Int(ceil($0.timeIntervalSince(day) / 3600)) }.max() ?? 20
        return min(24, max(20, latest))
    }
    private var timelineHeight: CGFloat { CGFloat(endHour - startHour) * hourHeight }

    var body: some View {
        GeometryReader { geometry in
            let contentWidth = max(1, geometry.size.width - gutter - 8)
            ZStack(alignment: .topLeading) {
                ForEach(startHour...endHour, id: \.self) { hour in
                    HStack(spacing: 6) {
                        Text(String(format: "%02d:00", hour))
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .frame(width: gutter - 6, alignment: .trailing)
                        Rectangle().fill(.secondary.opacity(0.2)).frame(height: 0.5)
                    }
                    .frame(width: geometry.size.width)
                    .offset(y: topInset + CGFloat(hour - startHour) * hourHeight - 6)
                }
                ForEach(CourseTimelinePlacement.make(events: events)) { placement in
                    let width = contentWidth / CGFloat(placement.columnCount)
                    let start = yPosition(placement.event.startDate)
                    let end = yPosition(placement.event.endDate ?? placement.event.startDate?.addingTimeInterval(3600))
                    CourseTimelineCard(event: placement.event, onAdd: { onAddEvent(placement.event) })
                        .frame(width: max(1, width - 3), height: max(24, end - start - 2), alignment: .topLeading)
                        .offset(x: gutter + CGFloat(placement.column) * width, y: topInset + start)
                }
            }
            .frame(width: geometry.size.width, height: timelineHeight + topInset * 2, alignment: .topLeading)
        }
        .frame(height: timelineHeight + topInset * 2)
    }

    private func yPosition(_ time: Date?) -> CGFloat {
        guard let time else { return 0 }
        let hours = time.timeIntervalSince(calendar.startOfDay(for: date)) / 3600
        return CGFloat(min(Double(endHour), max(Double(startHour), hours)) - Double(startHour)) * hourHeight
    }
}

private struct CourseTimelineCard: View {
    let event: ICSEventItem
    let onAdd: () -> Void

    private var color: Color {
        let colors: [Color] = [.blue, .green, .purple, .orange, .pink]
        let index = event.title.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % colors.count }
        return colors[index]
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .top, spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .top, spacing: 3) {
                        Text(event.title).font(.subheadline.bold()).lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button(action: onAdd) { Image(systemName: "calendar.badge.plus").font(.caption) }
                            .buttonStyle(.plain)
                            .accessibilityLabel("添加\(event.title)到系统日历")
                    }
                    if geometry.size.height > 58, let start = event.startDate {
                        Text(start.formatted(date: .omitted, time: .shortened))
                            .font(.caption2).lineLimit(1)
                    }
                    if geometry.size.height > 80, let location = event.location, !location.isEmpty {
                        Text(location).font(.caption2).lineLimit(1)
                    }
                }
            }
            .padding(7)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 9))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 9))
        }
    }
}
