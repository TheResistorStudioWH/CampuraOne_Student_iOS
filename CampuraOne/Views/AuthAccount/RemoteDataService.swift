//
//  RemoteDataService.swift
//  CampuraOne
//
//  Generated login-ready version
//

import Swift
import Combine
import SwiftyJSON
import Alamofire

final class RemoteDataService {
    static let shared = RemoteDataService()

    private init() { }

    // MARK: - Auth Token 管理

    func setAuthToken(_ token: String?) {
        APIClient.shared.setToken(token)
    }

    func bindUser(_ user: AppUser) {
        APIClient.shared.setToken(user.token)
    }

    func clearAuth() {
        APIClient.shared.clearToken()
    }

    // MARK: - 学生登录

    /// 学生账号密码登录。
    /// 返回的 AppUser 已自动写入 token，并会同步到 APIClient。
    func loginStudent(userName: String, password: String) async throws -> AppUser {
        let json = try await APIClient.shared.post(
            url: APIConfig.api_auth(APIConfig.AuthPath.studentLogin),
            parameters: [
                "userName": userName,
                "password": password
            ]
        )

        let data = json["data"]
        let token = data["token"].string
        let userJSON = data["user"]

        var user = JSONMapper.makeAppUser(from: userJSON)
        user.token = token

        APIClient.shared.setToken(token)
        return user
    }

    // MARK: - 请求当前用户

    func fetchCurrentUser() async throws -> AppUser {
        let json = try await APIClient.shared.get(url: APIConfig.api_download(APIConfig.DLPath.currentUser))
        return JSONMapper.makeAppUser(from: json["data"])
    }

    // MARK: - 请求用户信息

    func fetchUserProfile(userID: Int) async throws -> AppUser {
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.DLPath.currentUser),
            parameters: [
                "userID": userID
            ]
        )

        return JSONMapper.makeAppUser(from: json["data"])
    }

    // MARK: - 请求学生信息

    /// 新 token 版学生信息接口，不再依赖 studentID 参数。
    func fetchMyStudentProfile() async throws -> Student {
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.DLPath.studentProfile)
        )

        return JSONMapper.makeStudent(from: json["data"])
    }

    /// 兼容旧调用写法。建议后续逐步迁移到 fetchMyStudentProfile().
    func fetchStudentProfile(studentID: Int) async throws -> Student {
        _ = studentID
        return try await fetchMyStudentProfile()
    }
}
