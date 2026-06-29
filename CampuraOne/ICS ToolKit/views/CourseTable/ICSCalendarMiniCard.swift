//
//  ICSCalendarMiniCard.swift
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


struct ICSCalendar_TimeLineStyle: View {
    @StateObject private var viewModel = LoadableListViewModel<ICSEventItem>(loader: {
        let user = try await RemoteDataService.shared.fetchUserProfile(userID: 1)
        
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
                (lhs.startDate ?? .distantFuture) < (rhs.startDate ?? .distantFuture)
            }
    })
    
    private var events: [ICSEventItem] {
        viewModel.items
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 180)
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
                .frame(maxWidth: .infinity, minHeight: 180)
            } else {
                CalendarMiniTimeline(events: events)
            }
        }
        .task {
            await viewModel.load()
        }
    }
}

private struct CalendarMiniTimeline: View {
    let events: [ICSEventItem]
    
    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 30
    private let timeColumnWidth: CGFloat = 38
    private let startHour = 8
    private let endHour = 20
    
    private var displayEvents: [ICSEventItem] {
        events
            .filter { $0.startDate != nil }
            .prefix(8)
            .map { $0 }
    }
    
    private var displayDate: Date {
        displayEvents.first?.startDate ?? Date()
    }
    
    private var timelineHeight: CGFloat {
        CGFloat(endHour - startHour) * hourHeight
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            
            ZStack(alignment: .topLeading) {
                hourLines
                eventBlocks
            }
            .frame(height: timelineHeight)
            .clipped()
        }
    }
    
    private var header: some View {
        HStack(spacing: 8) {
            Text("今天")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 5) {
                Circle()
                    .strokeBorder(.primary, lineWidth: 1.5)
                    .frame(width: 14, height: 14)
                
                Text(displayDate.weekdayText)
                    .font(.caption)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
            }
        }
    }
    
    private var hourLines: some View {
        VStack(spacing: 0) {
            ForEach(startHour...endHour, id: \.self) { hour in
                HStack(alignment: .top, spacing: 8) {
                    Text(String(format: "%02d:00", hour))
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                        .frame(width: timeColumnWidth, alignment: .trailing)
                        .offset(y: -6)
                    
                    Rectangle()
                        .fill(.secondary.opacity(0.25))
                        .frame(height: 1)
                }
                .frame(height: hour == endHour ? 1 : hourHeight, alignment: .top)
            }
        }
    }
    
    private var eventBlocks: some View {
        ZStack(alignment: .topLeading) {
            ForEach(displayEvents) { event in
                if let startDate = event.startDate {
                    CalendarTimeline_MiniEventBlock(event: event)
                        .frame(
                            width: nil,
                            height: eventHeight(event)
                        )
                        .padding(.leading, timeColumnWidth + 10)
                        .offset(y: yOffset(for: startDate))
                }
            }
        }
    }
    
    private func yOffset(for date: Date) -> CGFloat {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? startHour
        let minute = components.minute ?? 0
        let decimalHour = CGFloat(hour) + CGFloat(minute) / 60.0
        let clampedHour = min(max(decimalHour, CGFloat(startHour)), CGFloat(endHour))
        return (clampedHour - CGFloat(startHour)) * hourHeight
    }
    
    private func eventHeight(_ event: ICSEventItem) -> CGFloat {
        guard let startDate = event.startDate, let endDate = event.endDate else {
            return hourHeight * 0.9
        }
        
        let duration = max(endDate.timeIntervalSince(startDate), 30 * 60)
        let hours = CGFloat(duration / 3600)
        return max(38, hours * hourHeight)
    }
}

private struct CalendarTimeline_MiniEventBlock: View {
    let event: ICSEventItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(event.accentColor)
                .frame(width: 3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
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

private extension Date {
    var weekdayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEE"
        return formatter.string(from: self)
    }
}

#Preview("课程表迷你日历 - 服务器") {
    ICSCalendar_TimeLineStyle()
        .padding()
}

#Preview("课程表迷你日历 - 本地数据") {
    CalendarMiniTimeline(
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
        ]
    )
    .padding()
}
