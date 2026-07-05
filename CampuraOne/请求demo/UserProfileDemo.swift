//
//  UserProfileDemo.swift
//  CampuraOne
//
//  Created by Lin Shay on 06/06/2026.
//

import SwiftUI

struct UserProfileDemo: View {
    @State private var user: AppUser?
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            List {
                Section("测试操作") {
                    Button {
                        Task {
                            await loadUserProfile()
                        }
                    } label: {
                        Label("加载 userID = 1 的用户信息", systemImage: "person.crop.circle.badge.checkmark")
                    }
                    .disabled(isLoading)
                    
                    if isLoading {
                        ProgressView("正在加载用户信息...")
                    }
                }
                
                if let errorMessage {
                    Section("错误") {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
                
                Section("用户信息") {
                    if let user {
                        UserProfileRow(title: "用户 ID", value: String(user.userID))
                        UserProfileRow(title: "用户名", value: user.userName)
                        UserProfileRow(title: "头像链接", value: user.userImg ?? "无")
                        UserProfileRow(title: "管理商户", value: user.shopIDs.isEmpty ? "无" : user.shopIDs.map(String.init).joined(separator: ", "))
                        UserProfileRow(title: "绑定学生", value: user.studentID.map(String.init) ?? "无")
                        UserProfileRow(title: "创建时间", value: formatDate(user.createdAt))
                        UserProfileRow(title: "更新时间", value: formatDate(user.updatedAt))
                    } else {
                        ContentUnavailableView(
                            "暂无用户信息",
                            systemImage: "person.crop.circle",
                            description: Text("点击上方按钮，从服务器加载 userID = 1 的用户信息。")
                        )
                    }
                }
            }
            .navigationTitle("用户信息 Demo")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("清空") {
                        user = nil
                        errorMessage = nil
                    }
                }
            }
        }
    }
    
    @MainActor
    private func loadUserProfile() async {
        isLoading = true
        errorMessage = nil
        
        do {
            user = try await RemoteDataService.shared.fetchUserProfile(userID: 1)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func formatDate(_ date: Date?) -> String {
        guard let date else {
            return "无"
        }
        
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct UserProfileRow: View {
    let title: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.body)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}

#Preview("UserProfileDemo") {
    UserProfileDemo()
}
