import SwiftUI
import PetaKitUIX
import SwiftData

struct CourseTableDetail: DashboardDetailContent {
    static let tileDescriptor = DashboardTileDescriptor(
        id: "courseTable", title: "日程表", systemImage: "calendar.badge.clock"
    )

    @ObservedObject private var courseStore = CourseScheduleStore.shared
    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @State private var showsDatePicker = false
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
        GeometryReader { geometry in
            let railWidth = min(64, max(48, geometry.size.width * 0.14))
            VStack(alignment: .leading, spacing: 18) {
                dayHeading
                    .padding(.leading, 16)
                    .padding(.trailing, DashboardDetailChrome.controlsWidth + 24)

                HStack(alignment: .top, spacing: 0) {
                    dateSidebar(width: railWidth)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            if !courseStore.isLoading, courseStore.errorMessage == nil {
                                CourseScheduleTags(insights: CourseDayInsights(events: dayEvents, date: selectedDate))
                                weekSection
                            }
                            daySection
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 10)
                        .padding(.trailing, 16)
                        .padding(.bottom, 24)
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
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

    private func dateSidebar(width: CGFloat) -> some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 8) {
                dateSelector(width: width)
                railButton(color: .blue, width: width) {
                    selectedDate = calendar.startOfDay(for: Date())
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "calendar.badge.clock")
                            .symbolRenderingMode(.multicolor)
                            .font(.system(size: 19, weight: .semibold))
                        Text("今天")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(.blue)
                }
                .accessibilityLabel("回到今天")
                CourseDateRail(selectedDate: $selectedDate, width: width)
                    .frame(maxHeight: .infinity)
            }
            .padding(.top, geometry.size.height * 0.04)
            .padding(.bottom, geometry.size.height * 0.02)
        }
        .frame(width: width)
    }

    private func dateSelector(width: CGFloat) -> some View {
        railButton(color: .red, width: width) {
            showsDatePicker = true
        } label: {
            Image(systemName: "calendar")
                .symbolRenderingMode(.multicolor)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(.red)
        }
        .accessibilityLabel("选择日程日期")
        .popover(isPresented: $showsDatePicker, arrowEdge: .leading) {
            VStack(spacing: 12) {
                DatePicker("选择日程日期", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
                Button("回到今天") {
                    selectedDate = calendar.startOfDay(for: Date())
                    showsDatePicker = false
                }
                .font(.subheadline.weight(.semibold))
                .padding(.bottom, 8)
            }
                .padding(12)
                .frame(idealWidth: 320)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .presentationCompactAdaptation(.popover)
                .onChange(of: selectedDate) { _, _ in showsDatePicker = false }
        }
    }

    private func railButton<Label: View>(
        color: Color,
        width: CGFloat,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        label()
            .frame(width: width, height: width)
            .background(color.opacity(0.14), in: UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 13,
                topTrailingRadius: 13
            ))
            .beButton(action)
            .buttonStyle(.plain)
    }

    private var dayHeading: some View {
        HStack(spacing: 8) {
            dateLabel
            lessonCount
        }
    }

    private var dateLabel: some View {
        Text(selectedDate.formatted(.dateTime.year().month().day().locale(Locale(identifier: "zh_CN"))))
            .font(.title2)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }

    private var lessonCount: some View {
        HStack(spacing: 2) {
            Text("共")
            if courseStore.isLoading || courseStore.errorMessage != nil {
                Text("/")
                    .foregroundStyle(Color.accentColor)
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
                VStack(alignment: .leading, spacing: 3) {
                    Text(weekDates.contains(where: calendar.isDateInToday) ? "本周课表" : "当周课表")
                        .font(.headline)
                    if let first = weekDates.first, let last = weekDates.last {
                        Text("\(weekDateTitle(first)) — \(weekDateTitle(last))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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

    private func weekDateTitle(_ date: Date) -> String {
        date.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN")))
    }

    // The edge-aligned date rail and independently scrolling content require this
    // feature's full-height presentation rather than the default outer ScrollView.
    func dashboardPresentation(in context: DashboardDetailContext) -> some View {
        let insets = context.safeAreaInsets
        return VStack(alignment: .leading, spacing: 14) {
            DashboardDetailTitle(context: context)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
                .padding(.trailing, DashboardDetailChrome.controlsWidth + 24)
            self
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, insets.top + 12)
        .padding(.bottom, insets.bottom + 8)
        .overlay(alignment: .topTrailing) {
            context.controls
                .padding(.top, insets.top + 10)
                .padding(.trailing, 16)
        }
        .padding(.leading, insets.leading)
        .padding(.trailing, insets.trailing)
    }
}
