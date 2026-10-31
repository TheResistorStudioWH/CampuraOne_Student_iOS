import Foundation
import CamapKit

/// Wire models stay independent of SwiftUI and of the eventual route-panel design.
nonisolated struct NavigationPreferences: Codable, Equatable, Sendable {
    var version: Int
    var recommendationsEnabled: Bool
    var historyEnabled: Bool
    var interests: [String]
    var blockedCategories: [String]
    var walkingSpeed: Double
    var arrivalBufferMinutes: Double
    var accessible: Bool
    var preferCovered: Bool

    static let initial = Self(version: 1, recommendationsEnabled: true, historyEnabled: false,
                              interests: [], blockedCategories: [], walkingSpeed: 1.2,
                              arrivalBufferMinutes: 5, accessible: false, preferCovered: false)
}

nonisolated struct NavigationPreferenceUpdate: Encodable, Sendable {
    var expectedVersion: Int
    var recommendationsEnabled: Bool?
    var historyEnabled: Bool?
    var interests: [String]?
    var blockedCategories: [String]?
    var walkingSpeed: Double?
    var arrivalBufferMinutes: Double?
    var accessible: Bool?
    var preferCovered: Bool?
}

nonisolated enum NavigationOrigin: Encodable, Equatable, Sendable {
    case node(id: String, frameID: String)
    case local(frameID: String, position: Point, accuracyMeters: Double)
    case mapkit(frameID: String, longitude: Double, latitude: Double, accuracyMeters: Double)

    var frameID: String {
        switch self {
        case .node(_, let id), .local(let id, _, _), .mapkit(let id, _, _, _): return id
        }
    }

    private enum Keys: String, CodingKey {
        case nodeID, frameId, position, accuracyMeters, provider, longitude, latitude
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(frameID, forKey: .frameId)
        switch self {
        case .node(let id, _): try c.encode(id, forKey: .nodeID)
        case .local(_, let position, let accuracy):
            try c.encode(position, forKey: .position)
            try c.encode(accuracy, forKey: .accuracyMeters)
        case .mapkit(_, let longitude, let latitude, let accuracy):
            try c.encode("mapkit", forKey: .provider)
            try c.encode(longitude, forKey: .longitude)
            try c.encode(latitude, forKey: .latitude)
            try c.encode(accuracy, forKey: .accuracyMeters)
        }
    }
}

nonisolated struct NavigationCommand: Encodable, Sendable {
    enum Action: String, Encodable, Sendable {
        case start, updateContext = "update_context", evaluateOptionalStop = "evaluate_optional_stop"
        case acceptSuggestion = "accept_suggestion", addFixedStop = "add_fixed_stop"
        case removeStop = "remove_stop", setRecommendations = "set_recommendations", replan, end
    }
    var action: Action
    var sessionID: String?
    var expectedContextVersion: Int?
    var origin: NavigationOrigin?
    /// Empty string returns to the next-course destination; nil leaves it unchanged.
    var destination: String?
    var arrivalTime: String?
    var departureTime: String?
    var recommendationsEnabled: Bool?
    var request: String?
    var suggestionID: String?
    var placeID: String?
    var dwellMinutes: Double?
    var stopID: String?
    var stopDurations: [String: Double]?
    var stopOrder: [String]?
    var clearsArrivalTime = false

    private enum CodingKeys: String, CodingKey {
        case action, sessionID, expectedContextVersion, origin, destination, arrivalTime, departureTime
        case recommendationsEnabled, request, suggestionID, placeID, dwellMinutes, stopID, stopDurations, stopOrder
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(action, forKey: .action)
        try c.encodeIfPresent(sessionID, forKey: .sessionID)
        try c.encodeIfPresent(expectedContextVersion, forKey: .expectedContextVersion)
        try c.encodeIfPresent(origin, forKey: .origin)
        try c.encodeIfPresent(destination, forKey: .destination)
        if clearsArrivalTime { try c.encodeNil(forKey: .arrivalTime) }
        else { try c.encodeIfPresent(arrivalTime, forKey: .arrivalTime) }
        try c.encodeIfPresent(departureTime, forKey: .departureTime)
        try c.encodeIfPresent(recommendationsEnabled, forKey: .recommendationsEnabled)
        try c.encodeIfPresent(request, forKey: .request)
        try c.encodeIfPresent(suggestionID, forKey: .suggestionID)
        try c.encodeIfPresent(placeID, forKey: .placeID)
        try c.encodeIfPresent(dwellMinutes, forKey: .dwellMinutes)
        try c.encodeIfPresent(stopID, forKey: .stopID)
        try c.encodeIfPresent(stopDurations, forKey: .stopDurations)
        try c.encodeIfPresent(stopOrder, forKey: .stopOrder)
    }
}

nonisolated struct NavigationTiming: Decodable, Sendable {
    let departureTime: Date
    let walkingSeconds: Int
    let dwellSeconds: Int
    let totalSeconds: Int
    let estimatedArrival: Date
    let arrivalRange: [Date]
    let conservativeArrival: Date
    let latestArrival: Date?
    let remainingSeconds: Int?
    let late: Bool
    let isEstimate: Bool
}

