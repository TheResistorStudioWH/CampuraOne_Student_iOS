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
//            if identity == nil {
//                IdentifySelectionView()
//            } else {
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
//            }
        }
        .alert("账号由学校统一发放", isPresented: $showHelp) {
            Button("知道了", role: .cancel) { }
        } message: {
            Text("学生请联系辅导员或学校信息中心领取、恢复账号。访客与教职工登录暂未开放；本版本不会创建临时身份或跳过认证。")
        }
    }

    private enum LoginIdentity { case student }

   
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
