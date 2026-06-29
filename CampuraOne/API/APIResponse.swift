//
//  APIResponse.swift
//  CampuraOne
//
//  Created by LShayc1own on 27/05/2026.
//


import Foundation

struct APIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
}
