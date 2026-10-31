import Foundation
import Combine

@MainActor
final class NavigationPreferencesStore: ObservableObject {
    struct Client {
        var fetch: () async throws -> NavigationPreferences
        var update: (NavigationPreferenceUpdate) async throws -> NavigationPreferences
        var clearHistory: () async throws -> Void
        var didChange: () -> Void = { }
    }

    @Published private(set) var preferences: NavigationPreferences?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var userID: Int?
    private let client: Client
    private var generation = UUID()

    init(client: Client) { self.client = client }

    func bind(userID: Int?) {
        guard self.userID != userID else { return }
        self.userID = userID
        generation = UUID()
        preferences = nil
        errorMessage = nil
        isLoading = false
        isSaving = false
    }

    func load(userID: Int, force: Bool = false) async {
        bind(userID: userID)
        guard !isLoading, !isSaving, force || preferences == nil else { return }
        let ticket = generation
        isLoading = true
        errorMessage = nil
        defer { if generation == ticket { isLoading = false } }
        do {
            let result = try await client.fetch()
            try Task.checkCancellation()
            guard generation == ticket else { return }
            preferences = result
        } catch is CancellationError { }
        catch { if generation == ticket { errorMessage = error.localizedDescription } }
    }

    @discardableResult
    func save(_ update: NavigationPreferenceUpdate) async -> Bool {
        guard userID != nil, !isSaving, !isLoading else { return false }
        let ticket = generation
        isSaving = true
        errorMessage = nil
        defer { if generation == ticket { isSaving = false } }
        do {
            let result = try await client.update(update)
            try Task.checkCancellation()
            guard generation == ticket else { return false }
            preferences = result
            client.didChange()
            return true
        } catch is CancellationError { return false }
        catch {
            guard generation == ticket else { return false }
            // Re-read after a conflict; never overwrite another device's settings.
            if (error as? APIClientError)?.statusCode == 409 {
                if let fresh = try? await client.fetch(), generation == ticket { preferences = fresh }
                guard generation == ticket else { return false }
                errorMessage = "设置已在其他位置更新，请检查后再保存"
            } else { errorMessage = error.localizedDescription }
            return false
        }
    }

    @discardableResult
    func setHistoryEnabled(_ enabled: Bool) async -> Bool {
        guard let preferences else { return false }
        return await save(NavigationPreferenceUpdate(expectedVersion: preferences.version, historyEnabled: enabled))
    }

    @discardableResult
    func clearHistory() async -> Bool {
        guard userID != nil, !isLoading, !isSaving else { return false }
        let ticket = generation
        isSaving = true
        errorMessage = nil
        defer { if generation == ticket { isSaving = false } }
        do {
            try await client.clearHistory()
            guard generation == ticket else { return false }
            client.didChange()
            // DELETE also advances the preference version on the server.
            preferences = nil
            let fresh = try await client.fetch()
            try Task.checkCancellation()
            guard generation == ticket else { return false }
            preferences = fresh
            return true
        } catch is CancellationError { return false }
        catch { if generation == ticket { errorMessage = error.localizedDescription }; return false }
    }
}
