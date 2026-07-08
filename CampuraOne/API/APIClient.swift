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
            AF.request(
                url,
                method: .get,
                parameters: parameters,
                encoding: URLEncoding.default,
                headers: headers
            )
            .validate()
            .responseData { response in
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
            AF.request(
                url,
                method: .post,
                parameters: parameters,
                encoding: JSONEncoding.default,
                headers: headers
            )
            .validate()
            .responseData { response in
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
