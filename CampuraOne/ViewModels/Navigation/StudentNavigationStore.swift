import Foundation
import Combine

/// Session/data integration only. The route-panel design will be discussed separately.
@MainActor
final class StudentNavigationStore: ObservableObject {
    struct Client {
        var send: (NavigationCommand) async throws -> NavigationResult
        var feedback: (NavigationFeedback) async throws -> NavigationFeedbackResult
        var source: (Int) async throws -> NavigationSourceNotice?
    }


    @Published private(set) var plan: NavigationPlan?
    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var requiresReplan = false
    @Published private(set) var requiresRestart = false
    @Published private(set) var previewSuggestionID: String?
    @Published private(set) var sourceNotice: AnnouncementItem?
    @Published private(set) var sourceError: String?
    @Published private(set) var lastOrigin: NavigationOrigin?
    @Published private(set) var destinationQuery: String?
    private var userID: Int?
    private var generation = UUID()
    private var tail: Task<Void, Never>?
    private var queuedTasks: [UUID: Task<Void, Never>] = [:]
    private var sourceRequest = UUID()
    private var lastLocationUpdate: Date?
    private var isPaused = false
    private var reportedContextVersion: Int?
    private let client: Client

    init(client: Client) { self.client = client }

    func bind(userID: Int?) {
        guard self.userID != userID else { return }
        self.userID = userID
        generation = UUID()
        for task in queuedTasks.values { task.cancel() }
        queuedTasks = [:]
        tail = nil
        plan = nil
        isWorking = false
        errorMessage = nil
        requiresReplan = false
        requiresRestart = false
        previewSuggestionID = nil
        sourceNotice = nil
        sourceError = nil
        lastOrigin = nil
        destinationQuery = nil
        lastLocationUpdate = nil
        isPaused = false
        reportedContextVersion = nil
        sourceRequest = UUID()
    }

    var isCurrent: Bool { !requiresReplan && !requiresRestart }
    var preview: NavigationSuggestion? { isCurrent ? plan?.suggestion(previewSuggestionID, at: Date()) : nil }

    func previewSuggestion(_ id: String?) { previewSuggestionID = plan?.suggestion(id, at: Date())?.id }
    func setPaused(_ paused: Bool) { isPaused = paused }
    func preferencesChanged() {
        guard plan != nil else { return }
        requiresReplan = true
        previewSuggestionID = nil
        sourceNotice = nil
        sourceRequest = UUID()
    }

    func start(origin: NavigationOrigin, destination: String? = nil, arrival: Date? = nil,
               recommendationsEnabled: Bool? = nil) async {
        var command = NavigationCommand(action: .start)
        command.origin = origin
        command.destination = destination
        command.arrivalTime = arrival.map(NavigationCoding.iso)
        command.recommendationsEnabled = recommendationsEnabled
        await send(command)
    }

    func update(origin: NavigationOrigin? = nil, destination: String? = nil, arrival: Date? = nil,
                clearArrival: Bool = false, departure: Date? = nil,
                durations: [String: Double]? = nil, order: [String]? = nil) async {
        var command = NavigationCommand(action: .updateContext)
        command.origin = origin
        command.destination = destination
        command.arrivalTime = arrival.map(NavigationCoding.iso)
        command.clearsArrivalTime = clearArrival
        command.departureTime = departure.map(NavigationCoding.iso)
        command.stopDurations = durations
        command.stopOrder = order
        await send(command)
    }

    func replan() async { await send(NavigationCommand(action: .replan)) }
    func end() async { await send(NavigationCommand(action: .end)) }
    func evaluateStop(_ request: String) async {
        var command = NavigationCommand(action: .evaluateOptionalStop)
        command.request = request.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let text = command.request, (1...200).contains(text.count) else {
            errorMessage = "请输入 1～200 字的途经需求"; return
        }
        await send(command)
    }
    func acceptSuggestion(_ id: String) async {
        var command = NavigationCommand(action: .acceptSuggestion)
        command.suggestionID = id
        await send(command)
    }
    func addStop(placeID: String, dwellMinutes: Double? = nil) async {
        guard dwellMinutes.map({ $0.isFinite && (0...120).contains($0) }) ?? true else {
            errorMessage = "停留时间应为 0～120 分钟"; return
        }
        var command = NavigationCommand(action: .addFixedStop)
        command.placeID = placeID
        command.dwellMinutes = dwellMinutes
        await send(command)
    }
    func removeStop(_ id: String) async {
        var command = NavigationCommand(action: .removeStop)
        command.stopID = id
        await send(command)
    }
    func setRecommendations(_ enabled: Bool) async {
        var command = NavigationCommand(action: .setRecommendations)
        command.recommendationsEnabled = enabled
        await send(command)
    }

