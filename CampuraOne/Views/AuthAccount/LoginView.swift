import SwiftData
import SwiftUI

struct LoginView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authSession: AuthSession
    @Query(sort: \AppUser.updatedAt, order: .reverse) private var savedUsers: [AppUser]

    @State private var userName = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var identity: LoginIdentity?
    @State private var showHelp = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            if identity == nil {
                identitySelection
            } else {
            VStack(spacing: 24) {
                LoginAnimatedSymbolCard()
                    .frame(height: 180)

                Form {
                    Section("学生账号登录") {
                        TextField("账号", text: $userName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .textContentType(.username)

                        SecureField("密码", text: $password)
                            .textContentType(.password)
                            .onSubmit {
                                submit()
                            }
                    }

                    Section {
                        Button {
                            submit()
                        } label: {
                            HStack {
                                Spacer()
                                if isLoading {
                                    ProgressView()
                                } else {
                                    Text("登录")
                                }
                                Spacer()
                            }
                        }
                        .disabled(isLoading || normalizedUserName.isEmpty || password.isEmpty)
                    }

                    if let errorMessage {
                        Section {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle("登录 Campura One")
            .disabled(isLoading)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("重新选择身份") { identity = nil }
                        .disabled(isLoading)
                }
            }
            }
        }
        .alert("账号由学校统一发放", isPresented: $showHelp) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("学生请联系辅导员或学校信息中心领取、恢复账号。访客与教职工登录暂未开放；本版本不会创建临时身份或跳过认证。")
        }
    }

    private enum LoginIdentity { case student }

    private var identitySelection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("CAMPURA ONE / 校园生活")
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
                Text("登录前，\n请先确认您的身份")
                    .font(.largeTitle.bold())
                Text("我是？").font(.title)
                HStack(alignment: .top, spacing: 16) {
                    identityCard(title: "校内人员", symbol: "graduationcap", detail: "已入学的学生\n已有校方发放的账号和密码", available: true)
                    identityCard(title: "其他情况", symbol: "person.crop.circle.badge.questionmark", detail: "访客、教职工\n或尚未录入系统的学生", available: false)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("对自己的情况有疑问？").font(.headline)
                    Divider()
                    Button("寻求帮助 · 联系校方") { showHelp = true }
                }
                .padding(20).background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
                Text("账号由学校统一发放，校园信息只在登录后开放。")
                    .font(.footnote).foregroundStyle(.secondary)
            }.padding(24)
        }
    }

    private func identityCard(title: String, symbol: String, detail: String, available: Bool) -> some View {
        Button {
            if available {
                withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.85)) {
                    identity = .student
                }
            } else { showHelp = true }
        } label: {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: symbol).font(.largeTitle).foregroundStyle(available ? Color.accentColor : .secondary)
                Text(title).font(.title2.bold())
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text(available ? "开始登录 →" : "了解账号规则 ↗").font(.subheadline.bold())
            }
            .frame(maxWidth: .infinity, minHeight: 230, alignment: .topLeading)
            .padding(16)
            .background(available ? Color.accentColor.opacity(0.09) : Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 24))
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }.buttonStyle(.plain)
    }

    private var normalizedUserName: String {
        userName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() {
        guard !isLoading, !normalizedUserName.isEmpty, !password.isEmpty else {
            return
        }

        errorMessage = nil
        isLoading = true

        Task {
            defer { isLoading = false }

            do {
                try await authSession.login(
                    userName: normalizedUserName,
                    password: password,
                    savedUsers: savedUsers,
                    modelContext: modelContext
                )
                password = ""
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthSession())
        .modelContainer(PreviewContainer.empty)
}
