//
//  AccountSheet.swift
//  CampuraOne
//
//  Created by Lin Shay on 10/06/2026.
//

import SwiftUI
import SwiftData
import PetaKitUIX

#Preview("app - 已登录") {
    PreviewAppView()
}

#Preview("app - 未登录") {
    PreviewAppView(signedIn: false)
}

struct AccountSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authSession: AuthSession
    @Query private var savedUsers: [AppUser]

    var body: some View {
        NavigationStack {
            Form {
                if let user = authSession.currentUser {
                    Section("当前账号") {
                        LabeledContent("用户名", value: user.userName)
                    }
                    NavigationHistorySection(userID: user.userID)

                    Section("AI") {
                        Label("AI 模型", systemImage: "sparkles")
                            .naviLink(to: AIModelSettingsView(userID: user.userID))
                    }
                }

                Section {
                    Button("退出登录", role: .destructive) {
                        authSession.signOut(
                            savedUsers: savedUsers,
                            modelContext: modelContext
                        )
                        dismiss()
                    }
                }
            }
            .navigationTitle("账号")
        }
    }
}
