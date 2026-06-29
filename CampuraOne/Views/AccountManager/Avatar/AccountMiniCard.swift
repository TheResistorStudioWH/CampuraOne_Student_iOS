//
//  AccountMiniCard.swift
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

struct AccountMiniCard: View {
    @Environment(\.colorScheme) var colorScheme
    let userProfile: AppUser?
    @Binding var showSheet: Bool
    @Binding var showName: Bool
    
    private var currentUser: AppUser? {
        userProfile
    }
    
    private var isLogIn: Bool {
        currentUser != nil
    }
    
    var body: some View {
        VStack {
            if isLogIn {
                LoggedIn()
            } else {
                notLogIn()
            }
        }
        .padding(.leading, 2)
        .padding(6)
        .background {
            if showName {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Material.bar)
            }
        }
        .beButton {
            showSheet = true
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(.colorScheme(light: 0.21, dark: 0.45, colorScheme)), radius: 6, x: 1, y: 1)
    }
    
    @ViewBuilder func notLogIn() -> some View {
        HStack {
            Text("未登录")
            
            Image(systemName: "person.crop.square.fill")
                .font(.system(size: 23))
        }
        .foregroundStyle(.secondary)
    }
    
    @ViewBuilder func LoggedIn() -> some View {
        //每次打开app时都会更新学生数据,更新时头像旋转
        if let currentUser {
            HStack {
                Text(currentUser.userName)
                    .offset(x: showName ? 0 : 40, y: 0)
                    .opacity(showName ? 1 : 0)
                UserAvatarView(user: currentUser, size: showName ? 26 : 35)
            }
            .foregroundStyle(.primary)
        }
    }
}


struct UserAvatarView: View {
    let user: AppUser?
    var size: CGFloat = 26
    
    private var cacheKey: String? {
        guard let user else {
            return nil
        }
        return "userAvatar-\(user.userID)"
    }
    
    private var displayAvatarURL: URL? {
        user?.avatarURL
    }
    
    init(user: AppUser?, size: CGFloat = 26) {
        self.user = user
        self.size = size
    }
    
    var body: some View {
        RemoteImageView(
            url: displayAvatarURL,
            cacheKey: cacheKey,
            contentMode: .fill,
            cornerRadius: size * 0.25
        ) {
            placeholder
        }
        .frame(width: size, height: size)
    }
    
    private var placeholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(.secondary.opacity(0.15))
            
            Image(systemName: "person.crop.square.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .padding(size * 0.12)
        }
    }
}
