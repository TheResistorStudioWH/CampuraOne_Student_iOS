//
//  ICSCalendar_TimeLine.swift
//  CampuraOne
//
//  Created by Lin Shay on 09/06/2026.
//

import SwiftUI
import SwiftData

#Preview("app - 已登录") {
    ContentView()
        .modelContainer(PreviewContainer.app)
}

struct ICSCalendar_TimeLine: View {
    @StateObject private var viewModel = LoadableListViewModel<ICSEventItem>(loader: {
        try await CourseTableRemoteService.shared.fetchCourseTableEvents(userID: 5)
    })
    var minimumTimelineHeight: CGFloat = 0
    var displayDate: Date? = nil
    
    private var events: [ICSEventItem] {
        viewModel.items
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
                VStack(alignment: .leading, spacing: 4) {
                    Label("课表加载失败", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if events.isEmpty {
                ContentUnavailableView(
                    "暂无课程",
                    systemImage: "calendar.badge.exclamationmark"
                )
                .font(.caption)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                CalendarTimeLineView(
                    events: events,
                    minimumTimelineHeight: minimumTimelineHeight,
                    displayDate: displayDate
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await viewModel.load()
        }
    }
}

private final class CourseTableRemoteService {
    static let shared = CourseTableRemoteService()
    
    private init() {}
    
    func fetchCourseTableEvents(userID: Int) async throws -> [ICSEventItem] {
        let user = try await RemoteDataService.shared.fetchUserProfile(userID: userID)
        
        guard let studentID = user.studentID else {
            return []
        }
        
        let student = try await RemoteDataService.shared.fetchStudentProfile(studentID: studentID)
        
        let icsText = try await RemoteDataService.shared.fetchCourseTableICS(
            schoolID: student.schoolID,
            compoundID: student.compoundID,
            departmentID: student.departmentID,
            classID: student.classID
        )
        
        return SimpleICSParser.parseEvents(from: icsText)
            .sorted { lhs, rhs in
                (lhs.startDate ?? .distantFuture) < (rhs.startDate ?? .distantFuture)
            }
    }
}

private struct CalendarTimeLineView: View {
    let events: [ICSEventItem]
    var minimumTimelineHeight: CGFloat = 0
    var displayDate: Date? = nil
    
    private let calendar = Calendar.current
    private let dayStartHour = 8
    private let dayEndHour = 20
    private let preferredHourHeight: CGFloat = 30
    private let minimumVisibleHourCount = 4
    
    private var resolvedDisplayDate: Date {
        displayDate ?? Date()
    }
    
    private var displayEvents: [ICSEventItem] {
        events
            .filter { event in
                guard let startDate = event.startDate else {
                    return false
                }
                
                return calendar.isDate(startDate, inSameDayAs: resolvedDisplayDate)
            }
            .sorted { lhs, rhs in
                (lhs.startDate ?? .distantFuture) < (rhs.startDate ?? .distantFuture)
            }
            .prefix(8)
            .map { $0 }
    }
    
    var body: some View {
        GeometryReader { proxy in
            let availableWidth = max(proxy.size.width, 1)
            let availableHeight = proxy.size.height.isFinite ? proxy.size.height : 180
            let timelineHeight = max(availableHeight, minimumTimelineHeight, 120)
            let totalHourCount = dayEndHour - dayStartHour
            let visibleHourCount = visibleHourCount(for: timelineHeight, totalHourCount: totalHourCount)
            let visibleStartHour = visibleStartHour(visibleHourCount: visibleHourCount)
            let visibleEndHour = visibleStartHour + visibleHourCount
            let hourHeight = timelineHeight / CGFloat(visibleHourCount)
            let timeColumnWidth = min(max(availableWidth * 0.12, 30), 46)
            let eventWidth = max(availableWidth - timeColumnWidth - 10, 80)
            
            ZStack(alignment: .topLeading) {
                hourLines(
                    visibleStartHour: visibleStartHour,
                    visibleEndHour: visibleEndHour,
                    hourHeight: hourHeight,
                    timeColumnWidth: timeColumnWidth
                )
                
                eventBlocks(
                    visibleStartHour: visibleStartHour,
                    visibleEndHour: visibleEndHour,
                    hourHeight: hourHeight,
                    timeColumnWidth: timeColumnWidth,
                    eventWidth: eventWidth
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func visibleHourCount(for timelineHeight: CGFloat, totalHourCount: Int) -> Int {
        let rawCount = Int((timelineHeight / preferredHourHeight).rounded(.down))
        return min(
            totalHourCount,
            max(minimumVisibleHourCount, rawCount)
        )
    }
    
    private func visibleStartHour(visibleHourCount: Int) -> Int {
        let firstEventHour = displayEvents
            .compactMap { event -> Int? in
                guard let startDate = event.startDate else {
                    return nil
                }
                return calendar.component(.hour, from: startDate)
            }
            .first ?? dayStartHour
        
        let latestStartHour = max(dayStartHour, dayEndHour - visibleHourCount)
        return min(
            max(firstEventHour, dayStartHour),
            latestStartHour
        )
    }
    
    private func eventOverlapsVisibleHours(
        _ event: ICSEventItem,
        visibleStartHour: Int,
        visibleEndHour: Int
    ) -> Bool {
        guard let startDate = event.startDate else {
            return false
        }
        
        let endDate = event.endDate ?? startDate.addingTimeInterval(60 * 60)
        let visibleStart = calendar.date(bySettingHour: visibleStartHour, minute: 0, second: 0, of: resolvedDisplayDate) ?? startDate
        let visibleEnd = calendar.date(bySettingHour: visibleEndHour, minute: 0, second: 0, of: resolvedDisplayDate) ?? startDate
        
        return startDate < visibleEnd && endDate > visibleStart
    }
    
    private func hourLines(
        visibleStartHour: Int,
        visibleEndHour: Int,
        hourHeight: CGFloat,
        timeColumnWidth: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(visibleStartHour...visibleEndHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: 8) {
                    Text(String(format: "%02d:00", hour))
                        .font(.system(size: max(9, min(11, hourHeight * 0.3)), weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(width: timeColumnWidth, alignment: .trailing)
                        .offset(y: -6)
                    
                    Rectangle()
                        .fill(.secondary.opacity(0.25))
                        .frame(height: 1)
                }
                .frame(height: hour == visibleEndHour ? 1 : hourHeight, alignment: .top)
            }
        }
    }
    
    private func eventBlocks(
        visibleStartHour: Int,
        visibleEndHour: Int,
        hourHeight: CGFloat,
        timeColumnWidth: CGFloat,
        eventWidth: CGFloat
    ) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(displayEvents.filter { eventOverlapsVisibleHours($0, visibleStartHour: visibleStartHour, visibleEndHour: visibleEndHour) }) { event in
                if let startDate = event.startDate {
                    CalendarTimeLineEventBlock(event: event)
                        .frame(
                            width: eventWidth,
                            height: eventHeight(event, visibleStartHour: visibleStartHour, visibleEndHour: visibleEndHour, hourHeight: hourHeight)
                        )
                        .padding(.leading, timeColumnWidth + 10)
                        .offset(y: yOffset(for: startDate, visibleStartHour: visibleStartHour, visibleEndHour: visibleEndHour, hourHeight: hourHeight))
                }
            }
        }
    }
    
    private func yOffset(
        for date: Date,
        visibleStartHour: Int,
        visibleEndHour: Int,
        hourHeight: CGFloat
    ) -> CGFloat {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? visibleStartHour
        let minute = components.minute ?? 0
        let decimalHour = CGFloat(hour) + CGFloat(minute) / 60.0
        let clampedHour = min(
            max(decimalHour, CGFloat(visibleStartHour)),
            CGFloat(visibleEndHour)
        )
        return (clampedHour - CGFloat(visibleStartHour)) * hourHeight
    }
    
    private func eventHeight(
        _ event: ICSEventItem,
        visibleStartHour: Int,
        visibleEndHour: Int,
        hourHeight: CGFloat
    ) -> CGFloat {
        guard let startDate = event.startDate else {
            return hourHeight * 0.9
        }
        
        let endDate = event.endDate ?? startDate.addingTimeInterval(60 * 60)
        let visibleStart = calendar.date(bySettingHour: visibleStartHour, minute: 0, second: 0, of: resolvedDisplayDate) ?? startDate
        let visibleEnd = calendar.date(bySettingHour: visibleEndHour, minute: 0, second: 0, of: resolvedDisplayDate) ?? endDate
        let clippedStart = max(startDate, visibleStart)
        let clippedEnd = min(endDate, visibleEnd)
        let duration = max(clippedEnd.timeIntervalSince(clippedStart), 20 * 60)
        let hours = CGFloat(duration / 3600)
        return max(hourHeight * 0.55, hours * hourHeight)
    }
}

private struct CalendarTimeLineEventBlock: View {
    let event: ICSEventItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(event.accentColor)
                .frame(width: 3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .lineLimit(1)
                
                // 时间显示预留：之后你可以在这里设计第几节 / 星期几 / 开始时间等。
                EmptyView()
                
                // 地点显示预留：之后你可以在这里设计教室 / 校区 / 楼栋等。
                EmptyView()
            }
            
            Spacer(minLength: 0)
            
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 9, weight: .semibold))
                .opacity(0.65)
        }
        .foregroundStyle(event.accentColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(event.accentColor.opacity(0.2))
        }
    }
}

private extension ICSEventItem {
    var accentColor: Color {
        let colors: [Color] = [.blue, .green, .purple, .orange, .pink]
        let index = abs(title.hashValue) % colors.count
        return colors[index]
    }
}

#Preview("课程表迷你日历 - 服务器") {
    ICSCalendar_TimeLine()
        .frame(width: 360, height: 180)
        .padding()
}

#Preview("课程表迷你日历 - 本地数据") {
    CalendarTimeLineView(
        events: [
            ICSEventItem(
                title: "大学英语 2",
                startDate: Calendar.current.date(bySettingHour: 8, minute: 20, second: 0, of: Date()),
                endDate: Calendar.current.date(bySettingHour: 10, minute: 5, second: 0, of: Date()),
                location: "2504 教室",
                detail: ""
            ),
            ICSEventItem(
                title: "大学生心理健康教育",
                startDate: Calendar.current.date(bySettingHour: 13, minute: 50, second: 0, of: Date()),
                endDate: Calendar.current.date(bySettingHour: 15, minute: 35, second: 0, of: Date()),
                location: "2205 教室",
                detail: ""
            ),
            ICSEventItem(
                title: "体育与健康 2",
                startDate: Calendar.current.date(bySettingHour: 15, minute: 50, second: 0, of: Date()),
                endDate: Calendar.current.date(bySettingHour: 17, minute: 30, second: 0, of: Date()),
                location: "田径场",
                detail: ""
            )
        ],
        displayDate: Date()
    )
    .frame(width: 360, height: 180)
    .padding()
}
