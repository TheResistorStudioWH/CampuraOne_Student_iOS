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

struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AppUser.updatedAt, order: .reverse) private var savedUsers: [AppUser]

    @State private var showLoginSheet = false
    @State private var symbolStep = 0

    private let services: [ServiceItem] = [
        .init(name: "校园帐号统一登录", description: "学生账号与密码由校方统一下发"),
        .init(name: "课程表、校历与校园信息同步", description: "登录后可直接读取学生所属身份数据"),
        .init(name: "后续支持学生证二维码登录", description: "预留无接触扫码登录能力"),
        .init(name: "个人信息确认与本地保持登录状态")
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                headerView
                serviceCard
                animatedSymbolCard
                openLoginButton
            }
            .padding(20)
        }
        .sheet(isPresented: $showLoginSheet) {
            StudentLoginSheet { dismiss() }
        }
        .task {
            startSymbolLoop()
            if let existing = savedUsers.first, let token = existing.token, !token.isEmpty {
                RemoteDataService.shared.bindUser(existing)
            }
        }
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image("Campura One")
                .resizable()
                .scaledToFit()
                .frame(width: 150)

            Text("登录后，您将可享受以下服务：")
                .font(.system(size: 30, weight: .bold, design: .rounded))
        }
    }

    private var serviceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(services) { item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("·")
                            .bold()
                        Text(item.name)
                    }
                    if let description = item.description {
                        HStack(alignment: .top, spacing: 8) {
                            Text("·")
                                .opacity(0)
                            Text(description)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private var animatedSymbolCard: some View {
        VStack(spacing: 18) {
            iconBackground()
                .frame(maxWidth: .infinity)
                .frame(height: 180)

            Image(systemName: symbolName)
                .font(.system(size: 92, weight: .regular))
                .contentTransition(.symbolEffect(.replace))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.accent)
                .animation(.smooth(duration: 0.55), value: symbolStep)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var openLoginButton: some View {
        Button {
            showLoginSheet = true
        } label: {
            HStack {
                Spacer()
                Image(systemName: "person.crop.circle.badge.checkmark")
                Text("登录 Campura One 学生账号")
                    .font(.headline)
                Spacer()
            }
            .padding(.vertical, 16)
        }
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

    let onFinish: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 26) {
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
            .navigationTitle("学生登录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .alert("登录失败", isPresented: .constant(errorMessage != nil), actions: {
                Button("好的") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
    }

    private var topIconSection: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .frame(height: 180)
                iconBackground()
                Image("Campura One")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 84)
            }

            Text("欢迎来到 Campura One")
                .font(.title2.bold())
                .foregroundStyle(.accent)
        }
    }

    private var methodSelector: some View {
        HStack(spacing: 12) {
            ForEach(LoginMethod.allCases, id: \.self) { item in
                Button {
                    withAnimation(.smooth) {
                        loginMethod = item
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: item.icon)
                        Text(item.title)
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(loginMethod == item ? .white : .primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(loginMethod == item ? Color.accentColor : Color.gray.opacity(0.12))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var accountPasswordSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("使用账号密码登录")
                .font(.headline)

            VStack(spacing: 12) {
                TextField("账号", text: $account)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(inputBackground)

                SecureField("密码", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(inputBackground)
            }

            Button {
                Task { await login() }
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "key.fill")
                    Text("登录")
                    Spacer()
                }
                .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .disabled(account.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || isLoading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private var noticeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("说明")
                .font(.headline)
            Text("账号由校方统一下发，无渠道擅自注册，若有疑问请联系校方。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
        )
    }

    private var inputBackground: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.bar)
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
        defer { isLoading = false }

        do {
            let user = try await RemoteDataService.shared.loginStudent(userName: trimmedAccount, password: password)
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

// MARK: - 动画背景

private extension LoginView {
    @ViewBuilder
    func iconBackground() -> some View {
        HStack(spacing: 22) {
            VStack(spacing: 12) {
                Image(systemName: "building.columns.fill")
                Image(systemName: "person.text.rectangle.fill")
                Image(systemName: "calendar.badge.clock")
            }
            .font(.system(size: 26))
            .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Image(systemName: "applewatch")
                Image(systemName: "qrcode.viewfinder")
                Image(systemName: "graduationcap.fill")
            }
            .font(.system(size: 34))
            .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                Image(systemName: "key.fill")
                Image(systemName: "person.crop.circle.badge.checkmark")
            }
            .font(.system(size: 26))
            .foregroundStyle(.secondary)
        }
        .symbolEffect(.appear.byLayer, options: .speed(0.8), value: symbolStep)
    }
}

private extension StudentLoginSheet {
    @ViewBuilder
    func iconBackground() -> some View {
        HStack(spacing: 18) {
            VStack(spacing: 12) {
                Image(systemName: "book.pages.fill")
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                Image(systemName: "chart.bar.doc.horizontal.fill")
            }
            .font(.system(size: 24))
            .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Image(systemName: "person.badge.key.fill")
                Image(systemName: "qrcode")
                Image(systemName: "applewatch")
            }
            .font(.system(size: 30))
            .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                Image(systemName: "graduationcap.fill")
                Image(systemName: "building.2.crop.circle.fill")
                Image(systemName: "sparkles")
            }
            .font(.system(size: 24))
            .foregroundStyle(.secondary)
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
        case .accountPassword: return "账号密码"
        case .qrCode: return "扫码登录"
        }
    }

    var icon: String {
        switch self {
        case .accountPassword: return "person.badge.key.fill"
        case .qrCode: return "qrcode.viewfinder"
        }
    }
}
