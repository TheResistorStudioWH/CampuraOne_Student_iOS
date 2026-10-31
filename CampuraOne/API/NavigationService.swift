import Foundation
import Alamofire
import SwiftyJSON
import CamapKit


extension RemoteDataService {
    func fetchNavigationPreferences() async throws -> NavigationPreferences {
        try decodeNavigation(await APIClient.shared.request(
            url: APIConfig.api_navigation(APIConfig.NavigationPath.preferences), method: .get,
            cachePolicy: .reloadIgnoringLocalCacheData).json)
    }

    func updateNavigationPreferences(_ update: NavigationPreferenceUpdate) async throws -> NavigationPreferences {
        try decodeNavigation(await APIClient.shared.request(
            url: APIConfig.api_navigation(APIConfig.NavigationPath.preferences), method: .patch,
            parameters: encodeNavigation(update)).json)
    }

    func sendNavigationCommand(_ command: NavigationCommand) async throws -> NavigationResult {
        let json = try await APIClient.shared.request(
            url: APIConfig.api_navigation(APIConfig.NavigationPath.plan), method: .post,
            parameters: encodeNavigation(command), cachePolicy: .reloadIgnoringLocalCacheData, timeout: 60).json
        if command.action == .end {
            try validateNavigationEnvelope(json)
            guard json["data"]["ended"].bool == true,
                  let id = json["data"]["sessionID"].string, id == command.sessionID else {
                throw APIClientError.invalidResponse
            }
            return .ended(sessionID: id)
        }
        let plan: NavigationPlan = try decodeNavigation(json)
        guard plan.contextVersion > 0, !plan.sessionID.isEmpty,
              plan.route.map({ route in
                  route.distanceMeters.isFinite && route.distanceMeters >= 0 && route.polyline.count >= 2
                  && route.polyline.allSatisfy { $0.x.isFinite && $0.y.isFinite }
              }) ?? true else { throw APIClientError.invalidResponse }
        return .plan(plan)
    }

    func sendNavigationFeedback(_ feedback: NavigationFeedback) async throws -> NavigationFeedbackResult {
        try decodeNavigation(await APIClient.shared.request(
            url: APIConfig.api_navigation(APIConfig.NavigationPath.feedback), method: .post,
            parameters: encodeNavigation(feedback)).json)
    }

    func clearNavigationHistory() async throws {
        let json = try await APIClient.shared.request(
            url: APIConfig.api_navigation(APIConfig.NavigationPath.feedback), method: .delete,
            parameters: [:]).json
        try validateNavigationEnvelope(json)
        guard json["data"]["cleared"].bool == true else { throw APIClientError.invalidResponse }
    }

    func fetchCampusMap(schoolID: Int, etag: String?) async throws -> CampusMapResponse {
        let response = try await APIClient.shared.request(
            url: APIConfig.api_download(APIConfig.DLPath.campusMap), method: .get,
            parameters: ["schoolID": schoolID, "format": "json"],
            cachePolicy: .reloadIgnoringLocalCacheData, etag: etag)
        if response.statusCode == 304 { return .unchanged }
        let document: CamapDocument = try decodeNavigation(response.json)
        try Camap.validate(document)
        return .document(CampusMapSnapshot(schoolID: schoolID, document: document, etag: response.etag))
    }

    /// Source lookups deliberately do not use the normal active-list filter.
    /// An expired display period can still have a currently valid navigation effect.
    func fetchNavigationSource(announceID: Int) async throws -> NavigationSourceNotice? {
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.DLPath.announcements),
            parameters: ["announceID": announceID], cachePolicy: .reloadIgnoringLocalCacheData)
        try validateNavigationEnvelope(json)
        guard let rows = json["data"].array else { throw APIClientError.invalidResponse }
        return rows.first(where: { $0["announceID"].int == announceID }).map {
            NavigationSourceNotice(notice: JSONMapper.makeAnnouncementItem(from: $0), version: $0["version"].int)
        }
    }

    private func encodeNavigation<T: Encodable>(_ value: T) throws -> Parameters {
        guard let parameters = try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? Parameters else {
            throw APIClientError.invalidResponse
        }
        return parameters
    }

    private func validateNavigationEnvelope(_ json: JSON) throws {
        guard json["code"].int == 200 else {
            throw APIClientError.server(statusCode: json["code"].int ?? 502,
                                        code: json["code"].int ?? 502,
                                        message: json["message"].string ?? "服务暂不可用", details: try? json["data"].rawData())
        }
    }

    private func decodeNavigation<T: Decodable>(_ json: JSON) throws -> T {
        try validateNavigationEnvelope(json)
        do { return try NavigationCoding.decoder().decode(T.self, from: json["data"].rawData()) }
        catch { throw APIClientError.invalidResponse }
    }
}

@MainActor
extension NavigationPreferencesStore {
    static let shared = NavigationPreferencesStore(client: Client(
        fetch: { try await RemoteDataService.shared.fetchNavigationPreferences() },
        update: { try await RemoteDataService.shared.updateNavigationPreferences($0) },
        clearHistory: { try await RemoteDataService.shared.clearNavigationHistory() },
        didChange: { StudentNavigationStore.shared.preferencesChanged() }
    ))
}

@MainActor
extension CampusMapStore {
    static let shared = CampusMapStore(client: Client(
        school: { try await RemoteDataService.shared.fetchMyStudentProfile().schoolID },
        fetch: { try await RemoteDataService.shared.fetchCampusMap(schoolID: $0, etag: $1) }
    ))
}

@MainActor
extension StudentNavigationStore {
    static let shared = StudentNavigationStore(client: Client(
        send: { try await RemoteDataService.shared.sendNavigationCommand($0) },
        feedback: { try await RemoteDataService.shared.sendNavigationFeedback($0) },
        source: { try await RemoteDataService.shared.fetchNavigationSource(announceID: $0) }
    ))
}
