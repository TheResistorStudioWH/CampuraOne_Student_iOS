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
                userName: "演示",
                token: "preview.local.only",
                shopIDs: [],
                studentID: 20260001
            )
            
            let demoStudent = Student(
                studentID: 20260001,
                studentName: "演示",
                gender: "男",
                schoolID: 1,
                compoundID: 1,
                departmentID: 2,
                classID: 3
            )
            
            context.insert(demoUser)
            context.insert(demoStudent)
            try context.save()
            
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

/// 所有整页预览共用的内存账户；不会读取或修改设备上真实的登录记录。
struct PreviewAppView: View {
    @StateObject private var session = AuthSession()
    @State private var container: ModelContainer

    init(signedIn: Bool = true) {
        _container = State(initialValue: signedIn ? PreviewContainer.app : PreviewContainer.empty)
    }

    var body: some View {
        AppRootView()
            .environmentObject(session)
            .modelContainer(container)
            .environment(\.scenePhase, .active)
    }
}
