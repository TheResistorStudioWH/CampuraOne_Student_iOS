import Foundation

enum WatchAccount {
    static let userName = "demo_student"
    static let password = "123456"
}

enum WatchCalendarKind: String, CaseIterable, Codable, Identifiable, Sendable {
    case courses, school
    var id: Self { self }
    var title: String { self == .courses ? "课表" : "校历" }
    var symbol: String { self == .courses ? "calendar.badge.clock" : "calendar" }
}

struct WatchHTTPRequest: Sendable {
    enum Method: Sendable { case get, post }
    let path: String
    var method: Method = .get
    var parameters: [String: String] = [:]
    var token: String?
}

struct WatchHTTPResponse: Sendable {
    let statusCode: Int
    let data: Data
}

typealias WatchHTTPTransport = @Sendable (WatchHTTPRequest) async throws -> WatchHTTPResponse

enum WatchServiceError: LocalizedError {
    case connection, authentication, unavailable, invalidData
    var errorDescription: String? {
        switch self {
        case .connection: "暂时无法连接，请稍后重试"
        case .authentication: "暂时无法获取账户信息，请重试"
        case .unavailable: "暂时无法获取安排，请稍后重试"
        case .invalidData: "无法读取返回的日程，请重试"
        }
    }
}

struct WatchStudentScope: Codable, Equatable, Sendable {
    let studentID: Int
    let schoolID: Int
    let compoundID: Int
    let departmentID: Int
    let classID: Int
}

struct WatchCalendarDocument: Codable, Sendable {
    var schemaVersion = 1
    let account: String
    let userID: Int
    let scope: WatchStudentScope
    let kind: WatchCalendarKind
    let content: String
    let fetchedAt: Date
}

