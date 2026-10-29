//
//  CourseTable.swift
//  CampuraOne
//
//  Created by LShayc1own on 25/05/2026.
//

import SwiftUI
import PetaToolKit
import SwiftData

#Preview("app - 已登录") {
    PreviewAppView()
}

#Preview("app - 未登录") {
    PreviewAppView(signedIn: false)
}

struct CourseTableTile: View {
    let context: DashboardTileContext
    @State private var selectedDay: CourseTileDay = .today

    var body: some View {
        DashboardTile(
            descriptor: CourseTableDetail.tileDescriptor,
            context: context,
            onOpen: { context.open(CourseTableDetail()) }
        ) {
            ICSCalendar_TimeLine(minimumTimelineHeight: 0, displayDate: selectedDay.date)
        } toolBar: {
            HStack(spacing: 6) {
                dayPicker
            }
        }
    }

    private var dayPicker: some View {
        HStack(spacing: 2) {
            ForEach(CourseTileDay.allCases) { day in
                Text(day.title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(selectedDay == day ? .primary : .secondary)
                    .frame(width: 22, height: 22)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedDay == day ? Material.regular : Material.ultraThin)
                    }
                    .onTapGesture {
                        selectedDay = day
                        TapSoft()
                    }
                    .animation(.smooth, value: selectedDay)
            }
        }
    }
}

private enum CourseTileDay: String, CaseIterable, Identifiable {
    case today, tomorrow

    var id: Self { self }
    var title: String { self == .today ? "今" : "明" }

    var date: Date {
        switch self {
        case .today:
            Date()
        case .tomorrow:
            Calendar.current.date(byAdding: .day, value: 1, to: Date())
                ?? Date().addingTimeInterval(24 * 60 * 60)
        }
    }
}
