//
//  StatusBar.swift
//  CampuraOne
//
//  Created by Lin Shay on 16/06/2026.
//

import SwiftUI
import SwiftData
import MapKit
import CoreLocation

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
    private struct RouteAssessment {
        enum Urgency {
            case comfortable
            case leaveSoon
            case late

            var color: Color {
                switch self {
                case .comfortable: return .green
                case .leaveSoon: return .orange
                case .late: return .red
                }
            }

            var icon: String {
                switch self {
                case .comfortable: return "checkmark.circle.fill"
                case .leaveSoon: return "figure.walk.motion"
                case .late: return "exclamationmark.triangle.fill"
                }
            }
        }

        let walkingTime: TimeInterval
        let suggestedDeparture: Date
        let urgency: Urgency
    }

    /// 与首页和详情页共用同一份课表，不再独立请求。
    @ObservedObject private var courseStore = CourseScheduleStore.shared

    /// 地图页的实时位置，用于估算走到下一节课的时间。
    let currentLocation: CLLocation?
    
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

    /// 基于 MapKit 步行路线的出发建议，这一步不需要 AI。
    @State private var routeAssessment: RouteAssessment?
    @State private var isCalculatingRoute = false

    private var routeRequestID: String {
        guard let course = nextCourse,
              let currentLocation,
              !course.location.isEmpty else {
            return "no-route"
        }

        return String(
            format: "%@-%.4f-%.4f-%@",
            course.id,
            currentLocation.coordinate.latitude,
            currentLocation.coordinate.longitude,
            course.location
        )
    }
    
    init(
        schoolID _: Int,
        compoundID _: Int,
        departmentID _: Int,
        classID _: Int,
        currentLocation: CLLocation? = nil,
        lastPurchase: StatusBarPurchase? = nil,
        recentlyViewed: RecentlyViewedItem? = nil,
        onSmartMealPlan: @escaping (StatusBarCourse) -> Void = { _ in },
        onOpenLastPurchase: @escaping (StatusBarPurchase) -> Void = { _ in },
        onOpenRecentlyViewed: @escaping (RecentlyViewedItem) -> Void = { _ in }
    ) {
        self.currentLocation = currentLocation
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
                        if let routeAssessment {
                            routeAssessmentCapsule(routeAssessment)
                        } else if isCalculatingRoute {
                            Label("正在计算去教室的时间", systemImage: "figure.walk")
                                .fixedSize(horizontal: true, vertical: false)
                                .statusBarCapsuleStyle()
                        }

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
                    } else if courseStore.isLoading {
                        Label("正在读取下一节课", systemImage: "clock")
                            .fixedSize(horizontal: true, vertical: false)
                            .statusBarCapsuleStyle()
                    } else if let errorMessage = courseStore.errorMessage {
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
            guard courseStore.events.isEmpty,
                  !courseStore.isLoading else {
                resolveNextCourse(after: Date())
                return
            }
            
            await loadCourseTable()
        }
        .task(id: routeRequestID) {
            await updateRouteAssessment()
        }
        .onChange(of: courseStore.events) { _, _ in
            resolveNextCourse(after: Date())
        }
    }
    // MARK: 加载与解析
    
    @MainActor
    private func loadCourseTable() async {
        await courseStore.load(forceRefresh: courseStore.errorMessage != nil)
        resolveNextCourse(after: Date())
    }
    
    @MainActor
    private func resolveNextCourse(
        after now: Date
    ) {
        guard !courseStore.events.isEmpty else {
            nextCourse = nil
            
            if !courseStore.isLoading,
               courseStore.errorMessage == nil {
                courseParseMessage = "服务器没有返回课程表"
            }
            return
        }
        
        nextCourse = CourseScheduleResolver.nextEvent(
            after: now,
            from: courseStore.events
        ).flatMap { event in
            guard let startTime = event.startDate else { return nil }
            return StatusBarCourse(
                id: event.id,
                courseName: event.title,
                startTime: startTime,
                location: event.location ?? ""
            )
        }
        
        if nextCourse == nil {
            courseParseMessage = "课程表已加载，但当前没有后续课程"
        } else {
            courseParseMessage = nil
        }
        
    }

    // MARK: 路线与出发建议

    /// 先用课程表的地点文本在当前位置附近查找，再计算步行路线。
    /// 这是确定性的地图功能，不需要调用大模型。
    @MainActor
    private func updateRouteAssessment() async {
        routeAssessment = nil

        guard let course = nextCourse,
              let currentLocation,
              !course.location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            isCalculatingRoute = false
            return
        }

        isCalculatingRoute = true
        defer { isCalculatingRoute = false }

        do {
            let searchRequest = MKLocalSearch.Request()
            searchRequest.naturalLanguageQuery = course.location
            searchRequest.region = MKCoordinateRegion(
                center: currentLocation.coordinate,
                latitudinalMeters: 8_000,
                longitudinalMeters: 8_000
            )

            let searchResponse = try await MKLocalSearch(request: searchRequest).start()
            try Task.checkCancellation()

            guard let destination = searchResponse.mapItems.first else { return }

            let directionsRequest = MKDirections.Request()
            directionsRequest.source = MKMapItem(
                placemark: MKPlacemark(coordinate: currentLocation.coordinate)
            )
            directionsRequest.destination = destination
            directionsRequest.transportType = .walking

            let directionsResponse = try await MKDirections(request: directionsRequest).calculate()
            try Task.checkCancellation()

            guard let route = directionsResponse.routes.first else { return }

            let safetyBuffer: TimeInterval = 5 * 60
            let suggestedDeparture = course.startTime
                .addingTimeInterval(-(route.expectedTravelTime + safetyBuffer))
            let margin = suggestedDeparture.timeIntervalSinceNow
            let urgency: RouteAssessment.Urgency

            if margin < 0 {
                urgency = .late
            } else if margin <= 10 * 60 {
                urgency = .leaveSoon
            } else {
                urgency = .comfortable
            }

            routeAssessment = RouteAssessment(
                walkingTime: route.expectedTravelTime,
                suggestedDeparture: suggestedDeparture,
                urgency: urgency
            )
        } catch is CancellationError {
            // 位置或下一节课变化时，忽略旧路线计算。
        } catch {
            // 地点无法识别时仍保留课程和地点标签，不把它误报为课表故障。
        }
    }

    private func routeAssessmentCapsule(
        _ assessment: RouteAssessment
    ) -> some View {
        let walkingMinutes = max(Int(ceil(assessment.walkingTime / 60)), 1)
        let text: String

        switch assessment.urgency {
        case .comfortable:
            text = "\(departureTimeText(assessment.suggestedDeparture)) 出发·步行约 \(walkingMinutes) 分钟"
        case .leaveSoon:
            text = "建议尽快出发·步行约 \(walkingMinutes) 分钟"
        case .late:
            text = "可能迟到·步行约 \(walkingMinutes) 分钟"
        }

        return Label(text, systemImage: assessment.urgency.icon)
            .fixedSize(horizontal: true, vertical: false)
            .font(.system(size: 12))
            .statusBarCapsuleStyle(tint: assessment.urgency.color)
    }

    private func departureTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
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
        isHighlighted: Bool = false,
        tint: Color? = nil
    ) -> some View {
        self
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint ?? (isHighlighted ? Color.accentColor : Color.primary))
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
