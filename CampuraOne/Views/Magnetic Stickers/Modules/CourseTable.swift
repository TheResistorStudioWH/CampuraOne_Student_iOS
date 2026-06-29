//
//  CourseTable.swift
//  CampuraOne
//
//  Created by LShayc1own on 25/05/2026.
//

import SwiftUI
import SwiftData

#Preview("app - 已登录") {
    ContentView()
        .modelContainer(PreviewContainer.app)
}

#Preview("app - 未登录") {
    ContentView()
        .modelContainer(PreviewContainer.empty)
}

struct CourseTableModule: View {
    var body: some View {
        ICSCalendar_TimeLineStyle()
    }
}
