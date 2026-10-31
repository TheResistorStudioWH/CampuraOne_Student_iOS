import Foundation
import CamapKit
import CoreLocation

private enum CheckError: Error { case unavailable }

@MainActor private final class NavigationFixture {
    let samples: [[String: Any]]
    var commands: [NavigationCommand] = []
    var feedbackCount = 0
    var failure: APIClientError?
    var noticesAvailable = true
    var noticeVersion = 1
    var held: CheckedContinuation<NavigationResult, Never>?
    var shouldHold = false

    init() throws {
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as! [String: Any]
        samples = (json["examples"] as! [[String: Any]]).map { ($0["response"] as! [String: Any])["data"] as! [String: Any] }
    }

    func plan(version: Int = 1, sample: Int = 1) throws -> NavigationPlan {
        var data = samples[sample]
        data["sessionID"] = "11111111-1111-4111-8111-111111111111"
        data["contextVersion"] = version
        data["planID"] = "plan-\(version)"
        if var suggestions = data["suggestions"] as? [[String: Any]] {
            for i in suggestions.indices {
                suggestions[i]["contextVersion"] = version
                suggestions[i]["expiresAt"] = NavigationCoding.iso(Date().addingTimeInterval(600))
            }
            data["suggestions"] = suggestions
        }
        return try NavigationCoding.decoder().decode(NavigationPlan.self, from: JSONSerialization.data(withJSONObject: data))
    }

    func store() -> StudentNavigationStore {
        StudentNavigationStore(client: .init(send: { command in
            self.commands.append(command)
            if let failure = self.failure { throw failure }
            if self.shouldHold {
                self.shouldHold = false
                return await withCheckedContinuation { self.held = $0 }
            }
            if command.action == .end { return .ended(sessionID: command.sessionID!) }
            return .plan(try self.plan(version: (command.expectedContextVersion ?? 0) + 1))
        }, feedback: { _ in
            self.feedbackCount += 1
            return NavigationFeedbackResult(recorded: true, reasonCode: nil)
        }, source: { id in
            guard self.noticesAvailable else { return nil }
            return NavigationSourceNotice(notice: AnnouncementItem(announceID: id, schoolID: 1, content: "施工期间绕行", type: .importantMarkdown,
                                    target: nil, startTime: .distantPast, endTime: .distantPast, createdAt: nil, updatedAt: nil), version: self.noticeVersion)
        }))
    }
}

@MainActor private final class PreferenceFixture {
    var value = NavigationPreferences.initial
    var fail = false
    var conflict = false
    var writes = 0
    var clears = 0
    func store() -> NavigationPreferencesStore {
        NavigationPreferencesStore(client: .init(fetch: {
            if self.fail { throw CheckError.unavailable }; return self.value
        }, update: { patch in
            self.writes += 1
            if self.fail { throw CheckError.unavailable }
            if self.conflict {
                self.value.version += 1
                throw APIClientError.server(statusCode: 409, code: 409, message: "conflict")
            }
            precondition(patch.expectedVersion == self.value.version)
            if let history = patch.historyEnabled { self.value.historyEnabled = history }
            self.value.version += 1
            return self.value
        }, clearHistory: { self.clears += 1; self.value.version += 1 }))
    }
}

@main @MainActor struct NavigationChecks {
    static var count = 0
    static func check(_ value: @autoclosure () -> Bool, _ message: String) {
        precondition(value(), message); count += 1
    }
    static func waitUntil(_ predicate: () -> Bool) async {
        for _ in 0..<10000 { if predicate() { return }; await Task.yield() }
        fatalError("Offline request did not start")
    }

