import Alamofire
import Foundation

enum WatchAlamofireTransport {
    static func send(_ request: WatchHTTPRequest) async throws -> WatchHTTPResponse {
        var headers: HTTPHeaders = [.accept("application/json")]
        if let token = request.token { headers.add(.authorization(bearerToken: token)) }
        let response = await AF.request(
            request.path,
            method: request.method == .post ? .post : .get,
            parameters: request.parameters,
            encoding: request.method == .post ? JSONEncoding.default : URLEncoding.default,
            headers: headers,
            requestModifier: {
                $0.timeoutInterval = 20
                $0.cachePolicy = .reloadIgnoringLocalCacheData
            }
        ).serializingData(automaticallyCancelling: true).response
        try Task.checkCancellation()
        guard let status = response.response?.statusCode, let data = response.data else {
            throw WatchServiceError.connection
        }
        return WatchHTTPResponse(statusCode: status, data: data)
    }
}
