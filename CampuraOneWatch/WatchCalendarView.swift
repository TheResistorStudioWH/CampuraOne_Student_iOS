import SwiftUI

enum WatchCalendarMode: String, CaseIterable, Identifiable {
    case list, day, week, month
    var id: Self { self }
    var title: String {
        switch self {
        case .list: "列表"
        case .day: "日"
        case .week: "周总览"
        case .month: "月"
        }
    }
    var symbol: String {
        switch self {
        case .list: "list.bullet"
        case .day: "rectangle.split.1x2"
        case .week: "rectangle.split.3x3"
        case .month: "calendar"
        }
    }
}

struct WatchCalendarView: View {
    let kind: WatchCalendarKind
    @EnvironmentObject private var store: WatchScheduleStore
    @AppStorage("watch.courses.view") private var courseMode = WatchCalendarMode.day.rawValue
    @AppStorage("watch.school.view") private var schoolMode = WatchCalendarMode.list.rawValue
    @State private var selectedDate = Date()
    @State private var showOptions = false
    @State private var showDatePicker = false
    @State private var dayAnchor = UUID()
    @State private var appliedLaunchMode = false

    private var mode: WatchCalendarMode {
        WatchCalendarMode(rawValue: kind == .courses ? courseMode : schoolMode) ?? .day
    }
    private var model: LoadableListViewModel<WatchCalendarEntry> { store.list(kind) }
    private var entries: [WatchCalendarEntry] { model.items }
    private var dayEvents: [WatchCalendarEntry] { WatchCalendarData.events(on: selectedDate, kind: kind, entries: entries) }

