//
//  CourseTableDetail.swift
//  CampuraOne
//
//  Created by Lin Shay on 09/06/2026.
//

import SwiftUI
import SwiftData

struct CourseTableDetail: View {
    /// 与首页卡片、地图标签观察同一份课表数据。
    @ObservedObject private var courseStore = CourseScheduleStore.shared

    @State private var selectedDate = Date()
    @State private var showNotificationAlert = false
    @State private var lastWeekJump = Date.distantPast
    @StateObject private var calendarPresenter = CalendarEventEditPresenter()

    private let calendar = Calendar.current

    private var allEvents: [ICSEventItem] {
        courseStore.events
    }

    private var selectedWeekDates: [Date] {
        guard let interval = calendar.dateInterval(
            of: .weekOfYear,
            for: selectedDate
        ) else {
            return [selectedDate]
        }

        return (0..<7).compactMap { dayOffset in
            calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: interval.start
            )
        }
    }

    private var selectedDayEvents: [DisplayedCourseEvent] {
        displayedEvents(on: selectedDate)
    }

    private var selectedWeekEvents: [DisplayedCourseEvent] {
        selectedWeekDates
            .flatMap { date in
                displayedEvents(on: date)
            }
            .sorted {
                $0.startDate < $1.startDate
            }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            dayRail
            ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label(
                    "管理课表通知",
                    systemImage: "bell.badge"
                )
                .beButton {
                    showNotificationAlert = true
                }
                dateControlCard
                weekSection
                daySection
            }
            .padding()
            }
        }
        .navigationTitle("课程表")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await courseStore.load()

        }
        .sheet(item: $calendarPresenter.selectedEvent) { event in
            CalendarEventEditSheet(
                event: event,
                eventStore: calendarPresenter.eventStore
            )
        }
        .alert(
            "暂未开放",
            isPresented: $showNotificationAlert
        ) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("课表通知管理功能正在开发中。")
        }
        .alert(
            "无法添加到日历",
            isPresented: Binding(
                get: {
                    calendarPresenter.errorMessage != nil
                },
                set: { isPresented in
                    if !isPresented {
                        calendarPresenter.errorMessage = nil
                    }
                }
            )
        ) {
            Button("知道了", role: .cancel) {
                calendarPresenter.errorMessage = nil
            }
        } message: {
            Text(calendarPresenter.errorMessage ?? "未知错误")
        }
    }

    /// 长按后沿日期轨道拖动；越过两端可继续翻周，轻点也可操作。
    private var dayRail: some View {
        VStack(spacing: 0) {
            Button { shiftWeek(-1) } label: { Image(systemName: "chevron.up") }
                .frame(height: 44).accessibilityLabel("上一周")
            VStack(spacing: 0) {
                ForEach(selectedWeekDates, id: \.self) { date in
                    Button {
                        selectedDate = date
                    } label: {
                        VStack(spacing: 3) {
                            Text(date.formatted(.dateTime.weekday(.narrow)))
                                .font(.caption2)
                            Text(date.formatted(.dateTime.day())).font(.callout.bold())
                        }
                        .foregroundStyle(calendar.isDateInToday(date) ? Color.accentColor : Color.primary)
                        .frame(width: 42, height: 52)
                        .background {
                            if calendar.isDate(date, inSameDayAs: selectedDate) {
                                Capsule().fill(Color.accentColor.opacity(0.16))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                    .accessibilityAddTraits(calendar.isDate(date, inSameDayAs: selectedDate) ? .isSelected : [])
                }
            }
            .gesture(LongPressGesture(minimumDuration: 0.25)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onChanged { value in
                    guard case .second(true, let drag?) = value else { return }
                    let y = drag.location.y
                    if y < 0 || y >= 364 {
                        if Date().timeIntervalSince(lastWeekJump) > 0.65 {
                            shiftWeek(y < 0 ? -1 : 1)
                            lastWeekJump = Date()
                        }
                    } else {
                        let date = selectedWeekDates[min(6, max(0, Int(y / 52)))]
                        if !calendar.isDate(date, inSameDayAs: selectedDate) {
                            selectedDate = date
                            TapSoft()
                        }
                    }
                })
            Button { shiftWeek(1) } label: { Image(systemName: "chevron.down") }
                .frame(height: 44).accessibilityLabel("下一周")
        }
        .padding(.leading, 8).padding(.top, 16)
    }

    private func shiftWeek(_ direction: Int) {
        if let date = calendar.date(byAdding: .weekOfYear, value: direction, to: selectedDate) {
            selectedDate = date
            TapSoft()
        }
    }

    private var dateControlCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("查看课程")
                        .font(.headline)

                    Text("长按左侧日期滑动 · 当天共 \(selectedDayEvents.count) 节课")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                DatePicker(
                    "选择日期",
                    selection: $selectedDate,
                    displayedComponents: .date
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .fixedSize()
            }

            HStack(spacing: 10) {
                dateInfoBlock(
                    title: "年份",
                    value: selectedDate.formatted(
                        .dateTime.year()
                    )
                )

                dateInfoBlock(
                    title: "日期",
                    value: selectedDate.formatted(
                        .dateTime
                            .month(.twoDigits)
                            .day(.twoDigits)
                    )
                )

                dateInfoBlock(
                    title: "星期",
                    value: selectedDate.formatted(
                        .dateTime
                            .weekday(.wide)
                            .locale(Locale(identifier: "zh_CN"))
                    )
                )
            }

            HStack(spacing: 10) {
                Button {
                    withAnimation(.smooth) {
                        selectedDate = Date()
                    }
                } label: {
                    Label(
                        "回到今天",
                        systemImage: "calendar"
                    )
                }
                .buttonStyle(.bordered)

                Spacer()

                Menu {
                    if let dayURL = makeICSURL(
                        from: selectedDayEvents,
                        calendarName: "当天课程",
                        fileName: "课程表-当天"
                    ) {
                        ShareLink(item: dayURL) {
                            Label(
                                "添加当天课程",
                                systemImage: "calendar.badge.plus"
                            )
                        }
                    }

                    if let weekURL = makeICSURL(
                        from: selectedWeekEvents,
                        calendarName: "本周课程",
                        fileName: "课程表-本周"
                    ) {
                        ShareLink(item: weekURL) {
                            Label(
                                "添加本周课程",
                                systemImage: "calendar.badge.plus"
                            )
                        }
                    }
                } label: {
                    Label(
                        "添加到日历",
                        systemImage: "calendar.badge.plus"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    selectedDayEvents.isEmpty
                    && selectedWeekEvents.isEmpty
                )
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thinMaterial)
        }
    }

    private func dateInfoBlock(
        title: String,
        value: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondary.opacity(0.1))
        }
    }

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("本周课表")
                    .font(.headline)

                Spacer()

                if let weekURL = makeICSURL(
                    from: selectedWeekEvents,
                    calendarName: "本周课程",
                    fileName: "课程表-本周"
                ) {
                    ShareLink(item: weekURL) {
                        Image(systemName: "calendar.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("添加本周课程到日历")
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(selectedWeekDates, id: \.self) { date in
                        weekDayCard(date)
                    }
                }
            }
        }
    }

    private func weekDayCard(_ date: Date) -> some View {
        let events = displayedEvents(on: date)
        let isSelected = calendar.isDate(
            date,
            inSameDayAs: selectedDate
        )

        return Button {
            withAnimation(.smooth) {
                selectedDate = date
            }
        } label: {
            VStack(spacing: 8) {
                Text(
                    date.formatted(
                        .dateTime
                            .weekday(.abbreviated)
                            .locale(Locale(identifier: "zh_CN"))
                    )
                )
                .font(.caption.weight(.semibold))

                Text(
                    date.formatted(
                        .dateTime.day()
                    )
                )
                .font(.title3.bold())

                Text(events.isEmpty ? "无课" : "\(events.count) 节")
                    .font(.caption2)
                    .foregroundStyle(
                        isSelected
                        ? Color.white.opacity(0.85)
                        : Color.secondary
                    )
                ForEach(events.prefix(3)) { event in
                    Text(event.event.title)
                        .font(.system(size: 10))
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(4)
                        .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
                }
                Spacer(minLength: 0)
            }
            .padding(8)
            .frame(width: 86, height: 196, alignment: .top)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        isSelected
                        ? Color.accentColor
                        : Color.secondary.opacity(0.12)
                    )
            }
            .foregroundStyle(
                isSelected ? Color.white : Color.primary
            )
        }
        .buttonStyle(.plain)
    }

    private var daySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("当天课程")
                        .font(.headline)

                    Text(
                        selectedDate.formatted(
                            .dateTime
                                .month()
                                .day()
                                .weekday(.wide)
                                .locale(Locale(identifier: "zh_CN"))
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if let dayURL = makeICSURL(
                    from: selectedDayEvents,
                    calendarName: "当天课程",
                    fileName: "课程表-当天"
                ) {
                    ShareLink(item: dayURL) {
                        Image(systemName: "calendar.badge.plus")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("添加当天课程到日历")
                }
            }

            if courseStore.isLoading {
                ProgressView("正在加载课表")
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else if let errorMessage = courseStore.errorMessage {
                VStack(spacing: 10) {
                    Label(
                        "课表加载失败",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.red)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("重新加载") {
                        Task {
                            await courseStore.load(forceRefresh: true)
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, minHeight: 220)
            } else if selectedDayEvents.isEmpty {
                emptyState(
                    icon: "calendar.badge.checkmark",
                    title: "这一天没有课程",
                    message: "可以选择其他日期查看。"
                )
            } else {
                CourseTableDayTimeline(
                    events: selectedDayEvents,
                    onAddEvent: { event in
                        Task {
                            await calendarPresenter.present(
                                event: event.calendarEvent
                            )
                        }
                    }
                )
            }
        }
    }


/// 详情页使用的当天课程时间线。
/// 布局与首页课表时间线保持一致，但保留单节课程添加到系统日历的按钮。
private struct CourseTableDayTimeline: View {
    let events: [DisplayedCourseEvent]
    let onAddEvent: (DisplayedCourseEvent) -> Void

    private let calendar = Calendar.current
    private let startHour = 8
    private let endHour = 20
    private let hourHeight: CGFloat = 52
    private let timeColumnWidth: CGFloat = 46

    private var timelineHeight: CGFloat {
        CGFloat(endHour - startHour) * hourHeight
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            hourLines
            eventBlocks
        }
        .frame(height: timelineHeight)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var hourLines: some View {
        VStack(spacing: 0) {
            ForEach(startHour...endHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: 8) {
                    Text(String(format: "%02d:00", hour))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(width: timeColumnWidth, alignment: .trailing)
                        .offset(y: -6)

                    Rectangle()
                        .fill(.secondary.opacity(0.22))
                        .frame(height: 1)
                }
                .frame(
                    height: hour == endHour ? 1 : hourHeight,
                    alignment: .top
                )
            }
        }
    }

    private var eventBlocks: some View {
        ZStack(alignment: .topLeading) {
            ForEach(events) { item in
                CourseTableTimelineEventBlock(
                    item: item,
                    onAdd: {
                        onAddEvent(item)
                    }
                )
                .frame(
                    height: eventHeight(item)
                )
                .padding(.leading, timeColumnWidth + 10)
                .offset(
                    y: yOffset(for: item.startDate)
                )
            }
        }
    }

    private func yOffset(for date: Date) -> CGFloat {
        let components = calendar.dateComponents(
            [.hour, .minute],
            from: date
        )

        let hour = components.hour ?? startHour
        let minute = components.minute ?? 0
        let decimalHour = CGFloat(hour) + CGFloat(minute) / 60
        let clampedHour = min(
            max(decimalHour, CGFloat(startHour)),
            CGFloat(endHour)
        )

        return (clampedHour - CGFloat(startHour)) * hourHeight
    }

    private func eventHeight(_ item: DisplayedCourseEvent) -> CGFloat {
        let duration = max(
            item.endDate.timeIntervalSince(item.startDate),
            30 * 60
        )

        return max(
            46,
            CGFloat(duration / 3600) * hourHeight
        )
    }
}

private struct CourseTableTimelineEventBlock: View {
    let item: DisplayedCourseEvent
    let onAdd: () -> Void

    private var accentColor: Color {
        let colors: [Color] = [
            .blue,
            .green,
            .purple,
            .orange,
            .pink
        ]

        return colors[abs(item.event.title.hashValue) % colors.count]
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.event.title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(
                        item.startDate.formatted(
                            date: .omitted,
                            time: .shortened
                        )
                    )

                    if let location = item.event.location,
                       !location.isEmpty {
                        Text("·")
                        Text(location)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(action: onAdd) {
                Image(systemName: "calendar.badge.plus")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("添加这节课到系统日历")
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(accentColor.opacity(0.16))
        }
        .foregroundStyle(accentColor)
    }
}

    private func displayedEvents(
        on date: Date
    ) -> [DisplayedCourseEvent] {
        allEvents
            .compactMap {
                DisplayedCourseEvent(
                    event: $0,
                    on: date
                )
            }
            .sorted {
                $0.startDate < $1.startDate
            }
    }

    private func makeICSURL(
        from events: [DisplayedCourseEvent],
        calendarName: String,
        fileName: String
    ) -> URL? {
        guard !events.isEmpty else {
            return nil
        }

        return try? ICSFileExporter.makeTemporaryICSFile(
            events: events.map(\.calendarEvent),
            calendarName: calendarName,
            fileName: fileName
        )
    }

    private func emptyState(
        icon: String,
        title: String,
        message: String
    ) -> some View {
        ContentUnavailableView(
            title,
            systemImage: icon,
            description: Text(message)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

/// 把 ICS 中的单次课程或每周重复课程转换成指定日期上的实际显示时间
private struct DisplayedCourseEvent: Identifiable {
    let event: ICSEventItem
    let startDate: Date
    let endDate: Date

    var id: String {
        "\(event.id)-\(startDate.timeIntervalSince1970)"
    }

    var calendarEvent: ICSEventItem {
        ICSEventItem(
            id: "\(event.id)-\(Int(startDate.timeIntervalSince1970))",
            title: event.title,
            startDate: startDate,
            endDate: endDate,
            location: event.location,
            detail: event.detail,
            recurrenceRule: nil
        )
    }

    init?(
        event: ICSEventItem,
        on selectedDate: Date,
        calendar: Calendar = .current
    ) {
        guard let occurrence = CourseScheduleResolver.events(
            on: selectedDate,
            from: [event],
            calendar: calendar
        ).first,
        let startDate = occurrence.startDate else {
            return nil
        }
        self.event = event
        self.startDate = startDate
        self.endDate = occurrence.endDate
            ?? startDate.addingTimeInterval(60 * 60)
    }
}

#Preview("app - 已登录") {
    ContentView()
        .modelContainer(PreviewContainer.app)
}
