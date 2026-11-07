#if DEBUG
import Foundation
import SwiftyJSON
import CamapKit
import CryptoKit

/// In-memory Canvas data. Never used as a fallback for a real account/server error.
@MainActor
enum PreviewNavigation {
    static let constructionNoticeText = "教学楼附近校园步道正在施工，围挡路段临时封闭，请按地图绕行。勿穿越围挡或从施工入口通行，注意安全。"
    #if DEMO
    private static let bundledDocument: Result<CamapDocument, Error> = Result {
        guard let url = Bundle.main.url(forResource: "school-1-v2", withExtension: "camap") else {
            throw APIClientError.invalidPayload("未找到本地校园地图")
        }
        return try Camap.read(from: url)
    }
    static var frameID: String { (try? bundledDocument.get().frames.first?.id) ?? "" }
    #else
    static let frameID = "10000000-0000-4000-8000-000000000001"
    #endif
    static let merchantID = "10000000-0000-4000-8000-000000000024"
    #if DEMO
    static var startID: String { closestNode(to: "学生宿舍17栋")?.id ?? "" }
    static var destinationID: String { feature(named: "1号教学楼")?.id ?? "" }
    static var bakeryID: String { feature(named: "山麦烘焙")?.id ?? "" }
    private static var demoDeparture = Date()
    static var demoClassStart: Date { demoDeparture.addingTimeInterval(15 * 60) }
    // A local scenario closure, not a surveyed change to the CAMAP document.
    private static let constructionEdgeID = "a1462eea-4f86-4f47-84bb-c55034afe4c8"
    private static var fixedStops: [[String: Any]] = []
    private static var candidates: [[String: Any]] = []
    private static var recommendationsEnabled = true
    private static var requestedCoffee = false
    private static var previewOriginID = ""
    private static var previewDestinationID = ""
    #else
    private static var previewOriginID = "10000000-0000-4000-8000-000000000002"
    private static var previewDestinationID = "10000000-0000-4000-8000-000000000022"
    static let startID = "10000000-0000-4000-8000-000000000002"
    static let destinationID = "10000000-0000-4000-8000-000000000022"
    #endif
    static var placePreviewID: String {
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--campura-preview-place"), arguments.indices.contains(index + 1),
           document.features.contains(where: { $0.id == arguments[index + 1] }) { return arguments[index + 1] }
        #if DEMO
        return document.features.first(where: { $0.id == bakeryID })?.buildingId ?? bakeryID
        #else
        return destinationID
        #endif
    }

    private static var usesCourse = true
    private static var preferences = NavigationPreferences.initial
    private static var sessionID = UUID().uuidString.lowercased()
    private static var contextVersion = 0

