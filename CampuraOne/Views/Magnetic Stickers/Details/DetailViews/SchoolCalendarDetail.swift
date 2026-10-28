//
//  SchoolCalendarDetail.swift
//  CampuraOne
//
//  Created by Lin Shay on 09/06/2026.
//

import SwiftUI
import SwiftData

struct SchoolCalendarDetail: DashboardDetailContent {
    static let tileDescriptor = DashboardTileDescriptor(
        id: "schoolCalendar", title: "校历", systemImage: "calendar"
    )

    var body: some View {
        ICSSchoolCalendar()
    }
}