/// One in-flight authentication is shared by both calendars. Tokens stay in memory.
actor WatchAPI {
    private struct Identity: Sendable {
        let token: String
        let userID: Int
        let scope: WatchStudentScope
    }
    private struct Envelope<Payload: Decodable>: Decodable {
        let code: Int
        let data: Payload?
    }
    private struct Login: Decodable {
        struct User: Decodable { let userID: Int; let studentID: Int? }
        let token: String
        let user: User
    }
    private struct CalendarContent: Decodable {
        let content: String
        private enum CodingKeys: String, CodingKey { case content, schoolCalendar }
        init(from decoder: Decoder) throws {
            if let text = try? decoder.singleValueContainer().decode(String.self) {
                content = text
                return
            }
            let container = try decoder.container(keyedBy: CodingKeys.self)
            if let text = try container.decodeIfPresent(String.self, forKey: .content) {
                content = text
            } else {
                content = try container.decode(String.self, forKey: .schoolCalendar)
            }
        }
    }

    private let transport: WatchHTTPTransport
    private var identity: Identity?
    private var authentication: (id: UUID, task: Task<Identity, Error>)?

    init(transport: @escaping WatchHTTPTransport) { self.transport = transport }

    func fetch(_ kind: WatchCalendarKind) async throws -> WatchCalendarDocument {
        var current = try await authenticatedIdentity()
        var response = try await download(kind, identity: current)
        if isUnauthorized(response) {
            // Another request may already have replaced the rejected token.
            if identity?.token == current.token { identity = nil }
            current = try await authenticatedIdentity()
            response = try await download(kind, identity: current)
        }
        if isUnauthorized(response) { throw WatchServiceError.authentication }
        let result: CalendarContent = try decode(response)
        try WatchCalendarData.validateICS(result.content)
        return WatchCalendarDocument(
            account: WatchAccount.userName, userID: current.userID, scope: current.scope,
            kind: kind, content: result.content, fetchedAt: Date()
        )
    }

    private func authenticatedIdentity() async throws -> Identity {
        if let identity { return identity }
        let pending: (id: UUID, task: Task<Identity, Error>)
        if let authentication {
            pending = authentication
        } else {
            let transport = self.transport
            let task = Task<Identity, Error> {
                let response = try await transport(WatchHTTPRequest(
                    path: APIConfig.api_auth(APIConfig.AuthPath.login), method: .post,
                    parameters: ["userName": WatchAccount.userName, "password": WatchAccount.password]
                ))
                if Self.isUnauthorized(response) { throw WatchServiceError.authentication }
                let login: Login = try Self.decode(response)
                guard !login.token.isEmpty, login.token.split(separator: ".").count == 3,
                      login.user.userID > 0, let studentID = login.user.studentID, studentID > 0 else {
                    throw WatchServiceError.authentication
                }
                let profile = try await transport(WatchHTTPRequest(
                    path: APIConfig.api_download(APIConfig.DLPath.studentProfile), token: login.token
                ))
                let scope: WatchStudentScope = try Self.decode(profile)
                guard scope.studentID == studentID, scope.schoolID > 0,
                      scope.compoundID > 0, scope.departmentID > 0, scope.classID > 0 else {
                    throw WatchServiceError.invalidData
                }
                return Identity(token: login.token, userID: login.user.userID, scope: scope)
            }
            pending = (UUID(), task)
            authentication = pending
        }
        do {
            let result = try await pending.task.value
            // Any waiter may resume first. Publish before returning, and never let
            // a late waiter overwrite a newer authentication or clear its task.
            if authentication?.id == pending.id {
                identity = result
                authentication = nil
            }
            return identity ?? result
        } catch {
            if authentication?.id == pending.id { authentication = nil }
            throw error
        }
    }

    private func download(_ kind: WatchCalendarKind, identity: Identity) async throws -> WatchHTTPResponse {
        var parameters = ["schoolID": String(identity.scope.schoolID)]
        if kind == .courses {
            parameters["compoundID"] = String(identity.scope.compoundID)
            parameters["departmentID"] = String(identity.scope.departmentID)
            parameters["classID"] = String(identity.scope.classID)
        }
        return try await transport(WatchHTTPRequest(
            path: APIConfig.api_download(kind == .courses ? APIConfig.DLPath.courseTable : APIConfig.DLPath.schoolCalendar),
            parameters: parameters, token: identity.token
        ))
    }

    private nonisolated static func isUnauthorized(_ response: WatchHTTPResponse) -> Bool {
        if response.statusCode == 401 { return true }
        struct Status: Decodable { let code: Int }
        return (try? JSONDecoder().decode(Status.self, from: response.data).code) == 401
    }

    private nonisolated static func decode<T: Decodable>(_ response: WatchHTTPResponse) throws -> T {
        guard (200..<300).contains(response.statusCode) else { throw WatchServiceError.unavailable }
        guard let envelope = try? JSONDecoder().decode(Envelope<T>.self, from: response.data) else {
            throw WatchServiceError.invalidData
        }
        guard envelope.code == 200 else { throw WatchServiceError.unavailable }
        guard let value = envelope.data else { throw WatchServiceError.invalidData }
        return value
    }

    private func isUnauthorized(_ response: WatchHTTPResponse) -> Bool { Self.isUnauthorized(response) }
    private func decode<T: Decodable>(_ response: WatchHTTPResponse) throws -> T { try Self.decode(response) }
}

actor WatchDocumentCache {
    private let directory: URL
    init(directory: URL = URL.applicationSupportDirectory.appendingPathComponent("WatchCalendars", isDirectory: true)) {
        self.directory = directory
    }

    func load(_ kind: WatchCalendarKind) -> WatchCalendarDocument? {
        guard let data = try? Data(contentsOf: path(kind)),
              let document = try? JSONDecoder().decode(WatchCalendarDocument.self, from: data),
              document.schemaVersion == 1, document.kind == kind,
              document.account == WatchAccount.userName,
              (try? WatchCalendarData.validateICS(document.content)) != nil else { return nil }
        return document
    }

    func save(_ document: WatchCalendarDocument) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(document).write(to: path(document.kind), options: .atomic)
    }

    private func path(_ kind: WatchCalendarKind) -> URL { directory.appendingPathComponent("\(kind.rawValue).json") }
}
