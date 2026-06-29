//
//  StatusBar.swift
//  CampuraOne
//
//  Created by Lin Shay on 16/06/2026.
//

import SwiftUI
import SwiftData

#Preview("app - 已登录") {
    ContentView()
        .modelContainer(PreviewContainer.app)
}

// MARK: - 状态栏需要的简单数据

/// 下一节课的信息。
///
/// StatusBar 只负责显示，因此不直接读取课程表数据库。
/// 父视图查到下一节课后，把整理好的数据传进来即可。
struct StatusBarCourse: Identifiable {
    let id: String
    let courseName: String
    let startTime: Date
    let location: String
    
    init(
        id: String = UUID().uuidString,
        courseName: String,
        startTime: Date,
        location: String
    ) {
        self.id = id
        self.courseName = courseName
        self.startTime = startTime
        self.location = location
    }
}

/// 最近一次购买记录。
/// 暂时只保存状态栏真正需要显示的内容，后面有订单模型时再替换。
struct StatusBarPurchase: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    
    init(
        id: String = UUID().uuidString,
        title: String,
        subtitle: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }
}

// MARK: - 横向状态栏

struct StatusBar: View {
    /// 使用项目现有的通用列表 ViewModel 加载服务器课程表。
    /// 与首页课表和课程表详情页统一使用 userID = 5，
    /// 再根据该用户的 studentID 获取所属班级对应的课程表。
    @StateObject private var courseTableViewModel: LoadableListViewModel<CourseTable>
    
    /// 没有购买记录时传 nil。
    let lastPurchase: StatusBarPurchase?
    
    /// 直接复用工具抽屉里定义的 RecentlyViewedItem。
    /// 没有最近浏览内容时传 nil。
    let recentlyViewed: RecentlyViewedItem?
    
    /// 点击“智能分配饮食”时，由父视图决定打开哪个页面。
    let onSmartMealPlan: (StatusBarCourse) -> Void
    
    /// 点击“上次购买”时，由父视图处理跳转。
    let onOpenLastPurchase: (StatusBarPurchase) -> Void
    
    /// 点击“最近看过”时，由父视图处理跳转。
    let onOpenRecentlyViewed: (RecentlyViewedItem) -> Void
    
    /// 控制上课地点气泡是否显示。
    @State private var isShowingLocation = false
    
    /// 已经从服务器课程表中解析出的“下一节课”。
    /// 单独放进 State 后，课程表加载完成时可以明确更新 UI。
    @State private var nextCourse: StatusBarCourse?
    
    /// 区分“服务器没有数据”和“ICS 没解析出来”。
    @State private var courseParseMessage: String?
    
