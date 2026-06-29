//
//  CourseTableDetail.swift
//  CampuraOne
//
//  Created by Lin Shay on 09/06/2026.
//

import SwiftUI
import SwiftData

struct CourseTableDetail: View {
    /// 与首页课表卡片使用完全相同的用户和课程表请求链路。
    /// 与首页时间线使用同一个展示用户：userID = 5。
    @StateObject private var viewModel = LoadableListViewModel<ICSEventItem>(loader: {
        let user = try await RemoteDataService.shared.fetchUserProfile(userID: 5)

        guard let studentID = user.studentID else {
            return []
        }

        let student = try await RemoteDataService.shared.fetchStudentProfile(
            studentID: studentID
        )

        let icsText = try await RemoteDataService.shared.fetchCourseTableICS(
            schoolID: student.schoolID,
            compoundID: student.compoundID,
            departmentID: student.departmentID,
            classID: student.classID
        )

        return SimpleICSParser.parseEvents(from: icsText)
            .sorted { lhs, rhs in
                (lhs.startDate ?? .distantFuture)
                < (rhs.startDate ?? .distantFuture)
            }
    })

    @State private var selectedDate = Date()
    @State private var showNotificationAlert = false
    @StateObject private var calendarPresenter = CalendarEventEditPresenter()

    private let calendar = Calendar.current

    private var allEvents: [ICSEventItem] {
        viewModel.items
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
        .navigationTitle("课程表")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()

            /// 加载完成后默认跳到课表中第一天，避免当前日期不在演示课表范围内时整页显示为空。
            if let firstDate = viewModel.items
                .compactMap(\.startDate)
                .sorted()
                .first {
                selectedDate = firstDate
            }
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

    private var dateControlCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("查看课程")
                        .font(.headline)

                    Text("选择任意日期查看对应周和当天课程")
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
            }
            .frame(width: 64, height: 86)
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

            if viewModel.isLoading {
                ProgressView("正在加载课表")
                    .frame(maxWidth: .infinity, minHeight: 220)
            } else if let errorMessage = viewModel.errorMessage {
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
                            await viewModel.load()
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
        guard let originalStart = event.startDate else {
            return nil
        }

        let originalEnd = event.endDate
            ?? calendar.date(
                byAdding: .hour,
                value: 1,
                to: originalStart
            )
            ?? originalStart

        let duration = max(
            originalEnd.timeIntervalSince(originalStart),
            0
        )

        if calendar.isDate(originalStart, inSameDayAs: selectedDate) {
            self.event = event
            self.startDate = originalStart
            self.endDate = originalEnd
            return
        }

        guard let recurrenceRule = event.recurrenceRule,
              Self.matchesWeeklyRecurrence(
                rule: recurrenceRule,
                originalStart: originalStart,
                selectedDate: selectedDate,
                calendar: calendar
              ),
              let displayedStart = Self.date(
                selectedDate,
                usingTimeFrom: originalStart,
                calendar: calendar
              ) else {
            return nil
        }
        
        self.event = event
        self.startDate = displayedStart
        self.endDate = displayedStart.addingTimeInterval(duration)
    }

    private static func matchesWeeklyRecurrence(
        rule: String,
        originalStart: Date,
        selectedDate: Date,
        calendar: Calendar
    ) -> Bool {
        let values = Dictionary(
            uniqueKeysWithValues: rule
                .split(separator: ";")
                .compactMap { component -> (String, String)? in
                    let pair = component.split(
                        separator: "=",
                        maxSplits: 1
                    )

                    guard pair.count == 2 else {
                        return nil
                    }

                    return (
                        String(pair[0]).uppercased(),
                        String(pair[1]).uppercased()
                    )
                }
        )

        guard values["FREQ"] == "WEEKLY" else {
            return false
        }

        let selectedDay = calendar.startOfDay(for: selectedDate)
        let originalDay = calendar.startOfDay(for: originalStart)

        guard selectedDay >= originalDay else {
            return false
        }

        if let untilText = values["UNTIL"],
           let untilDate = parseUntilDate(untilText),
           selectedDay > calendar.startOfDay(for: untilDate) {
            return false
        }

        let allowedWeekdays = values["BYDAY"]?
            .split(separator: ",")
            .compactMap {
                weekdayNumber(for: String($0))
            }

        if let allowedWeekdays,
           !allowedWeekdays.isEmpty,
           !allowedWeekdays.contains(
                calendar.component(
                    .weekday,
                    from: selectedDate
                )
           ) {
            return false
        }

        let interval = max(
            Int(values["INTERVAL"] ?? "1") ?? 1,
            1
        )

        let weeks = calendar.dateComponents(
            [.weekOfYear],
            from: originalDay,
            to: selectedDay
        ).weekOfYear ?? 0

        return weeks % interval == 0
    }

    private static func date(
        _ day: Date,
        usingTimeFrom source: Date,
        calendar: Calendar
    ) -> Date? {
        let time = calendar.dateComponents(
            [.hour, .minute, .second],
            from: source
        )

        return calendar.date(
            bySettingHour: time.hour ?? 0,
            minute: time.minute ?? 0,
            second: time.second ?? 0,
            of: day
        )
    }

    private static func weekdayNumber(
        for token: String
    ) -> Int? {
        switch String(token.suffix(2)) {
        case "SU": return 1
        case "MO": return 2
        case "TU": return 3
        case "WE": return 4
        case "TH": return 5
        case "FR": return 6
        case "SA": return 7
        default: return nil
        }
    }

    private static func parseUntilDate(
        _ text: String
    ) -> Date? {
        let formats = [
            "yyyyMMdd'T'HHmmss'Z'",
            "yyyyMMdd'T'HHmmss",
            "yyyyMMdd"
        ]

        for format in formats {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = text.hasSuffix("Z")
                ? TimeZone(secondsFromGMT: 0)
                : .current
            formatter.dateFormat = format

            if let date = formatter.date(from: text) {
                return date
            }
        }

        return nil
    }
}

#Preview("app - 已登录") {
    ContentView()
        .modelContainer(PreviewContainer.app)
}
