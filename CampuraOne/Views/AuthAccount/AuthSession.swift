import Combine
import Foundation
import SwiftData
import SwiftUI

@MainActor
final class AuthSession: ObservableObject {
    enum State {
        case restoring
        case signedOut
        case signedIn(AppUser)
    }

    @Published private(set) var state: State = .restoring
    private var hasRestored = false

    var currentUser: AppUser? {
        if case .signedIn(let user) = state {
            return user
        }
        return nil
    }

    func restore(from savedUsers: [AppUser], modelContext: ModelContext) async {
        guard !hasRestored else { return }
        hasRestored = true

        guard let savedUser = savedUsers.first(where: {
            guard let token = $0.token else { return false }
            return !token.isEmpty
        }), let token = savedUser.token else {
            APIClient.shared.clearToken()
            state = .signedOut
            return
        }

        APIClient.shared.setToken(token)

        do {
            let refreshedUser = try await RemoteDataService.shared.fetchCurrentUser()
            refreshedUser.token = token
            update(savedUser, from: refreshedUser)
            try? modelContext.save()
            state = .signedIn(savedUser)
        } catch let error as APIClientError where error.isUnauthorized {
            savedUser.token = nil
            try? modelContext.save()
            APIClient.shared.clearToken()
            state = .signedOut
        } catch {
            // 网络暂时不可用时保留本地会话；后续受保护请求仍由服务器校验 JWT。
            state = .signedIn(savedUser)
        }
    }

    func login(
        userName: String,
        password: String,
        savedUsers: [AppUser],
        modelContext: ModelContext
    ) async throws {
        let result = try await RemoteDataService.shared.loginStudent(
            userName: userName,
            password: password
        )

        let activeUser: AppUser
        if let existing = savedUsers.first(where: { $0.userID == result.user.userID }) {
            update(existing, from: result.user)
            activeUser = existing
        } else {
            modelContext.insert(result.user)
            activeUser = result.user
        }

        for user in savedUsers where user.userID != activeUser.userID {
            user.token = nil
        }

        do {
            try modelContext.save()
        } catch {
            APIClient.shared.clearToken()
            throw error
        }
        APIClient.shared.setToken(result.token)
        CourseScheduleStore.shared.reset()
        state = .signedIn(activeUser)
    }

    func signOut(savedUsers: [AppUser], modelContext: ModelContext) {
        for user in savedUsers {
            user.token = nil
        }
        try? modelContext.save()
        APIClient.shared.clearToken()
        CourseScheduleStore.shared.reset()
        state = .signedOut
    }

    private func update(_ destination: AppUser, from source: AppUser) {
        destination.userName = source.userName
        destination.userImg = source.userImg
        destination.token = source.token
        destination.shopIDs = source.shopIDs
        destination.studentID = source.studentID
        destination.createdAt = source.createdAt
        destination.updatedAt = source.updatedAt
    }
}

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var authSession: AuthSession
    @Query(sort: \AppUser.updatedAt, order: .reverse) private var savedUsers: [AppUser]

    var body: some View {
        Group {
            switch authSession.state {
            case .restoring:
                ProgressView("正在恢复登录状态…")
            case .signedOut:
                LoginView()
            case .signedIn(let user):
                ContentView(userProfile: user)
            }
        }
        .task {
            await authSession.restore(from: savedUsers, modelContext: modelContext)
        }
        .onReceive(NotificationCenter.default.publisher(for: .authenticationRequired)) { _ in
            authSession.signOut(savedUsers: savedUsers, modelContext: modelContext)
        }
    }
}
