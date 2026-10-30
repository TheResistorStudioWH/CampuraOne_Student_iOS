import SwiftUI
import PetaKitWatchUIX

struct WatchAgendaView: View {
    let kind: WatchCalendarKind
    let entries: [WatchCalendarEntry]
    @Binding var selectedDate: Date
    let scrollID: UUID
    let status: String?
    let onSelectDate: () -> Void

    private var groups: [(date: Date, events: [WatchCalendarEntry])] {
        let events = WatchCalendarData.agenda(kind: kind, entries: entries, around: selectedDate)
        return Dictionary(grouping: events) { Calendar.current.startOfDay(for: $0.start) }
            .map { (date: $0.key, events: $0.value.sorted { $0.start < $1.start }) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if let status { Text(status).font(.caption2).foregroundStyle(.secondary) }
                Label("选择日期", systemImage: "calendar")
                    .beButton(onSelectDate)
                if groups.isEmpty {
                    Text("暂无安排").foregroundStyle(.secondary)
                }
                ForEach(groups, id: \.date) { group in
                    Section {
                        ForEach(group.events) { event in
                            NavigationLink { WatchEventDetail(event: event, tint: kind.tint) } label: {
                                WatchEventRow(event: event, tint: kind.tint)
                            }
                            .accessibilityIdentifier("calendar.event.\(event.id)")
                        }
                    } header: {
                        Text(WatchDateText.string(group.date, "M月d日 EEEE"))
                            .foregroundStyle(Calendar.current.isDateInToday(group.date) ? .red : .secondary)
                    }
                    .id(group.date)
                }
            }
            .task(id: "\(scrollID)-\(entries.count)") {
                guard !groups.isEmpty else { return }
                // A currently running holiday can start before the selected day.
                let running = groups.first { $0.events.contains { $0.occurs(on: selectedDate) } }
                let target = groups.first(where: { $0.date >= Calendar.current.startOfDay(for: selectedDate) })?.date
                    ?? running?.date ?? groups.last?.date
                if let target { proxy.scrollTo(target, anchor: .top) }
            }
        }
    }
}

struct WatchEventRow: View {
    let event: WatchCalendarEntry
    let tint: Color
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 3)
            VStack(alignment: .leading, spacing: 3) {
                Text(event.title).font(.headline).lineLimit(3)
                Text(WatchDateText.range(event)).font(.caption2).foregroundStyle(.secondary)
                if let location = event.location, !location.isEmpty {
                    Text(location).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

struct WatchMonthView: View {
    let kind: WatchCalendarKind
    let entries: [WatchCalendarEntry]
    let selectedDate: Date
    let select: (Date) -> Void
    private let weekdays = ["一", "二", "三", "四", "五", "六", "日"]

    var body: some View {
        let days = WatchCalendarData.monthDays(containing: selectedDate)
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 2) {
            ForEach(weekdays, id: \.self) { weekday in
                Text(weekday).font(.system(size: 10)).foregroundStyle(.secondary)
            }
            ForEach(days.indices, id: \.self) { index in
                if let date = days[index] {
                    let events = WatchCalendarData.events(on: date, kind: kind, entries: entries)
                    let today = Calendar.current.isDateInToday(date)
                    let selected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                    VStack(spacing: 1) {
                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.system(size: 13, weight: today || selected ? .bold : .regular, design: .rounded))
                            .frame(maxWidth: .infinity, minHeight: days.count > 35 ? 17 : 20)
                            .background {
                                Circle().fill(today ? Color.red : selected ? Color.white.opacity(0.18) : .clear)
                            }
                        Circle().fill(events.isEmpty ? Color.clear : kind.tint).frame(width: 3, height: 3)
                    }
                    .beButton { select(date) }
                    .buttonStyle(.plain)
                    .foregroundStyle(.primary)
                    .accessibilityLabel("\(WatchDateText.string(date, "M月d日 EEEE"))，\(events.count)项安排")
                    .accessibilityIdentifier("calendar.date.\(WatchDateText.string(date, "yyyy-MM-dd"))")
                } else {
                    Color.clear.frame(height: days.count > 35 ? 21 : 24).accessibilityHidden(true)
                }
            }
        }
    }
}

