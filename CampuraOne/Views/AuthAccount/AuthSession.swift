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
        async let launchDisplay: Void = Task.sleep(for: .milliseconds(500))

        do {
            let refreshedUser = try await RemoteDataService.shared.fetchCurrentUser()
            refreshedUser.token = token
            update(savedUser, from: refreshedUser)
            try? modelContext.save()
            try? await launchDisplay
            state = .signedIn(savedUser)
        } catch let error as APIClientError where error.isUnauthorized {
            savedUser.token = nil
            try? modelContext.save()
            APIClient.shared.clearToken()
            try? await launchDisplay
            state = .signedOut
        } catch {
            // 网络暂时不可用时保留本地会话；后续受保护请求仍由服务器校验 JWT。
            try? await launchDisplay
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \AppUser.updatedAt, order: .reverse) private var savedUsers: [AppUser]

    private var isSignedIn: Bool {
        authSession.currentUser != nil
    }

    private var advertisementLifecycle: String {
        switch authSession.state {
        case .restoring: return "restoring"
        case .signedOut: return "signedOut"
        case .signedIn(let user): return "\(user.userID)-\(scenePhase == .active)"
        }
    }

    var body: some View {
        Group {
            switch authSession.state {
            case .restoring:
                SessionLaunchScreen()
                    .transition(.opacity)
            case .signedOut:
                LoginView()
                    .transition(.opacity)
            case .signedIn(let user):
                ContentView(userProfile: user)
                    .transition(reduceMotion ? .opacity : .dockLaunch)
            }
        }
        .animation(
            reduceMotion
                ? .easeOut(duration: 0.18)
                : .spring(response: 0.62, dampingFraction: 0.82),
            value: isSignedIn
        )
        .task {
            await authSession.restore(from: savedUsers, modelContext: modelContext)
        }
        .task(id: advertisementLifecycle) {
            guard !Task.isCancelled else { return }
            guard let user = authSession.currentUser else {
                if case .signedOut = authSession.state {
                    await AdvertisementStore.shared.clearSession()
                }
                return
            }
            guard scenePhase == .active else {
                await AdvertisementStore.shared.pause()
                return
            }
            await AdvertisementStore.shared.run(userID: user.userID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .authenticationRequired)) { _ in
            authSession.signOut(savedUsers: savedUsers, modelContext: modelContext)
        }
    }
}

/// App-managed restoration screen, not a paid interstitial. Replace only the
/// central symbol with the final brand asset; session/transition logic stays intact.
private struct SessionLaunchScreen: View {
    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 68, weight: .light))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text("Campura One")
                    .font(.system(.title2, design: .rounded, weight: .semibold))
                Spacer()
                ProgressView().controlSize(.small)
                Text("正在恢复登录")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.bottom, 36)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct DockLaunchModifier: AnimatableModifier {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .scaleEffect(0.82 + 0.18 * progress, anchor: .center)
            .opacity(progress)
            .blur(radius: (1 - progress) * 10)
    }
}

private extension AnyTransition {
    static var dockLaunch: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: DockLaunchModifier(progress: 0),
                identity: DockLaunchModifier(progress: 1)
            ),
            removal: .scale(scale: 0.94, anchor: .center).combined(with: .opacity)
        )
    }
}