    /// Called only for reliable GPS projected through a real MapKit binding.
    func updateLocation(_ origin: NavigationOrigin, at now: Date = Date()) async {
        guard !isPaused, isCurrent, plan != nil,
              now.timeIntervalSince(lastLocationUpdate ?? .distantPast) >= 15,
              origin != lastOrigin else { return }
        lastLocationUpdate = now
        await update(origin: origin)
    }

    /// Serial requests build their version at execution time, not while queued.
    private func send(_ input: NavigationCommand) async {
        guard userID != nil else { return }
        let ticket = generation
        let previous = tail
        let id = UUID()
        let task = Task { [weak self] in
            await previous?.value
            guard let self, ticket == self.generation, !Task.isCancelled else { return }
            defer { self.queuedTasks[id] = nil }
            var command = input
            if command.action != .start {
                guard let plan = self.plan, !self.requiresRestart else {
                    self.errorMessage = "请重新开始路线规划"; return
                }
                command.sessionID = plan.sessionID
                command.expectedContextVersion = self.reportedContextVersion ?? plan.contextVersion
                guard !self.requiresReplan || command.action == .replan || command.action == .end else {
                    self.errorMessage = "路线状态已变化，请先重新规划"; return
                }
            }
            if command.action == .acceptSuggestion,
               self.plan?.suggestion(command.suggestionID, at: Date()) == nil {
                self.errorMessage = "此推荐已过期，请重新规划"; self.requiresReplan = true; return
            }
            self.isWorking = true
            self.errorMessage = nil
            defer { if ticket == self.generation { self.isWorking = false } }
            do {
                let result = try await self.client.send(command)
                try Task.checkCancellation()
                guard ticket == self.generation else { return }
                switch result {
                case .plan(let plan):
                    guard command.action == .start || (plan.sessionID == command.sessionID
                          && plan.contextVersion > (command.expectedContextVersion ?? 0)) else {
                        throw APIClientError.invalidResponse
                    }
                    self.plan = plan
                    if let origin = command.origin { self.lastOrigin = origin }
                    if command.action == .start { self.destinationQuery = command.destination }
                    else if let destination = command.destination { self.destinationQuery = destination }
                case .ended:
                    self.plan = nil
                    self.lastOrigin = nil
                    self.destinationQuery = nil
                }
                self.requiresRestart = false
                self.requiresReplan = false
                self.reportedContextVersion = nil
                self.previewSuggestionID = nil
                self.sourceNotice = nil
                self.sourceRequest = UUID()
            } catch is CancellationError { }
            catch {
                guard ticket == self.generation else { return }
                self.errorMessage = error.localizedDescription
                self.previewSuggestionID = nil
                self.sourceNotice = nil
                self.sourceRequest = UUID()
                if let status = (error as? APIClientError)?.statusCode {
                    self.requiresRestart = status == 410 || status == 404 || status >= 500
                    self.requiresReplan = status == 409 || status == 403 || self.requiresRestart
                    if let apiError = error as? APIClientError,
                       case .server(_, _, _, let details) = apiError,
                       let details, let values = try? JSONSerialization.jsonObject(with: details) as? [String: Any],
                       let version = values["contextVersion"] as? Int {
                        self.reportedContextVersion = version
                    }
                } else {
                    // The server may have committed a timed-out mutation.
                    self.requiresReplan = true
                    self.requiresRestart = true
                }
            }
        }
        queuedTasks[id] = task
        tail = task
        await task.value
    }

    func recordFeedback(_ action: NavigationFeedback.Action, placeID: String,
                        historyEnabled: Bool, eventKey: String = UUID().uuidString) async -> Bool {
        // accept_suggestion already records accepted feedback atomically on the server.
        guard historyEnabled, action != .accepted, let plan, isCurrent else { return false }
        let ticket = generation
        let feedback = NavigationFeedback(sessionID: plan.sessionID, expectedContextVersion: plan.contextVersion,
                                          eventKey: eventKey, action: action, placeID: placeID)
        do {
            let response = try await client.feedback(feedback)
            return ticket == generation && response.recorded
        } catch { return false } // Feedback must never block a route operation.
    }

    func loadSource(_ source: NavigationSource) async {
        let ticket = generation
        let request = UUID()
        sourceRequest = request
        sourceNotice = nil
        sourceError = nil
        guard isCurrent, plan?.sources.contains(where: { $0.announceID == source.announceID && $0.version == source.version }) == true else {
            sourceError = "通知来源已变化，请先重新规划"; return
        }
        do {
            let result = try await client.source(source.announceID)
            try Task.checkCancellation()
            guard ticket == generation, sourceRequest == request else { return }
            if let result {
                guard result.version == source.version else {
                    sourceError = "通知已更新，请重新规划后查看依据"
                    requiresReplan = true
                    previewSuggestionID = nil
                    return
                }
                sourceNotice = result.notice
            } else { sourceError = "该通知已撤回或当前不可查看" }
        } catch is CancellationError { }
        catch {
            guard ticket == generation, sourceRequest == request else { return }
            sourceError = error.localizedDescription
        }
    }
}
