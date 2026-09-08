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

    var body: some View {
        NavigationStack {
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
        }
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
