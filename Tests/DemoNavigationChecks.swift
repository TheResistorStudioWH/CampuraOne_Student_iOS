import Foundation
import SwiftyJSON
import CamapKit

@main @MainActor struct DemoNavigationChecks {
    static var count = 0
    static func check(_ value: @autoclosure () -> Bool, _ message: String) {
        precondition(value(), message); count += 1
    }
    static func send(_ action: String, plan: NavigationPlan? = nil, values: [String: Any] = [:]) throws -> NavigationPlan {
        var parameters = values
        parameters["action"] = action
        if let plan {
            parameters["sessionID"] = plan.sessionID
            parameters["expectedContextVersion"] = plan.contextVersion
        }
        let response = try PreviewNavigation.response(path: "plan.php", method: "POST", parameters: parameters)
        return try NavigationCoding.decoder().decode(NavigationPlan.self, from: response["data"].rawData())
    }
    static func main() async throws {
        let document = PreviewNavigation.document
        try Camap.validate(document)
        let plan = try send("start")
        check(plan.hasRoute, "The actual bundled map has a route")
        check(plan.schedule?.location == "1号教学楼 1201室", "The class is 1201")
        check(plan.destination?.placeID == PreviewNavigation.destinationID, "The course resolves to teaching building one")
        check(plan.suggestions.first?.name == "库迪咖啡", "Cudi is the feasible recommended stop")
        check(plan.decisions.contains { $0.reasonCode == "insufficient_time" }, "The longer coffee detour is rejected for insufficient margin")
        let blocked = Set(plan.overlays.flatMap(\.affectedEdgeIDs))
        check(!blocked.isEmpty && blocked.isDisjoint(with: plan.route!.edges), "The scenario construction edge is actually excluded")
        check(plan.sources.first?.announceID == 3, "The closure links to the original construction notice")
        let suggestion = plan.suggestions[0]
        check(blocked.isDisjoint(with: suggestion.route.edges), "The suggested detour also avoids construction")
        check(suggestion.dwellSeconds == 120 && suggestion.timing.dwellSeconds == 120, "Pickup includes two minutes dwell")
        check(suggestion.timing.remainingSeconds! >= 0, "Pickup leaves the required arrival buffer")
        check(plan.waypoints.isEmpty, "Previewing never accepts a stop")
        let accepted = try send("accept_suggestion", plan: plan, values: ["suggestionID": suggestion.id])
        check(accepted.waypoints.count == 1 && accepted.waypoints[0].placeID == suggestion.placeID, "Acceptance inserts the chosen coffee stop")
        check(accepted.route?.legs.count == 2, "The accepted itinerary has one leg per destination")
        check(abs(accepted.route!.distanceMeters - suggestion.route.distanceMeters) < 0.01, "Accepted geometry matches the preview")
        check(accepted.timing?.totalSeconds == suggestion.timing.totalSeconds, "Comparison and acceptance use the same demo session clock")
        check(accepted.suggestions.isEmpty, "Accepting doesn't keep suggesting more coffee")
        check(blocked.isDisjoint(with: accepted.route!.edges), "The accepted route still avoids construction")
        do {
            _ = try send("accept_suggestion", plan: plan, values: ["suggestionID": suggestion.id])
            fatalError("A stale context was accepted")
        } catch let error as APIClientError { check(error.statusCode == 409, "Stale acceptance is rejected") }
        let removed = try send("remove_stop", plan: accepted, values: ["stopID": accepted.waypoints[0].id])
        check(removed.waypoints.isEmpty && abs(removed.route!.distanceMeters - plan.route!.distanceMeters) < 0.01, "Removing restores the direct route")
        let disabled = try send("set_recommendations", plan: removed, values: ["recommendationsEnabled": false])
        check(!disabled.recommendationsEnabled && disabled.suggestions.isEmpty, "The recommendation switch is respected")
        let requested = try send("evaluate_optional_stop", plan: disabled, values: ["request": "顺路取咖啡"])
        check(requested.suggestions.first?.source == "requested", "An explicit request works with proactive recommendations off")
        let bakery = try send("start", values: ["destination": PreviewNavigation.bakeryID])
        check(bakery.hasRoute && bakery.destination?.name == "山麦烘焙", "The independent bakery flow uses its own destination")
        check(bakery.schedule == nil && bakery.waypoints.isEmpty && bakery.suggestions.isEmpty, "The bakery session has no leftover course or stops")
        let geometry = NavigationGuidanceGeometry(points: [Point(0, 0), Point(100, 0), Point(100, 50)])
        check(geometry.sample(at: 50)?.instruction == "左转", "Positive northward turns are left turns")
        check(geometry.sample(at: 50)?.distanceToTurn == 50, "The turn distance follows the line")
        check(geometry.sample(at: 120)?.position == Point(100, 20), "The arrow follows the next segment")
        check(geometry.nextVertex(after: 0) == 100, "Manual advance moves to the next vertex")
        check(geometry.projectedProgress(of: Point(40, 3), after: 0)?.progress == 40, "GPS projects to the route without inserting a fake position")
        let right = NavigationGuidanceGeometry(points: [Point(0, 0), Point(100, 0), Point(100, -50)])
        check(right.sample(at: 50)?.instruction == "右转", "Southward turns are right turns")
        try await playback()
        print("Demo navigation checks passed: \(count)")
    }
    static func playback() async throws {
        let map = CampusMapStore(client: .init(school: { 1 }, fetch: { _, _ in
            .document(.init(schoolID: 1, document: PreviewNavigation.document, etag: PreviewNavigation.mapETag))
        }))
        let navigation = StudentNavigationStore(client: .init(send: { command in
            let parameters = try JSONSerialization.jsonObject(with: JSONEncoder().encode(command)) as! [String: Any]
            let json = try PreviewNavigation.response(path: "plan.php", method: "POST", parameters: parameters)
            if command.action == .end { return .ended(sessionID: command.sessionID!) }
            return .plan(try NavigationCoding.decoder().decode(NavigationPlan.self, from: json["data"].rawData()))
        }, feedback: { _ in .init(recorded: false, reasonCode: "history_disabled") }, source: { _ in nil }))
        navigation.bind(userID: 1)
        let preview = RoutePreviewStore(navigation: navigation, map: map)
        preview.bind(userID: 1); preview.open(.nextCourse)
        await preview.prepare()
        check(navigation.plan?.hasRoute == true && !preview.isSelectingOrigin, "Demo starts from the fixed dorm without GPS selection")
        await navigation.acceptSuggestion(navigation.plan!.suggestions[0].id)
        preview.startGuidance()
        check(preview.isGuiding && preview.isPlaying, "Start enables the shared guidance UI and Demo playback")
        try await Task.sleep(for: .milliseconds(250))
        check(preview.guidanceDistance > 0, "The arrow advances automatically along the route")
        preview.pausePlayback()
        let pausedDistance = preview.guidanceDistance
        try await Task.sleep(for: .milliseconds(150))
        check(preview.guidanceDistance == pausedDistance && !preview.isPlaying, "Pause freezes progress")
        for _ in 0..<200 where !preview.waitingAtStop { preview.nextGuidanceStep() }
        check(preview.waitingAtStop && !preview.isPlaying && preview.nextStop?.name == "库迪咖啡", "Playback stops at the actual first leg endpoint for pickup")
        preview.continueFromStop(); preview.pausePlayback()
        check(preview.completedStops == 1 && !preview.waitingAtStop, "Continuing acknowledges pickup once")
        for _ in 0..<200 where !preview.hasArrived { preview.nextGuidanceStep() }
        check(preview.hasArrived && !preview.isPlaying, "Manual advance reaches the final destination and stops")
        preview.startGuidance(); preview.pausePlayback()
        check(preview.guidanceDistance == 0 && preview.completedStops == 0 && !preview.hasArrived, "Replay resets the arrow and waypoint state")
        preview.close()
        check(!preview.isGuiding && !preview.isPlaying && navigation.plan == nil, "Closing cancels playback and clears the route")
    }

}
