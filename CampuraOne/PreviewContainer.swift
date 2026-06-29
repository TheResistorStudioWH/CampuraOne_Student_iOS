//
//  PreviewContainer.swift
//  CampuraOne
//
//  Created by LShayc1own on 25/05/2026.
//

import SwiftUI
import SwiftData

@MainActor
enum PreviewContainer {
    
    /// 适用于整个 App 的 Preview 数据
    static var app: ModelContainer {
        let schema = Schema([
            AppUser.self,
            Student.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            
            let context = container.mainContext
            
            let demoUser = AppUser(
                userID: 1,
                userName: "琳曦",
                userImg: "https://picsum.photos/200",
                passwordHash: "123456",
                shopIDs: [1001, 1002],
                studentID: 20260001
            )
            
            let demoStudent = Student(
                studentID: 20260001,
                studentName: "陵长镜",
                gender: "男",
                schoolID: 1,
                compoundID: 1,
                departmentID: 2,
                classID: 3
            )
            
            context.insert(demoUser)
            context.insert(demoStudent)
            
            return container
        } catch {
            fatalError("创建 App PreviewContainer 失败: \(error)")
        }
    }
    
    /// 空数据，适用于未登录状态
    static var empty: ModelContainer {
        let schema = Schema([
            AppUser.self,
            Student.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        do {
            return try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
        } catch {
            fatalError("创建 Empty PreviewContainer 失败: \(error)")
        }
    }
}