    var body: some View {
        Group {
            if entries.isEmpty && model.isLoading {
                ProgressView("正在更新\(kind.title)")
            } else if entries.isEmpty, let error = model.errorMessage {
                ScrollView {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark").font(.title2).foregroundStyle(.secondary)
                        Text(error).font(.footnote).multilineTextAlignment(.center)
                        Button("重试") { Task { await store.refresh() } }
                    }.padding(.vertical)
                }
            } else {
                calendarContent
            }
        }
        .navigationTitle(kind.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("更多选项", systemImage: "ellipsis") { showOptions = true }
                    .accessibilityIdentifier("calendar.options")
            }
            if !Calendar.current.isDateInToday(selectedDate) || mode == .list {
                ToolbarItem(placement: .bottomBar) {
                    Button("今天") {
                        selectedDate = Date()
                        dayAnchor = UUID()
                    }
                    .accessibilityIdentifier("calendar.today")
                }
            }
        }
        .sheet(isPresented: $showOptions) { options }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                Form {
                    DatePicker("日期", selection: $selectedDate, displayedComponents: .date)
                    Button("完成") { showDatePicker = false; dayAnchor = UUID() }
                }.navigationTitle("选择日期")
            }
        }
        .onAppear {
            #if DEBUG
            guard !appliedLaunchMode else { return }
            appliedLaunchMode = true
            let args = ProcessInfo.processInfo.arguments
            if let index = args.firstIndex(of: "--watch-view"), args.indices.contains(index + 1),
               let requested = WatchCalendarMode(rawValue: args[index + 1]) { setMode(requested) }
            #endif
        }
    }

    @ViewBuilder private var calendarContent: some View {
        switch mode {
        case .list:
            WatchAgendaView(kind: kind, entries: entries, selectedDate: $selectedDate, scrollID: dayAnchor,
                            status: statusText, onSelectDate: { showDatePicker = true })
        case .day:
            ScrollView {
                VStack(spacing: 12) {
                    dateHeader(component: .day)
                    status
                    WatchDayView(date: selectedDate, events: dayEvents, tint: kind.tint)
                }
            }
        case .month:
            ScrollView {
                VStack(spacing: 5) {
                    dateHeader(component: .month)
                    WatchMonthView(kind: kind, entries: entries, selectedDate: selectedDate) { date in
                        selectedDate = date
                        setMode(.day)
                    }
                    status
                }
            }
        case .week:
            ScrollView {
                VStack(spacing: 6) {
                    dateHeader(component: .weekOfYear)
                    WatchWeekView(entries: entries, selectedDate: selectedDate) { date in
                        selectedDate = date
                        setMode(.day)
                    }
                    status
                }
            }
        }
    }

    private func dateHeader(component: Calendar.Component) -> some View {
        HStack(spacing: 4) {
            Button { move(component, by: -1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel(component == .month ? "上个月" : component == .weekOfYear ? "上一周" : "前一天")
            Spacer(minLength: 0)
            Button { showDatePicker = true } label: {
                VStack(spacing: 2) {
                    if component == .day {
                        Text(WatchDateText.string(selectedDate, "M月d日"))
                            .font(.caption2).foregroundStyle(.red)
                    }
                    Text(headerTitle(component))
                        .font(component == .day ? .title3.bold() : .headline)
                        .foregroundStyle(component == .day ? Color.primary : Color.red)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("选择日期，\(WatchDateText.string(selectedDate, "yyyy年M月d日"))")
            Spacer(minLength: 0)
            Button { move(component, by: 1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel(component == .month ? "下个月" : component == .weekOfYear ? "下一周" : "后一天")
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 4)
    }

    private func headerTitle(_ component: Calendar.Component) -> String {
        if component == .month { return WatchDateText.string(selectedDate, "yyyy年M月") }
        if component == .weekOfYear {
            let days = WatchCalendarData.week(containing: selectedDate)
            return "\(WatchDateText.string(days[0], "M/d")) – \(WatchDateText.string(days[6], "M/d"))"
        }
        return WatchDateText.string(selectedDate, "EEEE")
    }

    private func move(_ component: Calendar.Component, by value: Int) {
        selectedDate = Calendar.current.date(byAdding: component, value: value, to: selectedDate) ?? selectedDate
        dayAnchor = UUID()
    }

    private var options: some View {
        NavigationStack {
            List {
                Section("显示方式") {
                    ForEach(WatchCalendarMode.allCases.filter { kind == .courses || $0 != .week }) { choice in
                        Button {
                            setMode(choice)
                            showOptions = false
                        } label: {
                            HStack {
                                Label(choice.title, systemImage: choice.symbol)
                                Spacer()
                                if mode == choice { Image(systemName: "checkmark").foregroundStyle(.red) }
                            }
                        }
                        .accessibilityIdentifier("calendar.mode.\(choice.rawValue)")
                    }
                }
                Button("选择日期", systemImage: "calendar") {
                    showOptions = false
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        showDatePicker = true
                    }
                }
                Button("刷新", systemImage: "arrow.clockwise") {
                    showOptions = false
                    Task { await store.refresh() }
                }
                .disabled(model.isLoading)
                if let updated = store.updatedAt[kind] {
                    Text("更新于 \(WatchDateText.string(updated, "M/d HH:mm"))")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("显示选项")
        }
    }

    private func setMode(_ mode: WatchCalendarMode) {
        if kind == .courses { courseMode = mode.rawValue } else { schoolMode = mode.rawValue }
    }

    private var statusText: String? {
        if model.isLoading { return "正在更新" }
        guard model.errorMessage != nil else { return nil }
        if let updated = store.updatedAt[kind] {
            return "暂未更新 · \(WatchDateText.string(updated, "M/d HH:mm"))"
        }
        return "暂未更新"
    }

    @ViewBuilder private var status: some View {
        if let statusText { Text(statusText).font(.caption2).foregroundStyle(.secondary) }
    }
}

enum WatchDateText {
    static func string(_ date: Date, _ format: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
    static func time(_ date: Date) -> String { string(date, "HH:mm") }
    static func range(_ event: WatchCalendarEntry) -> String {
        if event.isAllDay {
            let lastDay = max(event.start, event.end.addingTimeInterval(-1))
            if Calendar.current.isDate(event.start, inSameDayAs: lastDay) { return string(event.start, "M月d日") + " · 全天" }
            return "\(string(event.start, "M月d日")) – \(string(lastDay, "M月d日")) · 全天"
        }
        return "\(time(event.start))–\(time(event.end))"
    }
}

struct WatchEventDetail: View {
    let event: WatchCalendarEntry
    let tint: Color
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 28, height: 4)
                Text(event.title).font(.title3.bold()).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(WatchDateText.string(event.start, "yyyy年M月d日 EEEE"))
                    Text(WatchDateText.range(event)).foregroundStyle(.secondary)
                }.font(.footnote)
                if let location = event.location, !location.isEmpty {
                    Divider()
                    Label(location, systemImage: "mappin.and.ellipse").font(.footnote)
                }
                if let notes = event.notes, !notes.isEmpty {
                    Divider()
                    Text("备注").font(.caption).foregroundStyle(.secondary)
                    Text(notes).font(.footnote).fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.bottom)
        }
        .navigationTitle("日程详情")
    }
}
