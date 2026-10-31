import Foundation

enum APIClientError: LocalizedError {
    case invalidResponse
    case invalidPayload(String)
    case server(statusCode: Int, code: Int, message: String, details: Data? = nil)

    var statusCode: Int? {
        if case .server(let status, _, _, _) = self { return status }
        return nil
    }
    var isUnauthorized: Bool { statusCode == 401 }
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "服务器返回了无法识别的响应"
        case .invalidPayload(let message): return message
        case .server(_, _, let message, _): return message
        }
    }
}