    init(
        schoolID _: Int,
        compoundID _: Int,
        departmentID _: Int,
        classID _: Int,
        lastPurchase: StatusBarPurchase? = nil,
        recentlyViewed: RecentlyViewedItem? = nil,
        onSmartMealPlan: @escaping (StatusBarCourse) -> Void = { _ in },
        onOpenLastPurchase: @escaping (StatusBarPurchase) -> Void = { _ in },
        onOpenRecentlyViewed: @escaping (RecentlyViewedItem) -> Void = { _ in }
    ) {
        _courseTableViewModel = StateObject(
            wrappedValue: LoadableListViewModel<CourseTable>(loader: {
                let user = try await RemoteDataService.shared.fetchUserProfile(
                    userID: 5
                )

                guard let studentID = user.studentID else {
                    return []
                }

                let student = try await RemoteDataService.shared.fetchStudentProfile(
                    studentID: studentID
                )

                let courseTable = try await RemoteDataService.shared.fetchCourseTable(
                    schoolID: student.schoolID,
                    compoundID: student.compoundID,
                    departmentID: student.departmentID,
                    classID: student.classID
                )

                return [courseTable]
            })
        )
        
        self.lastPurchase = lastPurchase
        self.recentlyViewed = recentlyViewed
        self.onSmartMealPlan = onSmartMealPlan
        self.onOpenLastPurchase = onOpenLastPurchase
        self.onOpenRecentlyViewed = onOpenRecentlyViewed
    }
    
    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    if let nextCourse {
                        nextCourseCapsule(
                            nextCourse,
                            now: context.date
                        )
                        
                        locationCapsule(nextCourse)
                        
                        if shouldShowSmartMeal(
                            for: nextCourse,
                            now: context.date
                        ) {
                            smartMealCapsule(nextCourse)
                        }
                    } else if courseTableViewModel.isLoading {
                        Label("正在读取下一节课", systemImage: "clock")
                            .fixedSize(horizontal: true, vertical: false)
                            .statusBarCapsuleStyle()
                    } else if let errorMessage = courseTableViewModel.errorMessage {
                        Label(
                            "课程信息加载失败：\(errorMessage)",
                            systemImage: "exclamationmark.triangle"
                        )
                        .fixedSize(horizontal: true, vertical: false)
                        .statusBarCapsuleStyle()
                        .beButton {
                            Task {
                                await loadCourseTable()
                            }
                        }
                    } else if let courseParseMessage {
                        Label(
                            courseParseMessage,
                            systemImage: "calendar.badge.exclamationmark"
                        )
                        .fixedSize(horizontal: true, vertical: false)
                        .statusBarCapsuleStyle()
                    }
                    
                    if let lastPurchase {
                        lastPurchaseCapsule(lastPurchase)
                    }
                    
