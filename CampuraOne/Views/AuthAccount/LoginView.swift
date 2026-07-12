//
//  LoginView.swift
//  CampuraOne
//
//  Generated login migration version
//

import SwiftUI
import SwiftData
import Combine

#Preview("app - 已登录") {
    ContentView()
        .modelContainer(PreviewContainer.app)
}

#Preview("login") {
    LoginView()
}

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AppUser.updatedAt, order: .reverse) private var savedUsers: [AppUser]

    @State private var startLogin = false
    @State private var symbolStep = 0

    private let services: [ServiceItem] = [
        .init(name: "校园信息全平台一览", description: "学生账号与密码由校方统一下发"),
        .init(name: "时效性信息通知及时丰富", description: "课程表、校历等信息与校园信息同步，通知及时，减少出勤压力。"),
        .init(name: "校内通知分类摘要、即时通知", description: "信息一览无余，减少繁琐查询步骤。"),
        .init(name: "根据课表智能规划时间与路线", description: "课程规划信息与地图数据整合，降低时间规划成本，助于安心学习。"),
        .init(name: "搜索与消费便捷且个性化", description: "校园消费一站式服务，集成校园内商家的信息及线上下销售渠道。支持促销信息、价格对比、个性化智能搜索、个性化定制商品与商户标记、校内活动实时更新等功能，轻松查看各种消费级信息。")
    ]
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 28) {
                headerView
                serviceCard
            
                animatedSymbolCard
                
                
                openLoginButton
            }
            .padding(20)
        }
        
        .task {
            startSymbolLoop()
            if let existing = savedUsers.first, let token = existing.token, !token.isEmpty {
                RemoteDataService.shared.bindUser(existing)
            }
        }
    }

    private var headerView: some View {
        VStack(alignment:.leading) {
            Text("登录后，")
            Text("您将可享受以下服务：")
            
        }
        .font(screen.width > 390 ? .largeTitle : screen.width > 380 ? .title : .system(size: 26))
        .bold()
    }

    private var serviceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(services) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("·")
                        Text(item.name)
                    }
                    .bold()
                    if let description = item.description {
                        HStack(alignment: .top, spacing: 8) {
                            Text("·")
                                .opacity(0)
                            Text(description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var animatedSymbolCard: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Image(systemName: symbolName)
                    .font(.system(size: 100, weight: .regular))
                    .contentTransition(.symbolEffect(.replace))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.blue)
                    .animation(.smooth(duration: 0.55), value: symbolStep)
                Spacer()
            }
            Spacer()
        }
        
    }

    private var openLoginButton: some View {
        HStack {
            Spacer()
            Image(systemName: "person.crop.circle.badge.checkmark")
            Text("使用学生账号登录到 Campura One / 域校屿")
                .font(.headline)
            Spacer()
        }
        .jumpView(to:
            StudentLoginSheet {
                dismiss()
            }
        )
        .buttonStyle(.borderedProminent)
        .tint(.accentColor)
    }

    private var symbolName: String {
        switch symbolStep {
        case 0: return "graduationcap.fill"
        case 1: return "person.badge.key.fill"
        case 2: return "qrcode.viewfinder"
        default: return "sparkles"
        }
    }

    private func startSymbolLoop() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.2))
                await MainActor.run {
                    withAnimation(.smooth) {
                        symbolStep = (symbolStep + 1) % 4
                    }
                }
            }
        }
    }
}

// MARK: - 学生登录弹窗

#Preview("StudentLoginSheet") {
    StudentLoginSheet {}
}

