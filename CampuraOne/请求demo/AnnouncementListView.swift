//
//  AnnouncementListView.swift
//  CampuraOne
//
//  Created by Lin Shay on 03/06/2026.
//

import SwiftUI
import Combine
import MarkdownUI

#Preview("AnnouncementListView") {
    AnnouncementListView()
}

struct AnnouncementListView: View {
    
    /// 示例：当前登录学生的信息。
    /// 之后接入登录系统后，这些值可以从当前学生资料里读取。
    private let currentSchoolID = 1
    private let currentAreaID = 1
    private let currentDepartmentID = 1
    private let currentClassID = 1
    private let currentStudentID = 1
    
    @StateObject private var vm = LoadableListViewModel<AnnouncementItem> {
        try await RemoteDataService.shared.fetchVisibleAnnouncements(
            schoolID: 1,
            areaID: 1,
            departmentID: 1,
            classID: 1,
            studentID: 2
        )
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView("正在加载通知...")
                } else if let errorMessage = vm.errorMessage {
                    VStack(spacing: 12) {
                        Text("加载失败")
                            .font(.headline)
                        
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        
                        Button("重新加载") {
                            Task {
                                await vm.load()
                            }
                        }
                    }
                    .padding()
                } else {
                    List {
                        Section {
                            CurrentStudentTargetDemoView(
                                schoolID: currentSchoolID,
                                areaID: currentAreaID,
                                departmentID: currentDepartmentID,
                                classID: currentClassID,
                                studentID: currentStudentID
                            )
                        }
                        
                        Section("当前学生可见通知") {
                            ForEach(vm.items) { item in
                                AnnouncementRowView(item: item)
                            }
                        }
                    }
                }
            }
            .navigationTitle("学校通知")
            .task {
                await vm.load()
            }
        }
    }
}

private struct CurrentStudentTargetDemoView: View {
    let schoolID: Int
    let areaID: Int
    let departmentID: Int
    let classID: Int
    let studentID: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("当前学生筛选示例", systemImage: "person.crop.circle.badge.checkmark")
                .font(.headline)
            
            Text("页面没有直接调用 fetchAnnouncements，而是调用 fetchVisibleAnnouncements。")
                .font(.footnote)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 4) {
                targetLine(title: "schoolID", value: schoolID)
                targetLine(title: "areaID", value: areaID)
                targetLine(title: "departmentID", value: departmentID)
                targetLine(title: "classID", value: classID)
                targetLine(title: "studentID", value: studentID)
            }
            .font(.caption)
        }
        .padding(.vertical, 4)
    }
    
    private func targetLine(title: String, value: Int) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            
            Text("\(value)")
                .fontWeight(.semibold)
        }
    }
}

private struct AnnouncementRowView: View {
    let item: AnnouncementItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(item.typeTitle, systemImage: item.systemImage)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            announcementContent
            
            if let endTime = item.endTime {
                Text("截止：\(endTime.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            AnnouncementTargetDebugView(target: item.target)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var announcementContent: some View {
        if item.isMarkdown {
            Markdown(item.content)
                .markdownTextStyle {
                    FontSize(.em(1.0))
                }
        } else {
            Text(item.content)
                .font(.body)
        }
    }
}

private struct AnnouncementTargetDebugView: View {
    let target: AnnouncementTarget?
    
    var body: some View {
        if let target {
            VStack(alignment: .leading, spacing: 3) {
                Text("target 调试信息")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                if target.allSchool {
                    targetBadge("全校可见")
                } else {
                    if !target.areaIDs.isEmpty {
                        targetBadge("校区：\(target.areaIDs.map(String.init).joined(separator: ", "))")
                    }
                    
                    if !target.departmentIDs.isEmpty {
                        targetBadge("院系：\(target.departmentIDs.map(String.init).joined(separator: ", "))")
                    }
                    
                    if !target.classIDs.isEmpty {
                        targetBadge("班级：\(target.classIDs.map(String.init).joined(separator: ", "))")
                    }
                    
                    if !target.studentIDs.isEmpty {
                        targetBadge("学生：\(target.studentIDs.map(String.init).joined(separator: ", "))")
                    }
                }
            }
            .padding(.top, 4)
        } else {
            Text("target: nil，旧数据默认可见")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    private func targetBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary, in: Capsule())
    }
}