    static var document: CamapDocument {
        #if DEMO
        // Loading failures are surfaced by response(), never replaced with the old map.
        return (try? bundledDocument.get()) ?? CamapDocument(title: "校园地图")
        #else
        let uncalibrated = ProcessInfo.processInfo.arguments.contains("--campura-preview-uncalibrated")
        let frame = SpatialFrame(id: frameID, name: "校园", bindings: uncalibrated ? [:] : [
            "mapkit": CamapKit.Binding(longitude: 114.4, latitude: 30.4)
        ])
        return CamapDocument(id: "10000000-0000-4000-8000-000000000099", title: "校园地图", masterId: "10000000-0000-4000-8000-000000000099", baseRevision: 1, frames: [frame], features: [
            Feature(id: destinationID, frameId: frameID, kind: "building", name: "教学楼",
                    geometry: .polygon([Point(120, 120), Point(210, 120), Point(210, 180), Point(120, 180)])),
            Feature(id: "10000000-0000-4000-8000-000000000020", frameId: frameID, kind: "building", name: "图书馆",
                    geometry: .polygon([Point(35, 35), Point(105, 35), Point(105, 100), Point(35, 100)])),
            Feature(id: "10000000-0000-4000-8000-000000000024", frameId: frameID, kind: "merchant", name: "校园咖啡",
                    geometry: .point(Point(80, -40))),
            Feature(id: "10000000-0000-4000-8000-000000000026", frameId: frameID, kind: "door", name: "咖啡窗口室外入口",
                    geometry: .point(Point(80, -40)), exterior: true),
            Feature(id: "10000000-0000-4000-8000-000000000025", frameId: frameID, kind: "building", name: "宿舍楼17栋",
                    geometry: .polygon([Point(-50, -100), Point(20, -100), Point(20, -50), Point(-50, -50)])),
            Feature(id: "10000000-0000-4000-8000-000000000027", frameId: frameID, kind: "building", name: "学生活动中心",
                    geometry: .polygon([Point(-60, 100), Point(-10, 100), Point(-10, 150), Point(-60, 150)])),
            Feature(id: "10000000-0000-4000-8000-000000000028", frameId: frameID, kind: "building", name: "操场",
                    geometry: .polygon([Point(-140, -20), Point(-70, -20), Point(-70, 70), Point(-140, 70)]))
        ], nodes: [
            RouteNode(id: "10000000-0000-4000-8000-000000000006", frameId: frameID, position: Point(80, -40), name: "咖啡窗口入口", entranceId: "10000000-0000-4000-8000-000000000026"),
            RouteNode(id: startID, frameId: frameID, position: Point(0, 0), name: "生活区路口"),
            RouteNode(id: "10000000-0000-4000-8000-000000000003", frameId: frameID, position: Point(140, 0), name: "教学路口"),
            RouteNode(id: "10000000-0000-4000-8000-000000000004", frameId: frameID, position: Point(140, 120), name: "教学楼前"),
            RouteNode(id: "10000000-0000-4000-8000-000000000027", frameId: frameID, position: Point(-35, 100), name: "学生活动中心"),
            RouteNode(id: "10000000-0000-4000-8000-000000000028", frameId: frameID, position: Point(-70, 20), name: "操场")
        ], edges: [
            RouteEdge(id: "10000000-0000-4000-8000-000000000032", frameId: frameID, from: startID, to: "10000000-0000-4000-8000-000000000006", name: "咖啡步道"),
            RouteEdge(id: "10000000-0000-4000-8000-000000000030", frameId: frameID,
                      from: startID, to: "10000000-0000-4000-8000-000000000003", name: "校园路"),
            RouteEdge(id: "10000000-0000-4000-8000-000000000031", frameId: frameID,
                      from: "10000000-0000-4000-8000-000000000003", to: "10000000-0000-4000-8000-000000000004", name: "教学路"),
            RouteEdge(id: "10000000-0000-4000-8000-000000000033", frameId: frameID,
                      from: startID, to: "10000000-0000-4000-8000-000000000027", name: "活动中心步道"),
            RouteEdge(id: "10000000-0000-4000-8000-000000000034", frameId: frameID,
                      from: startID, to: "10000000-0000-4000-8000-000000000028", name: "操场步道")
        ])
        #endif
    }

