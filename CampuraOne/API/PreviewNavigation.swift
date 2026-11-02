#if DEBUG
import Foundation
import SwiftyJSON
import CamapKit
import CryptoKit

/// In-memory Canvas data. Never used as a fallback for a real account/server error.
@MainActor
enum PreviewNavigation {
    static let frameID = "10000000-0000-4000-8000-000000000001"
    static let merchantID = "10000000-0000-4000-8000-000000000024"
    private static var previewOriginID = "10000000-0000-4000-8000-000000000002"
    private static var previewDestinationID = "10000000-0000-4000-8000-000000000022"
    private static var usesCourse = true
    static let startID = "10000000-0000-4000-8000-000000000002"
    static let destinationID = "10000000-0000-4000-8000-000000000022"
    private static var preferences = NavigationPreferences.initial
    private static var sessionID = UUID().uuidString.lowercased()
    private static var contextVersion = 0

    static var document: CamapDocument {
        let uncalibrated = ProcessInfo.processInfo.arguments.contains("--campura-preview-uncalibrated")
        let frame = SpatialFrame(id: frameID, name: "校园", bindings: uncalibrated ? [:] : [
            "mapkit": CamapKit.Binding(longitude: 114.4, latitude: 30.4)
        ])
        return CamapDocument(id: "10000000-0000-4000-8000-000000000099", title: "校园地图", frames: [frame], features: [
            Feature(id: destinationID, frameId: frameID, kind: "building", name: "教学楼",
                    geometry: .polygon([Point(120, 120), Point(210, 120), Point(210, 180), Point(120, 180)])),
            Feature(id: "10000000-0000-4000-8000-000000000020", frameId: frameID, kind: "building", name: "图书馆",
                    geometry: .polygon([Point(35, 35), Point(105, 35), Point(105, 100), Point(35, 100)])),
            Feature(id: "10000000-0000-4000-8000-000000000024", frameId: frameID, kind: "merchant", name: "校园咖啡",
                    geometry: .point(Point(80, -40))),
            Feature(id: "10000000-0000-4000-8000-000000000026", frameId: frameID, kind: "door", name: "咖啡窗口室外入口",
                    geometry: .point(Point(80, -40)), exterior: true),
            Feature(id: "10000000-0000-4000-8000-000000000025", frameId: frameID, kind: "building", name: "宿舍楼17栋",
                    geometry: .polygon([Point(-50, -100), Point(20, -100), Point(20, -50), Point(-50, -50)]))
        ], nodes: [
            RouteNode(id: "10000000-0000-4000-8000-000000000006", frameId: frameID, position: Point(80, -40), name: "咖啡窗口入口", entranceId: "10000000-0000-4000-8000-000000000026"),
            RouteNode(id: startID, frameId: frameID, position: Point(0, 0), name: "生活区路口"),
            RouteNode(id: "10000000-0000-4000-8000-000000000003", frameId: frameID, position: Point(140, 0), name: "教学路口"),
            RouteNode(id: "10000000-0000-4000-8000-000000000004", frameId: frameID, position: Point(140, 120), name: "教学楼前")
        ], edges: [
            RouteEdge(id: "10000000-0000-4000-8000-000000000032", frameId: frameID, from: startID, to: "10000000-0000-4000-8000-000000000006", name: "咖啡步道"),
            RouteEdge(id: "10000000-0000-4000-8000-000000000030", frameId: frameID,
                      from: startID, to: "10000000-0000-4000-8000-000000000003", name: "校园路"),
            RouteEdge(id: "10000000-0000-4000-8000-000000000031", frameId: frameID,
                      from: "10000000-0000-4000-8000-000000000003", to: "10000000-0000-4000-8000-000000000004", name: "教学路")
        ])
    }