    static func main() async throws {
        let fixture = try NavigationFixture()
        for i in fixture.samples.indices {
            let data = try JSONSerialization.data(withJSONObject: fixture.samples[i])
            let plan = try NavigationCoding.decoder().decode(NavigationPlan.self, from: data)
            check(plan.hasRoute, "All three captured responses decode")
            check(plan.route?.polyline.count ?? 0 > 1, "Route is a local-coordinate polyline")
            check(plan.overlays.first?.geometry.points.count == 4, "Construction geometry survives decoding")
        }
        let first = try fixture.plan()
        check(first.sources.first?.publishedAt == APIDate.parse("2026-10-29T00:00:00+08:00"), "MySQL dates use Shanghai time")
        check(first.suggestion(first.suggestions[0].id, at: .distantFuture) == nil, "Expired suggestions cannot be selected")
        var command = NavigationCommand(action: .updateContext)
        command.origin = .node(id: "node", frameID: "frame")
        command.destination = ""
        command.clearsArrivalTime = true
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(command)) as! [String: Any]
        check(encoded["arrivalTime"] is NSNull, "Clear arrival must encode explicit null")
        check(encoded["destination"] as? String == "", "Empty destination selects next course")
        check((encoded["origin"] as? [String: Any])?["nodeID"] as? String == "node", "Manual origin uses node ID")
        check(encoded["expectedContextVersion"] == nil, "No fake version is encoded")
        try await sessions(fixture)
        try await preferences()
        try await maps()
        print("Navigation checks passed: \(count)")
    }

    private static func sessions(_ fixture: NavigationFixture) async throws {
        let store = fixture.store()
        store.bind(userID: 1)
        let start = Task { await store.start(origin: .node(id: "node", frameID: "frame")) }
        await waitUntil { !fixture.commands.isEmpty }
        let second = Task { await store.addStop(placeID: "place") }
        await start.value; await second.value
        check(store.plan?.contextVersion == 2, "Queued commands advance version")
        check(fixture.commands[1].expectedContextVersion == 1, "Version is captured after the preceding request")
        let originalID = store.plan?.planID
        let suggestion = store.plan!.suggestions[0]
        store.previewSuggestion(suggestion.id)
        check(store.preview?.id == suggestion.id, "Preview selects the current candidate")
        check(store.plan?.planID == originalID, "Preview never replaces accepted route")
        await store.acceptSuggestion(suggestion.id)
        check(fixture.commands.last?.suggestionID == suggestion.id, "Accept sends the candidate ID")
        check(fixture.feedbackCount == 0, "Server-owned accepted feedback is not sent twice")
        let recorded = await store.recordFeedback(.disliked, placeID: "place", historyEnabled: false)
        check(!recorded && fixture.feedbackCount == 0, "History disabled sends no feedback")
        let learned = await store.recordFeedback(.disliked, placeID: "place", historyEnabled: true)
        check(learned && fixture.feedbackCount == 1, "Explicit feedback can be submitted")
        let source = store.plan!.sources[0]
        await store.loadSource(source)
        check(store.sourceNotice != nil, "Navigation sources are not filtered by old display expiry")
        fixture.noticesAvailable = false
        await store.loadSource(source)
        check(store.sourceNotice == nil && store.sourceError != nil, "Invisible source removes old text")

        fixture.noticesAvailable = true
        fixture.noticeVersion = 2
        await store.loadSource(source)
        check(store.requiresReplan && store.sourceNotice == nil, "Changed source version invalidates the old route explanation")
        fixture.noticeVersion = 1
        await store.replan()

        fixture.failure = .server(statusCode: 409, code: 409, message: "changed",
                                  details: try JSONSerialization.data(withJSONObject: ["contextVersion": 12]))
        await store.replan()
        check(store.requiresReplan && !store.isCurrent && store.preview == nil, "409 invalidates candidates and route freshness")
        fixture.failure = nil
        await store.replan()
        check(fixture.commands.last?.expectedContextVersion == 12, "Explicit recovery uses server-reported version")
        check(store.plan?.contextVersion == 13 && store.isCurrent, "Replan recovers the session")
        fixture.failure = .server(statusCode: 410, code: 410, message: "expired")
        await store.replan()
        check(store.requiresRestart && !store.isCurrent, "Expired session requires a new start")
        let before = fixture.commands.count
        await store.removeStop("old-stop")
        check(fixture.commands.count == before, "Mutations do not replay against an expired session")
        fixture.failure = nil
        await store.start(origin: .node(id: "node", frameID: "frame"))
        fixture.failure = .server(statusCode: 503, code: 503, message: "unavailable")
        await store.replan()
        check(!store.isCurrent, "Server outage must not leave an old route marked current")
        fixture.failure = nil
        await store.start(origin: .node(id: "node", frameID: "frame"))
        await store.end()
        check(store.plan == nil, "End clears accepted route")

        fixture.shouldHold = true
        let held = Task { await store.start(origin: .node(id: "node", frameID: "frame")) }
        await waitUntil { fixture.held != nil }
        store.bind(userID: 2)
        fixture.held?.resume(returning: .plan(try fixture.plan()))
        fixture.held = nil
        await held.value
        check(store.plan == nil && store.lastOrigin == nil, "Old-account response cannot populate new account")
    }

    static func preferences() async throws {
        let fixture = PreferenceFixture(), store = fixture.store()
        await store.load(userID: 1)
        check(store.preferences?.historyEnabled == false, "History defaults to off")
        let enabled = await store.setHistoryEnabled(true)
        check(enabled && store.preferences?.historyEnabled == true, "History toggle persists server response")
        fixture.fail = true
        let failed = await store.setHistoryEnabled(false)
        check(!failed && store.preferences?.historyEnabled == true, "Failed save preserves actual server setting")
        fixture.fail = false
        fixture.conflict = true
        let writes = fixture.writes
        _ = await store.setHistoryEnabled(false)
        check(fixture.writes == writes + 1 && store.errorMessage != nil, "Conflict never retries a write automatically")
        check(store.preferences?.version == fixture.value.version, "Conflict re-reads current settings")
        fixture.conflict = false
        let cleared = await store.clearHistory()
        check(cleared && fixture.clears == 1, "Clear history calls DELETE")
        check(store.preferences?.version == fixture.value.version, "Clear refreshes advanced preference version")
        check(store.preferences?.historyEnabled == true, "Clearing history preserves chosen learning setting")
        store.bind(userID: 2)
        check(store.preferences == nil, "Other accounts do not inherit preferences")
    }

    static func maps() async throws {
        let frameID = "10000000-0000-4000-8000-000000000001"
        var frame = SpatialFrame(id: frameID, name: "校园")
        var document = CamapDocument(id: "10000000-0000-4000-8000-000000000002", frames: [frame])
        let one = CampusMapSnapshot(schoolID: 9, document: document, etag: "\"hash-one\"")
        var next = CampusMapResponse.document(one), seenETag: String?
        var fails = false
        let store = CampusMapStore(client: .init(school: { 9 }, fetch: { school, etag in
            precondition(school == 9); seenETag = etag
            if fails { throw CheckError.unavailable }; return next
        }))
        await store.load(userID: 1)
        check(store.snapshot?.hash == "hash-one", "Map hash comes from authoritative ETag")
        store.setPlacement(.init(longitude: 114, latitude: 30, localAnchor: Point(100, 200)), frameID: frameID)
        next = .unchanged
        await store.load(userID: 1, force: true)
        check(seenETag == "\"hash-one\"" && store.snapshot != nil, "304 preserves verified map")
        check(store.placements[frameID] != nil, "Unchanged map keeps temporary placement")
        document.title = "新地图"
        next = .document(.init(schoolID: 9, document: document, etag: "\"hash-two\""))
        await store.load(userID: 1, force: true)
        check(store.placements.isEmpty && store.snapshot?.hash == "hash-two", "Changed map resets temporary alignment")
        fails = true
        await store.load(userID: 1, force: true)
        check(store.snapshot?.hash == "hash-two" && store.errorMessage != nil, "Map read failure preserves old content and reports failure")
        let location = CLLocation(coordinate: .init(latitude: 30, longitude: 114), altitude: 0,
                                  horizontalAccuracy: 5, verticalAccuracy: 5, timestamp: Date())
        check(CampusMapGeometry.gpsOrigin(location, frame: frame) == nil, "Missing real binding never uses visual placement for GPS")
        frame.bindings["mapkit"] = CamapKit.Binding(longitude: 114, latitude: 30, rotation: 15)
        check(CampusMapGeometry.gpsOrigin(location, frame: frame) != nil, "Good GPS accepts real MapKit binding")
        let imprecise = CLLocation(coordinate: location.coordinate, altitude: 0, horizontalAccuracy: 31, verticalAccuracy: 0, timestamp: Date())
        check(CampusMapGeometry.gpsOrigin(imprecise, frame: frame) == nil, "Poor accuracy requires a manual start")
        let old = CLLocation(coordinate: location.coordinate, altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 0, timestamp: Date().addingTimeInterval(-61))
        check(CampusMapGeometry.gpsOrigin(old, frame: frame) == nil, "Stale GPS is rejected")
        let placement = TemporaryCampusPlacement(longitude: 114, latitude: 30, rotation: 90, localAnchor: Point(100, 200))
        let anchor = placement.project(Point(100, 200))
        check(abs(anchor.latitude - 30) < 1e-8 && abs(anchor.longitude - 114) < 1e-8, "Temporary placement respects local center")
        let projected = CampusMapGeometry.coordinate(Point(25, 50), frame: frame, temporary: placement)!
        let sdk = frame.bindings["mapkit"]!.project(Point(25, 50))
        check(abs(projected.latitude - sdk.y) < 1e-8, "Real binding takes priority over temporary data")
        store.bind(userID: nil)
        check(store.snapshot == nil && store.placements.isEmpty, "Logout clears maps and temporary placements")
    }
}
