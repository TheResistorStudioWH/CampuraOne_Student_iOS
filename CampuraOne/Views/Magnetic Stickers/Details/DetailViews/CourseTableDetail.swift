import SwiftUI
import SwiftData

struct CourseTableDetail: View {
    @ObservedObject private var courseStore = CourseScheduleStore.shared
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @StateObject private var calendarPresenter = CalendarEventEditPresenter()
    private let calendar = Calendar.current

    private var weekDates: [Date] {
        let day = calendar.startOfDay(for: selectedDate)
        let daysSinceMonday = (calendar.component(.weekday, from: day) + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -daysSinceMonday, to: day)!
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }
    private var dayEvents: [ICSEventItem] { events(on: selectedDate) }
    private var weekEvents: [[ICSEventItem]] { weekDates.map { events(on: $0) } }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                dateSelector
                CourseDateRail(selectedDate: $selectedDate)
            }
            .padding(.top, screen.height * 0.035)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    dayHeading
                    if !courseStore.isLoading, courseStore.errorMessage == nil {
                        CourseScheduleTags(insights: CourseDayInsights(events: dayEvents, date: selectedDate))
                        weekSection
                    }
                    daySection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                .padding(.trailing, 2)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear { selectedDate = calendar.startOfDay(for: Date()) }
        .task { await courseStore.load() }
        .sheet(item: $calendarPresenter.selectedEvent) { event in
            CalendarEventEditSheet(event: event, eventStore: calendarPresenter.eventStore)
        }
        .alert("无法添加到日历", isPresented: Binding(
            get: { calendarPresenter.errorMessage != nil },
            set: { if !$0 { calendarPresenter.errorMessage = nil } }
        )) {
            Button("知道了", role: .cancel) { calendarPresenter.errorMessage = nil }
        } message: {
            Text(calendarPresenter.errorMessage ?? "未知错误")
        }
    }

    private var dateSelector: some View {
        HStack(spacing: 8) {
            DatePicker(selection: $selectedDate, displayedComponents: .date) {
                Image(systemName: "calendar")
            }
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .accessibilityLabel("选择日程日期")
            Spacer(minLength: 0)
            if !calendar.isDateInToday(selectedDate) {
                Button("今天") { selectedDate = calendar.startOfDay(for: Date()) }
                    .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var dayHeading: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                dateLabel
                Spacer(minLength: 0)
                lessonCount
            }
            VStack(alignment: .leading, spacing: 10) {
                dateLabel
                lessonCount
            }
        }
    }

    private var dateLabel: some View {
        Text(selectedDate.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN"))))
            .font(.title2)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var lessonCount: some View {
        HStack(spacing: 2) {
            Text("共")
            if courseStore.isLoading || courseStore.errorMessage != nil {
                Text("—").foregroundStyle(Color.accentColor)
            } else {
                Text("\(dayEvents.count)").foregroundStyle(Color.accentColor).fontWeight(.bold)
            }
            Text("节课")
        }
        .font(.subheadline)
        .fixedSize()
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }

    private var weekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("本周课表").font(.headline)
                Spacer()
                exportLink(events: weekEvents.flatMap { $0 }, week: true)
            }
            CourseWeekGrid(dates: weekDates, events: weekEvents, selectedDate: $selectedDate)
        }
    }

    private var daySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(calendar.isDateInToday(selectedDate) ? "今日日程" : "当日日程").font(.headline)
                Spacer()
                exportLink(events: dayEvents, week: false)
            }
            if courseStore.isLoading {
                ProgressView("正在加载课表").frame(maxWidth: .infinity, minHeight: 180)
            } else if let error = courseStore.errorMessage {
                VStack(spacing: 10) {
                    Label("课表加载失败", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                    Text(error).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    Button("重新加载") { Task { await courseStore.load(forceRefresh: true) } }
                        .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
            } else if dayEvents.isEmpty {
                ContentUnavailableView("这一天没有课程", systemImage: "calendar.badge.checkmark",
                                       description: Text("可以选择其他日期查看。"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                CourseScheduleDayTimeline(events: dayEvents, date: selectedDate) { event in
                    Task { await calendarPresenter.present(event: event) }
                }
            }
        }
    }

    @ViewBuilder private func exportLink(events: [ICSEventItem], week: Bool) -> some View {
        if !events.isEmpty, let url = try? ICSFileExporter.makeTemporaryICSFile(
            events: events, calendarName: week ? "本周课程" : "当天课程",
            fileName: week ? "课程表-本周" : "课程表-当天"
        ) {
            ShareLink(item: url) { Image(systemName: "calendar.badge.plus") }
                .buttonStyle(.bordered)
                .accessibilityLabel(week ? "添加本周课程到日历" : "添加当天课程到日历")
        }
    }

    private func events(on date: Date) -> [ICSEventItem] {
        CourseScheduleResolver.events(on: date, from: courseStore.events, calendar: calendar)
    }
}
