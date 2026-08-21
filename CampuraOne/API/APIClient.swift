//
//  APIClient.swift
//  CampuraOne
//
//  Created by LShayc1own on 25/05/2026.
//



import Foundation
import Alamofire
import SwiftyJSON

final class APIClient {
    
    static let shared = APIClient()
    private var authToken: String?
    
    private init() { }
    
    func setToken(_ token: String) {
        self.authToken = token
        print("🔐 Token Updated")
        print(token)
    }
    /// 通用 GET 请求
    func get(
        url: String,
        parameters: Parameters? = nil
    ) async throws -> JSON {
        
        return try await withCheckedThrowingContinuation { continuation in
            var headers: HTTPHeaders = []
            if let token = authToken {
                headers.add(name: "Authorization", value: "Bearer \(token)")
            }
            print("➡️ GET \(url)")

            if let parameters {
                print("   Parameters:", parameters)
            }

            if let token = authToken {
                print("   Authorization: Bearer \(token.prefix(20))...")
            } else {
                print("   Authorization: <none>")
            }
            
            AF.request(
                url,
                method: .get,
                parameters: parameters,
                encoding: URLEncoding.default,
                headers: headers
            )
            .validate()
            .responseData { response in

                print("⬅️ Status:", response.response?.statusCode ?? -1)
                
                if let data = response.data,
                   let body = String(data: data, encoding: .utf8) {
                    print("⬅️ Body:")
                    print(body)
                }
                
                switch response.result {
                    case .success(let data):
                        let json = JSON(data)
                        continuation.resume(returning: json)
                        
                    case .failure(let error):
                        continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// 通用 POST 请求，之后登录、提交数据时会用到
    func post(
        url: String,
        parameters: Parameters? = nil
    ) async throws -> JSON {
        
        return try await withCheckedThrowingContinuation { continuation in
            var headers: HTTPHeaders = []
            if let token = authToken {
                headers.add(name: "Authorization", value: "Bearer \(token)")
            }
            print("➡️ POST \(url)")

            if let parameters {
                print("   Parameters:", parameters)
            }

            if let token = authToken {
                print("   Authorization: Bearer \(token.prefix(20))...")
            } else {
                print("   Authorization: <none>")
            }
            
            AF.request(
                url,
                method: .post,
                parameters: parameters,
                encoding: JSONEncoding.default,
                headers: headers
            )
            .validate()
            .responseData { response in
                print("⬅️ Status:", response.response?.statusCode ?? -1)
                
                if let data = response.data,
                   let body = String(data: data, encoding: .utf8) {
                    print("⬅️ Body:")
                    print(body)
                }
                switch response.result {
                    case .success(let data):
                        let json = JSON(data)
                        continuation.resume(returning: json)
                        
                    case .failure(let error):
                        continuation.resume(throwing: error)
                }
            }
        }
    }
}
