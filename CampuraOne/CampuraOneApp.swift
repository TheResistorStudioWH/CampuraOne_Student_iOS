//
//  CampuraOneApp.swift
//  CampuraOne
//
//  Created by LShayc1own on 18/05/2026.
//

import SwiftUI
import SwiftData

@main
struct CampuraOneApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(for: [
                            School.self,
                            Campus.self,
                            SchoolCalendar.self,
                            CourseTable.self,
                            AppUser.self,
                            Student.self
                        ])
        }
    }
}