struct WatchDayView: View {
    let date: Date
    let events: [WatchCalendarEntry]
    let tint: Color
    private var timed: [WatchCalendarEntry] { events.filter { !$0.isAllDay } }

    var body: some View {
        VStack(spacing: 10) {
            if events.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar").font(.title2)
                    Text("这一天没有安排").font(.footnote)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity).padding(.vertical, 30)
            }
            ForEach(events.filter(\.isAllDay)) { event in
                NavigationLink { WatchEventDetail(event: event, tint: tint) } label: {
                    WatchEventRow(event: event, tint: tint)
                        .padding(8)
                        .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            if !timed.isEmpty { timeline }
        }
    }

    private var timeline: some View {
        let dayStart = Calendar.current.startOfDay(for: date)
        let firstHour = max(0, min(8, Int(timed.map { $0.start.timeIntervalSince(dayStart) / 3600 }.min() ?? 8)))
        let lastHour = min(24, max(20, Int(ceil(timed.map { $0.end.timeIntervalSince(dayStart) / 3600 }.max() ?? 20))))
        let hourHeight: CGFloat = 60
        let height = CGFloat(lastHour - firstHour) * hourHeight
        let placements = CourseTimelinePlacement.make(events: timed.map(\.course))
        return GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(firstHour...lastHour, id: \.self) { hour in
                    HStack(spacing: 4) {
                        Text(String(format: "%02d", hour))
                            .font(.system(size: 10)).foregroundStyle(.secondary).frame(width: 18, alignment: .leading)
                        Rectangle().fill(.white.opacity(0.16)).frame(height: 0.5)
                    }
                    .offset(y: CGFloat(hour - firstHour) * hourHeight)
                }
                ForEach(placements) { placement in
                    if let event = timed.first(where: { $0.id == placement.id }) {
                        let y = max(0, CGFloat(event.start.timeIntervalSince(dayStart) / 3600 - Double(firstHour)) * hourHeight)
                        let endY = min(height, CGFloat(event.end.timeIntervalSince(dayStart) / 3600 - Double(firstHour)) * hourHeight)
                        let cardHeight = max(32, endY - y - 2)
                        let width = max(20, (geometry.size.width - 24) / CGFloat(placement.columnCount))
                        NavigationLink { WatchEventDetail(event: event, tint: tint) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title).font(.system(size: 12, weight: .semibold)).lineLimit(cardHeight > 60 ? 3 : 1)
                                Text(WatchDateText.range(event)).font(.system(size: 9)).lineLimit(1)
                                if cardHeight > 65, let location = event.location {
                                    Text(location).font(.system(size: 10)).lineLimit(2).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 5).padding(.vertical, 4)
                            .frame(width: width - 2, height: cardHeight, alignment: .topLeading)
                            .background(tint.opacity(0.24), in: RoundedRectangle(cornerRadius: 6))
                            .overlay(alignment: .leading) { Capsule().fill(tint).frame(width: 2).padding(.vertical, 3) }
                        }
                        .buttonStyle(.plain)
                        .offset(x: 24 + CGFloat(placement.column) * width, y: y)
                        .accessibilityIdentifier("calendar.event.\(event.id)")
                        .accessibilityLabel("\(event.title)，\(WatchDateText.range(event))，\(event.location ?? "")")
                    }
                }
                if Calendar.current.isDateInToday(date) {
                    TimelineView(.periodic(from: .now, by: 60)) { context in
                        let y = CGFloat(context.date.timeIntervalSince(dayStart) / 3600 - Double(firstHour)) * hourHeight
                        if y >= 0 && y <= height {
                            HStack(spacing: 0) {
                                Circle().fill(.red).frame(width: 5, height: 5)
                                Rectangle().fill(.red).frame(height: 1)
                            }
                            .padding(.leading, 20).offset(y: y)
                            .allowsHitTesting(false).accessibilityHidden(true)
                        }
                    }
                }
            }
        }
        .frame(height: height + 10)
    }
}