                    if let recentlyViewed {
                        recentlyViewedCapsule(recentlyViewed)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
            
            .scrollIndicators(.hidden)
            .task(id: context.date) {
                /// TimelineView 每分钟触发一次，课程开始以后会重新寻找下一节。
                resolveNextCourse(after: context.date)
            }
        }
        .task {
            guard courseTableViewModel.items.isEmpty,
                  !courseTableViewModel.isLoading else {
                resolveNextCourse(after: Date())
                return
            }
            
            await loadCourseTable()
        }
    }
    // MARK: 加载与解析
    
    @MainActor
    private func loadCourseTable() async {
        await courseTableViewModel.load()
        resolveNextCourse(after: Date())
    }
    
    @MainActor
    private func resolveNextCourse(
        after now: Date
    ) {
        guard !courseTableViewModel.items.isEmpty else {
            nextCourse = nil
            
            if !courseTableViewModel.isLoading,
               courseTableViewModel.errorMessage == nil {
                courseParseMessage = "服务器没有返回课程表"
            }
            return
        }
        
        let parsedEventCount = courseTableViewModel.items.reduce(0) { count, table in
            count + SimpleICSParser.parseEvents(from: table.content).count
        }
        
        guard parsedEventCount > 0 else {
            nextCourse = nil
            courseParseMessage = "课程表已加载，但没有解析到 VEVENT"
            print("StatusBar：ICS 未解析到事件")
            print(courseTableViewModel.items.first?.content ?? "课程表 content 为空")
            return
        }
        
        nextCourse = findNextCourse(
            from: courseTableViewModel.items,
            after: now
        )
        
        if nextCourse == nil {
            courseParseMessage = "课程表已加载，但当前没有后续课程"
        } else {
            courseParseMessage = nil
        }
        
        print("StatusBar：课程表数量 = \(courseTableViewModel.items.count)")
        print("StatusBar：解析事件数量 = \(parsedEventCount)")
        print("StatusBar：下一节课 = \(nextCourse?.courseName ?? "无")")
    }
    
    // MARK: 从 ICS 课程表中寻找下一节课
    
    /// 使用你项目里现成的 SimpleICSParser，
    /// 把服务器返回的 CourseTable.content 转成 [ICSEventItem]。
    private func findNextCourse(
        from courseTables: [CourseTable],
        after now: Date
    ) -> StatusBarCourse? {
        let parsedEvents = courseTables.flatMap { courseTable in
            SimpleICSParser.parseEvents(from: courseTable.content)
        }
        
        let nextEvent = parsedEvents
            .compactMap { nextOccurrence(of: $0, after: now) }
            .sorted { first, second in
                first.startTime < second.startTime
            }
            .first
        
        guard let nextEvent else {
            return nil
        }
        
        return StatusBarCourse(
            id: nextEvent.id,
            courseName: nextEvent.title,
            startTime: nextEvent.startTime,
            location: nextEvent.location
        )
    }
    
    /// SimpleICSParser 已经解析出了 DTSTART 和 RRULE，
    /// 这里负责把 DAILY 重复课程换算成“下一次上课时间”。
    private func nextOccurrence(
        of event: ICSEventItem,
        after now: Date
    ) -> (
        id: String,
        title: String,
        startTime: Date,
        location: String
    )? {
        guard let originalStartTime = event.startDate else {
            return nil
        }
        
        let location = event.location ?? ""
        
        guard let recurrenceRule = event.recurrenceRule,
              recurrenceRule.uppercased().contains("FREQ=DAILY") else {
            guard originalStartTime > now else {
                return nil
            }
            
            return (
                id: event.id,
                title: event.title,
                startTime: originalStartTime,
                location: location
            )
        }
        
        let calendar = Calendar.current
        let originalDay = calendar.startOfDay(for: originalStartTime)
        let currentDay = calendar.startOfDay(for: now)
        let passedDays = max(
            calendar.dateComponents(
                [.day],
                from: originalDay,
                to: currentDay
            ).day ?? 0,
            0
        )
        
        guard var candidate = calendar.date(
            byAdding: .day,
            value: passedDays,
            to: originalStartTime
        ) else {
            return nil
        }
        
        if candidate <= now {
            guard let nextDay = calendar.date(
                byAdding: .day,
                value: 1,
                to: candidate
            ) else {
                return nil
            }
            
            candidate = nextDay
        }
        
        if let untilDate = recurrenceEndDate(from: recurrenceRule),
           candidate > untilDate {
            return nil
        }
        
        return (
            id: "\(event.id)-\(candidate.timeIntervalSince1970)",
            title: event.title,
            startTime: candidate,
            location: location
        )
    }
    
    /// 从 `FREQ=DAILY;UNTIL=20260716T235959` 中解析 UNTIL。
    private func recurrenceEndDate(
        from recurrenceRule: String
    ) -> Date? {
        guard let untilPart = recurrenceRule
            .components(separatedBy: ";")
            .first(where: { $0.uppercased().hasPrefix("UNTIL=") }) else {
            return nil
        }
        
        let value = String(
            untilPart.dropFirst("UNTIL=".count)
        )
        
        let formats = [
            "yyyyMMdd'T'HHmmss'Z'",
            "yyyyMMdd'T'HHmmss",
            "yyyyMMdd"
        ]
        
        for format in formats {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = format.contains("'Z'")
                ? TimeZone(secondsFromGMT: 0)
                : .current
            formatter.dateFormat = format
            
            if let date = formatter.date(from: value) {
                return date
            }
        }
        
        return nil
    }
    
    
    // MARK: 下一节课
    
    private func nextCourseCapsule(
        _ course: StatusBarCourse,
        now: Date
    ) -> some View {
        Label {
            Text("\(countdownText(to: course.startTime, now: now)) · \(course.courseName)")
                /// fixedSize 可以避免横向 ScrollView 里的文字被压缩成省略号。
                .fixedSize(horizontal: true, vertical: false)
        } icon: {
            Image(systemName: "book.closed.fill")
        }
        .font(.system(size: 12))
        .statusBarCapsuleStyle()
    }
    
    // MARK: 上课地点
    
    private func locationCapsule(
        _ course: StatusBarCourse
    ) -> some View {
        Label("导航到上课地点", systemImage: "location.fill")
            .fixedSize(horizontal: true, vertical: false)
            .font(.system(size: 12))
            .statusBarCapsuleStyle()
            .beButton {
                isShowingLocation.toggle()
            }
        .buttonStyle(.plain)
        .popover(
            isPresented: $isShowingLocation,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .bottom
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Label("上课地点", systemImage: "mappin.and.ellipse")
                    .font(.headline)
                
                Text(course.location.isEmpty ? "暂未填写上课地点" : course.location)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(idealWidth: 240, alignment: .leading)
            .presentationCompactAdaptation(.popover)
        }
    }
    
    // MARK: 智能饮食
    
    private func smartMealCapsule(
        _ course: StatusBarCourse
    ) -> some View {
        Button {
            onSmartMealPlan(course)
        } label: {
            Label(
                "根据上课时间智能分配饮食",
                systemImage: "sparkles"
            )
            .fixedSize(horizontal: true, vertical: false)
            .font(.system(size: 12))
            .statusBarCapsuleStyle(isHighlighted: true)
        }
        .buttonStyle(.plain)
    }
    
    /// 距离上课时间在 0 到 1.5 小时之间时显示。
    /// 已经开始或已经结束的课程不会显示这个按钮。
    private func shouldShowSmartMeal(
        for course: StatusBarCourse,
        now: Date
    ) -> Bool {
        let remaining = course.startTime.timeIntervalSince(now)
        return remaining > 0 && remaining <= 90 * 60
    }
    
    // MARK: 上次购买
    
    private func lastPurchaseCapsule(
        _ purchase: StatusBarPurchase
    ) -> some View {
        Button {
            onOpenLastPurchase(purchase)
        } label: {
            Label {
                if let subtitle = purchase.subtitle,
                   !subtitle.isEmpty {
                    Text("上次购买：\(purchase.title) · \(subtitle)")
                        .fixedSize(horizontal: true, vertical: false)
                } else {
                    Text("上次购买：\(purchase.title)")
                        .fixedSize(horizontal: true, vertical: false)
                }
            } icon: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .font(.system(size: 12))
            .statusBarCapsuleStyle()
        }
        .buttonStyle(.plain)
    }
    
    // MARK: 最近看过
    
    private func recentlyViewedCapsule(
        _ item: RecentlyViewedItem
    ) -> some View {
        Button {
            onOpenRecentlyViewed(item)
        } label: {
            Label {
                Text("你刚看过：\(item.title)")
                    .fixedSize(horizontal: true, vertical: false)
            } icon: {
                Image(systemName: item.icon)
            }
            .font(.system(size: 12))
            .statusBarCapsuleStyle()
        }
        .buttonStyle(.plain)
    }
    
    // MARK: 倒计时文字
    
    private func countdownText(
        to startTime: Date,
        now: Date
    ) -> String {
        let remaining = startTime.timeIntervalSince(now)
        
        guard remaining > 0 else {
            return "课程即将开始"
        }
        
        let totalMinutes = max(Int(ceil(remaining / 60)), 1)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        
        if hours > 0 && minutes > 0 {
            return "距上课还有 \(hours) h \(minutes) min"
        } else if hours > 0 {
            return "距上课还有 \(hours) h"
        } else {
            return "距上课还有 \(minutes) min"
        }
    }
}

// MARK: - 胶囊统一样式

private extension View {
    /// 所有状态栏项目都使用同一套外观。
    /// 以后想统一改高度、间距或材质，只需要改这里。
    func statusBarCapsuleStyle(
        isHighlighted: Bool = false
    ) -> some View {
        self
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isHighlighted ? Color.accentColor : Color.primary)
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background {
                Capsule(style: .continuous)
                    .fill(
                        isHighlighted
                        ? Material.regular
                        : Material.ultraThin
                    )
            }
            .contentShape(Capsule(style: .continuous))
    }
}