    static var mapETag: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = (try? encoder.encode(document)) ?? Data()
        return "\"" + SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() + "\""
    }

    static func response(path: String, method: String, parameters: [String: Any]) throws -> JSON {
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
            if action == "start" { contextVersion = 0; sessionID = UUID().uuidString.lowercased() }
            else if parameters["sessionID"] as? String != sessionID
                        || parameters["expectedContextVersion"] as? Int != contextVersion {
                throw APIClientError.server(statusCode: 409, code: 409, message: "路线状态已更新")
            }
            if action == "end" { data = ["sessionID": sessionID, "ended": true] }
            else {
                contextVersion += 1
                if let value = parameters["destination"] as? String {
                    usesCourse = value.isEmpty
                    previewDestinationID = value.isEmpty ? destinationID : value
                } else if action == "start" { usesCourse = true; previewDestinationID = destinationID }
                if let origin = parameters["origin"] as? [String: Any], let id = origin["nodeID"] as? String { previewOriginID = id }
                data = previewPlan()

            }
        default: throw APIClientError.invalidResponse
        }
        return JSON(["code": 200, "message": "Local preview data", "data": data])
    }

    private static func previewPlan() -> [String: Any] {
        let doc = document
        let nodes = Dictionary(uniqueKeysWithValues: doc.nodes.map { ($0.id, $0) })
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
        let points = chain.reversed().compactMap { nodes[$0]?.position }
        let distance = zip(points, points.dropFirst()).reduce(0.0) { $0 + hypot($1.0.x - $1.1.x, $1.0.y - $1.1.y) }
        var coordinates = points.map { [$0.x, $0.y] }
        if coordinates.count == 1 { coordinates.append(coordinates[0]) }
        let seconds = Int(ceil(distance / 1.2))
        let now = Date()
        let iso = NavigationCoding.iso
        let timing: [String: Any] = ["departureTime": iso(now), "walkingSeconds": seconds,
            "dwellSeconds": 0, "totalSeconds": seconds, "estimatedArrival": iso(now.addingTimeInterval(Double(seconds))),
            "arrivalRange": [iso(now.addingTimeInterval(distance / 1.4)), iso(now.addingTimeInterval(distance))],
            "conservativeArrival": iso(now.addingTimeInterval(distance)), "latestArrival": usesCourse ? iso(now.addingTimeInterval(3300)) : NSNull(),
            "remainingSeconds": usesCourse ? 3300 - Int(distance) : NSNull(), "late": false, "isEstimate": true]
        let route: [String: Any] = ["frameId": frameID,
            "origin": ["frameId": frameID, "position": coordinates.first ?? [0, 0]],
            "polyline": coordinates, "distanceMeters": distance, "edges": Array(edges.reversed()),
            "legs": [["frameId": frameID, "nodes": Array(chain.reversed()), "edges": Array(edges.reversed()),
                      "polyline": coordinates, "distanceMeters": distance]]]
        let feature = doc.features.first { $0.id == previewDestinationID }
        let overlay: [String: Any] = ["targetID": "10000000-0000-4000-8000-000000000020", "name": "图书馆东侧施工",
            "frameId": frameID, "geometry": ["type": "polygon", "coordinates": [[35, 35], [105, 35], [105, 100], [35, 100]]],
            "kind": "construction", "nature": "advice", "avoidanceStatus": reachable ? "avoided" : "route_unavailable",
            "sourceID": 1, "sourceVersion": 1, "evidence": "图书馆东门施工，请从南门通行。", "endUnknown": true, "affectedEdgeIDs": []]
        return ["sessionID": sessionID, "contextVersion": contextVersion, "planID": UUID().uuidString,
            "mapRevision": 1, "mapHash": mapETag.trimmingCharacters(in: CharacterSet(charactersIn: "\"")),
            "status": reachable ? "ready" : "unreachable", "route": reachable ? route : NSNull(),
            "timing": reachable ? timing : NSNull(),
            "destination": ["placeID": previewDestinationID, "name": feature?.name ?? nodes[endpoint]?.name ?? "校园地点", "kind": feature?.kind ?? "node"],
            "schedule": usesCourse ? ["uid": "preview-course", "title": "下一节课", "location": "教学楼", "startAt": now.addingTimeInterval(3600).timeIntervalSince1970,
                                      "endAt": now.addingTimeInterval(7200).timeIntervalSince1970, "tableID": 1, "tableVersion": 1] : NSNull(),
            "waypoints": [], "suggestions": [], "overlays": [overlay],
            "sources": [["announceID": 1, "version": 1, "title": "图书馆东门施工通知", "publishedAt": iso(now.addingTimeInterval(-86400)),
                         "excerpt": "图书馆东门施工，请从南门通行。"]],
            "decisions": [], "warnings": [], "aiStatus": "disabled", "modelDisplayName": "通义千问", "recommendationsEnabled": false]
    }

    private static func object<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }
}
#endif
