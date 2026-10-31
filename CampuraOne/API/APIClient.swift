import Foundation
import Alamofire
import SwiftyJSON

extension Notification.Name {
    static let authenticationRequired = Notification.Name("authenticationRequired")
}


struct APIHTTPResponse {
    let json: JSON
    let statusCode: Int
    let etag: String?
}

final class APIClient {
    static let shared = APIClient()
    private var authToken: String?
    private init() { }

    func setToken(_ token: String?) {
        let token = token?.trimmingCharacters(in: .whitespacesAndNewlines)
        authToken = token?.isEmpty == false ? token : nil
    }
    func clearToken() { authToken = nil }

    func get(url: String, parameters: Parameters? = nil,
             cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy) async throws -> JSON {
        try await request(url: url, method: .get, parameters: parameters, cachePolicy: cachePolicy).json
    }

    func post(url: String, parameters: Parameters? = nil) async throws -> JSON {
        try await request(url: url, method: .post, parameters: parameters).json
    }

    /// Shared transport for navigation PATCH/DELETE and conditional map reads.
    /// No automatic mutation retries: a timeout can occur after a server commit.
    func request(url: String, method: HTTPMethod, parameters: Parameters? = nil,
                 cachePolicy: URLRequest.CachePolicy = .useProtocolCachePolicy,
                 timeout: TimeInterval = 60, etag: String? = nil) async throws -> APIHTTPResponse {
        try Task.checkCancellation()
        #if DEBUG
        if PreviewAPI.isEnabled {
            let json = try PreviewAPI.response(url: url, parameters: parameters, method: method.rawValue)
            return APIHTTPResponse(json: json, statusCode: 200,
                                   etag: URL(string: url)?.lastPathComponent == "campus_map.php" ? PreviewNavigation.mapETag : nil)
        }
        #endif
        let requestToken = authToken
        var headers: HTTPHeaders = ["Accept": "application/json"]
        if let requestToken { headers.add(name: "Authorization", value: "Bearer \(requestToken)") }
        if let etag { headers.add(name: "If-None-Match", value: etag) }
        #if DEBUG
        print("➡️ \(method.rawValue) \(url)")
        #endif
        let request = AF.request(url, method: method, parameters: parameters,
                                 encoding: method == .get ? URLEncoding.default : JSONEncoding.default,
                                 headers: headers, requestModifier: {
            $0.cachePolicy = cachePolicy
            $0.timeoutInterval = timeout
        })
        let response = await request.serializingData(automaticallyCancelling: true).response
        try Task.checkCancellation()
        guard let http = response.response else {
            throw response.error ?? AFError.responseValidationFailed(reason: .dataFileNil)
        }
        #if DEBUG
        print("⬅️ Status:", http.statusCode)
        #endif
        if http.statusCode == 304 {
            return APIHTTPResponse(json: .null, statusCode: 304, etag: http.value(forHTTPHeaderField: "ETag"))
        }
        if http.statusCode == 401, requestToken == authToken {
            NotificationCenter.default.post(name: .authenticationRequired, object: nil)
        }
        let data = try response.result.get()
        guard data.count <= 22 * 1024 * 1024 else { throw APIClientError.invalidResponse }
        let json = JSON(data)
        guard (200..<300).contains(http.statusCode) else {
            throw APIClientError.server(statusCode: http.statusCode,
                                        code: json["code"].int ?? http.statusCode,
                                        message: json["message"].string ?? "请求失败（HTTP \(http.statusCode)）",
                                        details: try? json["data"].rawData())
        }
        // In particular, reject PHP warnings/HTML that arrive with HTTP 200.
        guard json.dictionary != nil, json["code"].int != nil else { throw APIClientError.invalidResponse }
        return APIHTTPResponse(json: json, statusCode: http.statusCode, etag: http.value(forHTTPHeaderField: "ETag"))
    }
}