    static var mapETag: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(document)) ?? Data()
        return "\"" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() + "\""
    }

    static func response(path: String, method: String, parameters: [String: Any]) throws -> JSON {
        #if DEMO
        _ = try bundledDocument.get()
        if path == "plan.php", parameters["action"] as? String != "end", document.nodes.isEmpty || document.edges.isEmpty {
            throw APIClientError.invalidPayload("本地校园地图尚未包含可通行路网，暂时无法规划路线。")
        }
        #endif
        let data: Any
        switch path {
        case "campus_map.php": data = try object(document)
        case "preferences.php":
            if method == "PATCH" {
                guard parameters["expectedVersion"] as? Int == preferences.version else {
                    throw APIClientError.server(statusCode: 409, code: 409, message: "设置已更新")
                }
                var values = try object(preferences) as! [String: Any]
                for (key, value) in parameters where key != "expectedVersion" { values[key] = value }
                values["version"] = preferences.version + 1
                preferences = try NavigationCoding.decoder().decode(NavigationPreferences.self, from: JSONSerialization.data(withJSONObject: values))
            }
            data = try object(preferences)
        case "feedback.php":
            if method == "DELETE" { preferences.version += 1; data = ["cleared": true] }
            else { data = ["recorded": preferences.historyEnabled, "reasonCode": preferences.historyEnabled ? "recorded" : "history_disabled"] }
        case "plan.php":
            let action = parameters["action"] as? String ?? ""
            if action == "start" {
                contextVersion = 0; sessionID = UUID().uuidString.lowercased()
                previewOriginID = startID
                previewDestinationID = destinationID
                #if DEMO
                fixedStops = []; candidates = []; requestedCoffee = false; demoDeparture = Date()
                recommendationsEnabled = parameters["recommendationsEnabled"] as? Bool ?? preferences.recommendationsEnabled
                #endif
            }
            else if parameters["sessionID"] as? String != sessionID
                        || parameters["expectedContextVersion"] as? Int != contextVersion {
                throw APIClientError.server(statusCode: 409, code: 409, message: "路线状态已更新")
            }
            if action == "end" { data = ["sessionID": sessionID, "ended": true] }
            else {
                #if DEMO
                try applyDemoAction(action, parameters: parameters)
                #endif
                contextVersion += 1
                if let value = parameters["destination"] as? String {
                    usesCourse = value.isEmpty
                    previewDestinationID = value.isEmpty ? destinationID : value
                } else if action == "start" { usesCourse = true; previewDestinationID = destinationID }
                if let origin = parameters["origin"] as? [String: Any], let id = origin["nodeID"] as? String { previewOriginID = id }
                #if DEMO
                data = demoPlan()
                #else
                data = previewPlan()
                #endif

            }
        default: throw APIClientError.invalidResponse
        }
        return JSON(["code": 200, "message": "Local preview data", "data": data])
    }

    private static func previewPlan() -> [String: Any] {
        let doc = document
        let nodes = Dictionary(uniqueKeysWithValues: doc.nodes.map { ($0.id, $0) })
        #if DEMO
        let feature = doc.features.first { $0.id == previewDestinationID }
        let endpoint = feature.flatMap { closestNode(to: $0)?.id } ?? previewDestinationID
        let (chain, edges) = shortestPath(from: previewOriginID, to: endpoint)
        let reachable = chain.count >= 2 && chain.first == previewOriginID && chain.last == endpoint
        #else
        let endpoint = previewDestinationID == destinationID ? "10000000-0000-4000-8000-000000000004"
            : previewDestinationID == merchantID ? "10000000-0000-4000-8000-000000000006" : previewDestinationID
        var queue = [previewOriginID]
        var visited = Set(queue)
        var previous: [String: (String, String)] = [:]
        while !queue.isEmpty {
            let node = queue.removeFirst()
            for edge in doc.edges where !edge.closed && (edge.from == node || edge.to == node) {
                let next = edge.from == node ? edge.to : edge.from
                if visited.insert(next).inserted { previous[next] = (node, edge.id); queue.append(next) }
            }
        }
        var chain = [endpoint], edges: [String] = []
        while let entry = previous[chain.last!] { chain.append(entry.0); edges.append(entry.1) }
        let reachable = nodes[endpoint] != nil && chain.last == previewOriginID
        chain.reverse(); edges.reverse()
        #endif
        let points = chain.compactMap { nodes[$0]?.position }
        let distance = zip(points, points.dropFirst()).reduce(0.0) { $0 + hypot($1.0.x - $1.1.x, $1.0.y - $1.1.y) }
        var coordinates = points.map { [$0.x, $0.y] }
        if coordinates.count == 1 { coordinates.append(coordinates[0]) }
        let seconds = Int(ceil(distance / 1.2))
        let now = Date()
        #if DEMO
        let classStart = demoClassStart
        let classTitle = "软件工程"
        let classLocation = "1号教学楼 1201室"
        #else
        let classStart = now.addingTimeInterval(3600)
        let classTitle = "下一节课"
        let classLocation = "教学楼"
        #endif
        let iso = NavigationCoding.iso
        let timing: [String: Any] = ["departureTime": iso(now), "walkingSeconds": seconds,
            "dwellSeconds": 0, "totalSeconds": seconds, "estimatedArrival": iso(now.addingTimeInterval(Double(seconds))),
            "arrivalRange": [iso(now.addingTimeInterval(distance / 1.4)), iso(now.addingTimeInterval(distance))],
            "conservativeArrival": iso(now.addingTimeInterval(distance)), "latestArrival": usesCourse ? iso(classStart) : NSNull(),
            "remainingSeconds": usesCourse ? Int(classStart.timeIntervalSince(now)) - Int(distance) : NSNull(),
            "late": usesCourse && classStart.timeIntervalSince(now) < distance, "isEstimate": true]
        let route: [String: Any] = ["frameId": frameID,
            "origin": ["frameId": frameID, "position": coordinates.first ?? [0, 0]],
            "polyline": coordinates, "distanceMeters": distance, "edges": edges,
            "legs": [["frameId": frameID, "nodes": chain, "edges": edges,
                      "polyline": coordinates, "distanceMeters": distance]]]
        #if !DEMO
        let feature = doc.features.first { $0.id == previewDestinationID }
        #endif
        #if DEMO
        let overlays: [[String: Any]] = []
        let sources: [[String: Any]] = []
        let warnings: [[String: Any]] = reachable ? [["code": "missing_entrance"]] : []
        #else
        let overlay: [String: Any] = ["targetID": destinationID, "name": "教学楼施工区域",
            "frameId": frameID, "geometry": ["type": "polygon", "coordinates": [[120, 120], [210, 120], [210, 180], [120, 180]]],
            "kind": "construction", "nature": "advice", "avoidanceStatus": reachable ? "avoided" : "route_unavailable",
            "sourceID": 3, "sourceVersion": 1, "evidence": constructionNoticeText, "endUnknown": true, "affectedEdgeIDs": []]
        let overlays = [overlay]
        let sources: [[String: Any]] = [["announceID": 3, "version": 1, "title": "教学楼施工安全提醒", "publishedAt": iso(now.addingTimeInterval(-86400)),
                                        "excerpt": "教学楼附近正在施工，请绕行围挡区域。"]]
        let warnings: [[String: Any]] = []
        #endif
        return ["sessionID": sessionID, "contextVersion": contextVersion, "planID": UUID().uuidString,
            "mapRevision": doc.frames.first?.revision ?? 1, "mapHash": mapETag.trimmingCharacters(in: CharacterSet(charactersIn: "\"")),
            "status": reachable ? "ready" : "unreachable", "route": reachable ? route : NSNull(),
            "timing": reachable ? timing : NSNull(),
            "destination": ["placeID": previewDestinationID, "name": feature?.name ?? nodes[endpoint]?.name ?? "校园地点", "kind": feature?.kind ?? "node"],
            "schedule": usesCourse ? ["uid": "preview-course", "title": classTitle, "location": classLocation,
                                      "startAt": classStart.timeIntervalSince1970,
                                      "endAt": classStart.addingTimeInterval(5400).timeIntervalSince1970,
                                      "tableID": 1, "tableVersion": 1] : NSNull(),
            "waypoints": [], "suggestions": [], "overlays": overlays,
            "sources": sources,
            "decisions": [], "warnings": warnings, "aiStatus": "disabled", "modelDisplayName": "通义千问", "recommendationsEnabled": false]
    }

    #if DEMO
    private static func applyDemoAction(_ action: String, parameters: [String: Any]) throws {
        switch action {
        case "accept_suggestion":
            guard let id = parameters["suggestionID"] as? String,
                  let candidate = candidates.first(where: { $0["suggestionID"] as? String == id }),
                  candidate["contextVersion"] as? Int == contextVersion,
                  let expiry = candidate["expiresAt"] as? String,
                  let date = APIDate.parse(expiry), date > Date(),
                  let placeID = candidate["placeID"] as? String else {
                throw APIClientError.server(statusCode: 409, code: 409, message: "推荐已更新，请重新规划")
            }
            addDemoStop(placeID, seconds: candidate["dwellSeconds"] as? Int ?? 120, source: "accepted")
        case "add_fixed_stop":
            if let id = parameters["placeID"] as? String {
                addDemoStop(id, seconds: Int((parameters["dwellMinutes"] as? Double ?? 2) * 60), source: "manual")
            }
        case "remove_stop": fixedStops.removeAll { $0["stopID"] as? String == parameters["stopID"] as? String }
        case "set_recommendations": recommendationsEnabled = parameters["recommendationsEnabled"] as? Bool ?? true
        case "evaluate_optional_stop": requestedCoffee = true
        default: break
        }
    }

    private static func addDemoStop(_ id: String, seconds: Int, source: String) {
        guard let place = document.features.first(where: { $0.id == id }),
              !fixedStops.contains(where: { $0["placeID"] as? String == id }) else { return }
        fixedStops.append(["stopID": UUID().uuidString, "placeID": id, "name": place.name,
                           "category": "coffee", "source": source, "dwellSeconds": seconds,
                           "dwellRangeSeconds": [seconds, seconds]])
    }

    private static func demoRoute(via stops: [[String: Any]]) -> [String: Any]? {
        let doc = document
        let nodes = Dictionary(uniqueKeysWithValues: doc.nodes.map { ($0.id, $0) })
        let destinations = stops.compactMap { $0["placeID"] as? String } + [previewDestinationID]
        var current = previewOriginID
        var allPoints: [Point] = [], allEdges: [String] = [], legs: [[String: Any]] = []
        var distance = 0.0
        for id in destinations {
            let end = doc.features.first(where: { $0.id == id }).flatMap { closestNode(to: $0)?.id } ?? id
            let (chain, edges) = shortestPath(from: current, to: end, blocked: [constructionEdgeID])
            guard chain.first == current, chain.last == end else { return nil }
            var points = chain.compactMap { nodes[$0]?.position }
            if points.count == 1 { points.append(points[0]) }
            let length = zip(points, points.dropFirst()).reduce(0.0) { $0 + hypot($1.0.x - $1.1.x, $1.0.y - $1.1.y) }
            legs.append(["frameId": frameID, "nodes": chain, "edges": edges,
                         "polyline": points.map { [$0.x, $0.y] }, "distanceMeters": length])
            allPoints += allPoints.isEmpty ? points : Array(points.dropFirst())
            allEdges += edges; distance += length; current = end
        }
        guard let first = allPoints.first else { return nil }
        return ["frameId": frameID, "origin": ["frameId": frameID, "position": [first.x, first.y]],
                "polyline": allPoints.map { [$0.x, $0.y] }, "distanceMeters": distance,
                "edges": allEdges, "legs": legs]
    }

    private static func demoTiming(route: [String: Any], stops: [[String: Any]], now: Date) -> [String: Any] {
        let distance = route["distanceMeters"] as? Double ?? 0
        let walking = Int(ceil(distance / max(0.5, preferences.walkingSpeed)))
        let dwell = stops.reduce(0) { $0 + ($1["dwellSeconds"] as? Int ?? 0) }
        let total = walking + dwell
        let conservative = max(walking, Int(ceil(distance))) + dwell
        let deadline = demoClassStart.addingTimeInterval(-preferences.arrivalBufferMinutes * 60)
        let remaining = Int(deadline.timeIntervalSince(now)) - conservative
        return ["departureTime": NavigationCoding.iso(now), "walkingSeconds": walking,
                "dwellSeconds": dwell, "totalSeconds": total,
                "estimatedArrival": NavigationCoding.iso(now.addingTimeInterval(Double(total))),
                "arrivalRange": [NavigationCoding.iso(now.addingTimeInterval(Double(total))), NavigationCoding.iso(now.addingTimeInterval(Double(conservative)))],
                "conservativeArrival": NavigationCoding.iso(now.addingTimeInterval(Double(conservative))),
                "latestArrival": usesCourse ? NavigationCoding.iso(deadline) : NSNull(),
                "remainingSeconds": usesCourse ? remaining : NSNull(),
                "late": usesCourse && remaining < 0, "isEstimate": true]
    }

    private static func demoPlan() -> [String: Any] {
        let now = demoDeparture, planID = UUID().uuidString
        let route = demoRoute(via: fixedStops)
        let timing = route.map { demoTiming(route: $0, stops: fixedStops, now: now) }
        var decisions: [[String: Any]] = []
        candidates = []
        if route != nil, fixedStops.isEmpty, (usesCourse && recommendationsEnabled || requestedCoffee) {
            for name in ["库迪咖啡", "瑞幸咖啡"] {
                guard let place = feature(named: name) else { continue }
                let stop: [String: Any] = ["placeID": place.id, "dwellSeconds": 120]
                guard let alternative = demoRoute(via: [stop]) else { continue }
                let candidateTiming = demoTiming(route: alternative, stops: [stop], now: now)
                let extra = max(0, (candidateTiming["totalSeconds"] as? Int ?? 0) - (timing?["totalSeconds"] as? Int ?? 0))
                if candidateTiming["late"] as? Bool == true {
                    decisions.append(["placeID": place.id, "reasonCode": "insufficient_time", "extraSeconds": extra,
                                      "conservativeArrival": candidateTiming["conservativeArrival"]!])
                    continue
                }
                candidates.append(["suggestionID": UUID().uuidString, "planID": planID, "contextVersion": contextVersion,
                                   "placeID": place.id, "name": name, "category": "coffee", "reasonCode": "fits_schedule",
                                   "source": requestedCoffee ? "requested" : "proactive", "extraSeconds": extra,
                                   "timing": candidateTiming, "route": alternative, "dwellSeconds": 120,
                                   "expiresAt": NavigationCoding.iso(Date().addingTimeInterval(600)), "openingStatus": "unknown"])
            }
            candidates.sort { ($0["extraSeconds"] as? Int ?? 0) < ($1["extraSeconds"] as? Int ?? 0) }
        }
        var overlays: [[String: Any]] = [], sources: [[String: Any]] = []
        if let edge = document.edges.first(where: { $0.id == constructionEdgeID }),
           let a = document.nodes.first(where: { $0.id == edge.from }),
           let b = document.nodes.first(where: { $0.id == edge.to }) {
            overlays = [["targetID": edge.id, "name": "教学楼附近施工路段", "frameId": frameID,
                         "geometry": ["type": "line", "coordinates": [[a.position.x, a.position.y], [b.position.x, b.position.y]]],
                         "kind": "closure", "nature": "restriction", "avoidanceStatus": route == nil ? "route_unavailable" : "excluded",
                         "sourceID": 3, "sourceVersion": 1, "evidence": constructionNoticeText,
                         "endUnknown": true, "affectedEdgeIDs": [edge.id]]]
            sources = [["announceID": 3, "version": 1, "title": "教学楼施工安全提醒",
                        "publishedAt": NavigationCoding.iso(Calendar.current.startOfDay(for: now).addingTimeInterval(-86400 + 120)),
                        "excerpt": constructionNoticeText]]
        }
        let destination = document.features.first { $0.id == previewDestinationID }
        return ["sessionID": sessionID, "contextVersion": contextVersion, "planID": planID,
                "mapRevision": document.frames.first?.revision ?? 1, "mapHash": mapETag.trimmingCharacters(in: CharacterSet(charactersIn: "\"")),
                "status": route == nil ? "unreachable" : "ready", "route": route as Any? ?? NSNull(),
                "timing": timing as Any? ?? NSNull(),
                "destination": ["placeID": previewDestinationID, "name": destination?.name ?? "校园地点", "kind": destination?.kind ?? "node"],
                "schedule": usesCourse ? ["uid": "preview-course", "title": "软件工程", "location": "1号教学楼 1201室",
                                           "startAt": demoClassStart.timeIntervalSince1970, "endAt": demoClassStart.addingTimeInterval(5400).timeIntervalSince1970,
                                           "tableID": 1, "tableVersion": 1] : NSNull(),
                "waypoints": fixedStops, "suggestions": candidates, "decisions": decisions,
                "overlays": overlays, "sources": sources,
                "warnings": route == nil ? [] : [["code": "missing_entrance"]],
                "aiStatus": "cached", "modelDisplayName": "路线推荐", "recommendationsEnabled": recommendationsEnabled]
    }

    private static func feature(named name: String) -> Feature? {
        document.features.first { $0.name == name }
    }

    private static func closestNode(to name: String) -> RouteNode? {
        feature(named: name).flatMap { closestNode(to: $0) }
    }

    private static func closestNode(to feature: Feature) -> RouteNode? {
        let vertices = feature.geometry.points
        guard !vertices.isEmpty else { return nil }
        let center = Point(vertices.map(\.x).reduce(0, +) / Double(vertices.count),
                           vertices.map(\.y).reduce(0, +) / Double(vertices.count))
        return document.nodes.filter { $0.frameId == feature.frameId }.min {
            hypot($0.position.x - center.x, $0.position.y - center.y)
                < hypot($1.position.x - center.x, $1.position.y - center.y)
        }
    }

    private static func shortestPath(from start: String, to end: String, blocked: Set<String> = []) -> ([String], [String]) {
        let nodes = Dictionary(uniqueKeysWithValues: document.nodes.map { ($0.id, $0) })
        guard nodes[start] != nil, nodes[end] != nil else { return ([], []) }
        var unsettled = Set(nodes.keys)
        var distances = [start: 0.0]
        var previous: [String: (String, String)] = [:]
        while let current = unsettled.min(by: { (distances[$0] ?? .infinity) < (distances[$1] ?? .infinity) }),
              let base = distances[current], base.isFinite {
            unsettled.remove(current)
            if current == end { break }
            for edge in document.edges where !edge.closed && !blocked.contains(edge.id) && (edge.from == current || (!edge.oneWay && edge.to == current)) {
                let next = edge.from == current ? edge.to : edge.from
                guard unsettled.contains(next), let a = nodes[current]?.position,
                      let b = nodes[next]?.position else { continue }
                let candidate = base + hypot(a.x - b.x, a.y - b.y)
                if candidate < (distances[next] ?? .infinity) {
                    distances[next] = candidate
                    previous[next] = (current, edge.id)
                }
            }
        }
        guard distances[end] != nil else { return ([], []) }
        var chain = [end], edges: [String] = []
        while let step = previous[chain.last!] {
            chain.append(step.0); edges.append(step.1)
        }
        return (Array(chain.reversed()), Array(edges.reversed()))
    }
    #endif

    private static func object<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }
}
#endif