nonisolated struct NavigationRoute: Decodable, Sendable {
    struct Origin: Decodable, Sendable {
        let frameId: String
        let position: Point
        let observedPosition: Point?
        let accuracyMeters: Double?
        let snapDistanceMeters: Double?
    }
    struct Leg: Decodable, Sendable {
        let frameId: String
        let polyline: [Point]
        let distanceMeters: Double
        let nodes: [String]
        let edges: [String]
    }
    let frameId: String
    let distanceMeters: Double
    let polyline: [Point]
    let origin: Origin
    let legs: [Leg]
    let edges: [String]
}

nonisolated struct NavigationPlace: Decodable, Identifiable, Sendable {
    let placeID: String
    let name: String
    let kind: String
    let frameId: String?
    let category: String?
    var id: String { placeID }
}

nonisolated struct NavigationStop: Decodable, Identifiable, Sendable {
    let stopID: String
    let placeID: String
    let name: String
    let category: String
    let source: String
    let dwellSeconds: Int
    let dwellRangeSeconds: [Int]
    var id: String { stopID }
}

nonisolated struct NavigationSuggestion: Decodable, Identifiable, Sendable {
    let suggestionID: String
    let planID: String
    let contextVersion: Int
    let placeID: String
    let name: String
    let category: String
    let reasonCode: String
    let source: String
    let extraSeconds: Int
    let timing: NavigationTiming
    let route: NavigationRoute
    let dwellSeconds: Int
    let expiresAt: Date
    let openingStatus: String
    var id: String { suggestionID }
}

nonisolated struct NavigationOverlay: Decodable, Identifiable, Sendable {
    let targetID: String
    let name: String
    let frameId: String
    let geometry: Geometry
    let kind: String
    let nature: String
    let avoidanceStatus: String
    let sourceID: Int
    let sourceVersion: Int
    let evidence: String
    let endUnknown: Bool
    let affectedEdgeIDs: [String]
    var id: String { "\(targetID)-\(sourceID)-\(sourceVersion)" }
}

nonisolated struct NavigationSource: Decodable, Identifiable, Sendable {
    let announceID: Int
    let version: Int
    let title: String?
    let publishedAt: Date?
    let excerpt: String
    var id: Int { announceID }
}

struct NavigationSourceNotice {
    let notice: AnnouncementItem
    let version: Int?
}

nonisolated struct NavigationWarning: Decodable, Sendable {
    let code: String
    let edgeIDs: [String]?
    let removableStopIDs: [String]?
}

nonisolated struct NavigationDecision: Decodable, Sendable {
    let placeID: String
    let reasonCode: String
    let extraSeconds: Int?
    let conservativeArrival: Date?
}

nonisolated struct NavigationSchedule: Decodable, Sendable {
    let uid: String
    let title: String
    let location: String
    let startAt: TimeInterval
    let endAt: TimeInterval
    let tableID: Int
    let tableVersion: Int
}

nonisolated struct NavigationPlan: Decodable, Sendable {
    struct Metrics: Decodable, Sendable {
        let modelCalls: Int
        let inputTokens: Int
        let outputTokens: Int
        let latencyMs: Int
        let invalidResults: Int
    }
    let sessionID: String
    let contextVersion: Int
    let planID: String?
    let mapRevision: Int
    let mapHash: String
    let status: String
    let destination: NavigationPlace?
    let schedule: NavigationSchedule?
    let route: NavigationRoute?
    let timing: NavigationTiming?
    let waypoints: [NavigationStop]
    let suggestions: [NavigationSuggestion]
    let decisions: [NavigationDecision]
    let overlays: [NavigationOverlay]
    let sources: [NavigationSource]
    let warnings: [NavigationWarning]
    let aiStatus: String
    let modelDisplayName: String
    let aiMetrics: Metrics?
    let recommendationsEnabled: Bool
    let placeChoices: [NavigationPlace]?
    let resolutionReason: String?

    var hasRoute: Bool { status == "ready" && route != nil && timing != nil }
    func suggestion(_ id: String?, at now: Date) -> NavigationSuggestion? {
        suggestions.first { $0.id == id && $0.contextVersion == contextVersion && $0.expiresAt > now }
    }
}

nonisolated struct NavigationFeedback: Encodable, Sendable {
    enum Action: String, Encodable, Sendable {
        case accepted, removed, skippedTime = "skipped_time", disliked, arrived
    }
    let sessionID: String
    let expectedContextVersion: Int
    let eventKey: String
    let action: Action
    let placeID: String
}

nonisolated struct NavigationFeedbackResult: Decodable, Sendable {
    let recorded: Bool
    let reasonCode: String?
}

nonisolated enum NavigationResult: Sendable {
    case plan(NavigationPlan)
    case ended(sessionID: String)
}

nonisolated enum NavigationCoding {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            guard let date = APIDate.parse(text) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Invalid navigation date"))
            }
            return date
        }
        return decoder
    }

    static func iso(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
}

nonisolated struct CampusMapSnapshot: Sendable {
    let schoolID: Int
    let document: CamapDocument
    let etag: String?
    var hash: String? { etag?.trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
}

nonisolated enum CampusMapResponse: Sendable {
    case unchanged
    case document(CampusMapSnapshot)
}

