#if DEBUG
import Foundation
import SwiftyJSON
import CamapKit
import CryptoKit

/// In-memory Canvas data. Never used as a fallback for a real account/server error.
@MainActor
enum PreviewNavigation {
    static let frameID = "10000000-0000-4000-8000-000000000001"
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
            Feature(id: "10000000-0000-4000-8000-000000000025", frameId: frameID, kind: "building", name: "宿舍楼17栋",
                    geometry: .polygon([Point(-50, -100), Point(20, -100), Point(20, -50), Point(-50, -50)]))
        ], nodes: [
            RouteNode(id: startID, frameId: frameID, position: Point(0, 0), name: "生活区路口"),
            RouteNode(id: "10000000-0000-4000-8000-000000000003", frameId: frameID, position: Point(140, 0), name: "教学路口"),
            RouteNode(id: "10000000-0000-4000-8000-000000000004", frameId: frameID, position: Point(140, 120), name: "教学楼前")
        ], edges: [
            RouteEdge(id: "10000000-0000-4000-8000-000000000030", frameId: frameID,
                      from: startID, to: "10000000-0000-4000-8000-000000000003", name: "校园路"),
            RouteEdge(id: "10000000-0000-4000-8000-000000000031", frameId: frameID,
                      from: "10000000-0000-4000-8000-000000000003", to: "10000000-0000-4000-8000-000000000004", name: "教学路")
        ])
    }

    static var mapETag: String {
        let data = (try? JSONEncoder().encode(document)) ?? Data()
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
                let origin: [String: Any] = ["frameId": frameID, "position": [0, 0]]
                let route: [String: Any] = ["frameId": frameID, "origin": origin,
                    "polyline": [[0, 0], [140, 0], [140, 120]], "distanceMeters": 260,
                    "edges": [], "legs": [["frameId": frameID, "nodes": [], "edges": [],
                        "polyline": [[0, 0], [140, 0], [140, 120]], "distanceMeters": 260]]]
                let iso = NavigationCoding.iso
                let now = Date()
                let timing: [String: Any] = ["departureTime": iso(now), "walkingSeconds": 217,
                    "dwellSeconds": 0, "totalSeconds": 217, "estimatedArrival": iso(now.addingTimeInterval(217)),
                    "arrivalRange": [iso(now.addingTimeInterval(186)), iso(now.addingTimeInterval(260))],
                    "conservativeArrival": iso(now.addingTimeInterval(260)), "latestArrival": NSNull(),
                    "remainingSeconds": NSNull(), "late": false, "isEstimate": true]
                data = ["sessionID": sessionID, "contextVersion": contextVersion, "planID": UUID().uuidString,
                        "mapRevision": 1, "mapHash": mapETag.trimmingCharacters(in: CharacterSet(charactersIn: "\"")),
                        "status": "ready", "route": route, "timing": timing,
                        "destination": ["placeID": destinationID, "name": "教学楼", "kind": "building", "category": "other"],
                        "schedule": NSNull(), "waypoints": [], "suggestions": [], "overlays": [], "sources": [],
                        "decisions": [], "warnings": [], "aiStatus": "unavailable", "modelDisplayName": "通义千问",
                        "recommendationsEnabled": parameters["recommendationsEnabled"] as? Bool ?? preferences.recommendationsEnabled]
            }
        default: throw APIClientError.invalidResponse
        }
        return JSON(["code": 200, "message": "Local preview data", "data": data])
    }

    private static func object<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }
}
#endif