private struct StudentLoginSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AppUser.updatedAt, order: .reverse) private var savedUsers: [AppUser]

    @State private var loginMethod: LoginMethod = .accountPassword
    @State private var account = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var confirmedUser: AppUser?
    @State private var confirmedStudent: Student?
    
    @Namespace var selectorBg
    
    @State var showIn = false
    @State var showMid = false
    @State var showEx = false
    
    let onFinish: () -> Void
    
    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack {
                    topIconSection
                    
                    methodSelector
                    
                    switch loginMethod {
                        case .accountPassword:
                            accountPasswordSection
                        case .qrCode:
                            QRLoginPlaceholderView()
                    }
                    
                    noticeSection
                    
                    if let user = confirmedUser {
                        StudentLoginConfirmView(user: user, student: confirmedStudent) {
                            dismiss()
                            onFinish()
                        }
                    }
                }
                .padding(20)
            }
            
            if isLoading {
                ZStack {
                    Color.black.opacity(0.12).ignoresSafeArea()
                    ProgressView("正在登录…")
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(.regularMaterial)
                        )
                }
            }
        }
        .alert("登录失败", isPresented: .constant(errorMessage != nil), actions: {
            Button("好的") { errorMessage = nil }
        }, message: {
            Text(errorMessage ?? "")
        })
        
    }
    
    private var topIconSection: some View {
        VStack(alignment: .leading) {
            ZStack {
                iconBackground()
                Image("logo-CampuraOne")
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(.infinity)
                    .frame(width: screen.width/4.7)
                    .blur(radius: 10)
                    .opacity(0.8)
                    .offset(x: 2, y: 2)
                Image("logo-CampuraOne")
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(.infinity)
                    .frame(width: screen.width/4.7)
            }
            .padding(.bottom, screen.height/22)
            
            Text("欢迎来到 Campura One")
                .font(.largeTitle)
                .bold()
        }
        
    }

    private var methodSelector: some View {
        VStack(alignment: .leading) {
            Text("请选择你的登录方式")
                .font(.title3)
            HStack {
                Image(systemName: "info.circle")
                Text("请以校方下发的登录方式为准")
            }
            .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                ForEach(LoginMethod.allCases, id: \.self) { item in
                    HStack(spacing: 8) {
                        Image(systemName: item.icon)
                        Text(item.title)
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .background {
                        if loginMethod == item {
                            selectorBgRect()
                        }
                    }
                    .beButton {
                        withAnimation(.smooth) {
                            loginMethod = item
                        }
                        print(loginMethod)
                        
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(5)
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Material.thin)
            }
        }
        
    }
    
    @ViewBuilder func selectorBgRect() -> some View {
        RoundedRectangle(cornerRadius: 13, style: .continuous)
            .fill(Color.gray.opacity(0.25))
            .matchedGeometryEffect(id: "loginSelector", in: selectorBg, properties: .position)
    }
    
    @FocusState var isFocusedOn_Account
    @FocusState var isFocusedOn_Password
    private var accountPasswordSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("使用账号密码登录")
                .font(.headline)

            VStack(spacing: 12) {
                TextField("账号", text: $account)
                    .focused($isFocusedOn_Account)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background {
                        inputBackground(isFocused: isFocusedOn_Account)
                    }

                SecureField("密码", text: $password)
                    .focused($isFocusedOn_Password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background {
                        inputBackground(isFocused: isFocusedOn_Password)
                    }
            }
            .font(.system(.body, design: .monospaced))
            HStack {
                Spacer()
                Image(systemName: "key.fill")
                Text("登录")
                Spacer()
            }
            .beButton {
                Task {
                    await login()
                }
            }
            .buttonStyle(.borderedProminent)
            .padding(.vertical, 15)
            .disabled(account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || isLoading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .animation(.smooth, value: isFocusedOn_Account)
        .animation(.smooth, value: isFocusedOn_Password)
    }

    private var noticeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("说明")
                .font(.headline)
            Text("学生账号由校方统一下发，无渠道供学生擅自注册，若有疑问请联系校方。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    
    @ViewBuilder func inputBackground(isFocused: Bool) -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(isFocused ? .blue.opacity(0.2) : .gray.opacity(0.33))
            .stroke(isFocused ? .blue.opacity(0.6) : .clear, style: .init(lineWidth: 4))
            .shadow(color: .black.opacity(0.08), radius: 8, x: 1, y: 2)
    }

    @MainActor
    private func login() async {
        let trimmedAccount = account.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAccount.isEmpty, !password.isEmpty else {
            errorMessage = "请填写完整的账号和密码"
            return
        }

        isLoading = true
        
        defer {
            isLoading = false
        }

        do {
            let result = try await RemoteDataService.shared.loginStudent(userName: trimmedAccount, password: password)
            let user = result.user

            persist(user: user)
            RemoteDataService.shared.bindUser(user)

            confirmedUser = user
            confirmedStudent = try? await RemoteDataService.shared.fetchMyStudentProfile()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func persist(user: AppUser) {
        if let old = savedUsers.first(where: { $0.userID == user.userID }) {
            old.userName = user.userName
            old.userImg = user.userImg
            old.token = user.token
            old.shopIDs = user.shopIDs
            old.studentID = user.studentID
            old.createdAt = user.createdAt
            old.updatedAt = user.updatedAt
        } else {
            modelContext.insert(user)
        }

        try? modelContext.save()
    }
}

extension StudentLoginSheet {
    
    @ViewBuilder
    func iconBackground() -> some View {
        HStack {
            HStack {
                VStack {//外
                    Image(systemName: "visionpro")
                        .font(.system(size: 24))
                        .rotationEffect(.degrees(-5))
                        .offset(x: screen.width/13, y: -screen.height/22)
                    Image(systemName: "lock.icloud.fill")
                        .font(.system(size: screen.width > 390 ? 24 : 22))
                        .offset(x: screen.width/23, y: -screen.height/40)
                    Image(systemName: "cloud.circle")
                        .font(.system(size: screen.width > 390 ? 28 : 26))
                        .offset(x: screen.width/24, y: screen.height/45)
                }
                .symbolEffect(.appear,
                              isActive: !showEx)
                VStack {//中
                    Image(systemName: "clock")
                        .font(.system(size: 20))
                        .offset(x: screen.width/16, y: -screen.height/72)
                    Image(systemName: "ellipsis.message.fill")
                        .font(.system(size: 23))
                        .offset(x: screen.width/38, y: screen.height/59)
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 22))
                        .offset(x: screen.width/17, y: screen.height/15.7)
                }
                .symbolEffect(.appear,
                              isActive: !showMid)
                VStack {//内
                    Image(systemName: "applewatch")
                        .font(.system(size: 34))
                        .offset(x: screen.width/21, y: -screen.height/180)
                    Image(systemName: "at")
                        .font(.system(size: 20))
                        .offset(x: screen.width/56, y: screen.height/80)
                    Image(systemName: "ellipsis.curlybraces")
                        .font(.system(size: screen.width > 390 ? 34 : 32))
                        .offset(x: screen.width/56, y: screen.height/40)
                    Image(systemName: "bolt.horizontal.icloud")
                        .font(.system(size: screen.width > 390 ? 29 : 27))
                        .offset(x: screen.width/10, y: screen.height/25)
                    
                }
                .symbolEffect(.appear,
                              isActive: !showIn)
            }
             
           Rectangle()
                .fill(.clear)
                .frame(width: screen.width/4.7, height: 0)
                .padding(.horizontal)
            
            HStack {
                VStack {//内
                    Image(systemName: "network")
                        .font(.system(size: 23))
                        .offset(x: -screen.width/17, y: -screen.height/140)
                    Image(systemName: "bolt.heart.fill")
                        .font(.system(size: 29))
                        .offset(x: screen.width/50)
                    Image(systemName: "macbook.and.iphone")
                        .font(.system(size: 26))
                        .offset(x: screen.width/140, y: screen.height/50)
                    Image(systemName: "atom")
                        .font(.system(size: screen.width > 390 ? 23 : 21))
                        .rotationEffect(.degrees(10))
                        .offset(x: -screen.width/14, y: screen.height/31)
                }
                .symbolEffect(.appear,
                              isActive: !showIn)
                
                VStack {//中
                    Image(systemName: "bonjour")
                        .font(.system(size: 23))
                        .rotationEffect(.degrees(24))
                        .offset(x: -screen.width/15, y: -screen.height/18)
                    Image(systemName: "gift.fill")
                        .font(.system(size: screen.width > 390 ? 28 : 26))
                        .offset(x: -screen.width/40, y: screen.height/13)
                }
                .symbolEffect(.appear,
                              isActive: !showMid)
                VStack {//外
                    Image(systemName: "icloud.and.arrow.down")
                        .font(.system(size: 24))
                        .offset(x: -screen.width/10, y: -screen.height/50)
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: screen.width > 390 ? 30 : 28))
                        .offset(x: -screen.width/15, y: screen.height/130)
                }
               
                .symbolEffect(.appear,
                              isActive: !showEx)
            }
            
        }
        .onAppear {
            DispatchAfter(after: 0.26) {
                showIn = true
                DispatchAfter(after: 0.2) {
                    showMid = true
                    DispatchAfter(after: 0.14) {
                        showEx = true
                    }
                }
            }
        }
      
    }
}

private struct ServiceItem: Identifiable {
    let id = UUID()
    let name: String
    let description: String?
}

private enum LoginMethod: CaseIterable {
    case accountPassword
    case qrCode

    var title: String {
        switch self {
        case .accountPassword: return "通过账号密码继续"
        case .qrCode: return "通过密钥二维码继续"
        }
    }

    var icon: String {
        switch self {
        case .accountPassword: return "person.badge.key.fill"
        case .qrCode: return "qrcode.viewfinder"
        }
    }
}