struct WatchWeekView: View {
    let entries: [WatchCalendarEntry]
    let selectedDate: Date
    let select: (Date) -> Void

    var body: some View {
        let days = WatchCalendarData.week(containing: selectedDate)
        let events = days.map { WatchCalendarData.events(on: $0, kind: .courses, entries: entries) }
        VStack(spacing: 8) {
            weekChart(days: days, events: events)
            Text("本周 \(events.reduce(0) { $0 + $1.count }) 节课")
                .font(.caption).foregroundStyle(.secondary)
            ForEach(days.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 8) {
                    VStack(spacing: 2) {
                        Text(WatchDateText.string(days[index], "EE")).font(.caption2)
                        Text(WatchDateText.string(days[index], "d")).font(.title3.bold())
                    }
                    .foregroundStyle(Calendar.current.isDateInToday(days[index]) ? .red : .primary)
                    .frame(width: 34)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(events[index].isEmpty ? "没有课程" : "\(events[index].count) 节课").font(.headline)
                        if let first = events[index].first, let last = events[index].last {
                            Text("\(WatchDateText.time(first.start))–\(WatchDateText.time(last.end))")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                }.padding(.vertical, 4)
                .beButton { select(days[index]) }
                .buttonStyle(.plain)
            }
        }
    }

    private func weekChart(days: [Date], events: [[WatchCalendarEntry]]) -> some View {
        let offsets = zip(days, events).flatMap { day, items in
            items.flatMap { [$0.start.timeIntervalSince(Calendar.current.startOfDay(for: day)) / 3600,
                            $0.end.timeIntervalSince(Calendar.current.startOfDay(for: day)) / 3600] }
        }
        let lower = max(0, min(8, Int(offsets.min() ?? 8)))
        let upper = min(24, max(20, Int(ceil(offsets.max() ?? 20))))
        let chartHeight: CGFloat = 82
        return HStack(alignment: .top, spacing: 3) {
            VStack(spacing: 0) {
                Color.clear.frame(height: 29)
                Text(String(format: "%02d", lower))
                Spacer()
                Text(String(format: "%02d", upper))
            }
            .font(.system(size: 9)).foregroundStyle(.secondary).frame(width: 14, height: chartHeight + 29)
            ForEach(days.indices, id: \.self) { index in
                VStack(spacing: 4) {
                    VStack(spacing: 1) {
                        Text(WatchDateText.string(days[index], "EE").replacingOccurrences(of: "周", with: ""))
                            .font(.system(size: 9))
                        Text(WatchDateText.string(days[index], "d"))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(height: 25)
                    .foregroundStyle(Calendar.current.isDateInToday(days[index]) ? .red : .primary)
                    GeometryReader { geometry in
                        ZStack(alignment: .top) {
                            RoundedRectangle(cornerRadius: 3).fill(.white.opacity(0.07))
                            ForEach(events[index]) { event in
                                let start = Calendar.current.startOfDay(for: days[index])
                                let y = max(0, event.start.timeIntervalSince(start) / 3600 - Double(lower)) / Double(upper - lower) * chartHeight
                                let h = max(3, event.end.timeIntervalSince(event.start) / 3600 / Double(upper - lower) * chartHeight)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.cyan.opacity(0.85))
                                    .frame(width: geometry.size.width, height: h)
                                    .offset(y: y)
                            }
                        }
                    }.frame(height: chartHeight)
                }
                .beButton { select(days[index]) }
                .buttonStyle(.plain)
                .accessibilityLabel("\(WatchDateText.string(days[index], "M月d日 EEEE"))，\(events[index].count)节课")
            }
        }
        .accessibilityIdentifier("calendar.weekOverview")
    }
}
