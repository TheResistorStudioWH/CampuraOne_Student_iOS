//
//  APIConfig.swift
//  CampuraOne
//
//  Created by LShayc1own on 25/05/2026.
//


import Foundation

enum APIConfig {
    
    static let baseURL = "http://129.211.189.35"
    
    static func api_download(_ path: String) -> String {
        baseURL + "/api/download" + path
    }
    
    static func api_upload(_ path: String) -> String {
        baseURL + "/api/upload" + path
    }
    
    enum Path {
        static let currentUser = "/user_profile.php"
        static let studentProfile = "/student_profile.php"
        
        static let school = "/school_profile.php"
        static let campuses = "/campuses.php"
        static let schoolCalendar = "/school_calendar.php"
        
        static let courseTable = "/course_table.php"
        
        static let shops = "/main_shops.php"
        static let subShops = "/sub_shops.php"
        
        static let products = "/products.php"
        static let productCategories = "/product_categories.php"
        
        static let advertisements = "/advertisements.php"
        static let promotions = "/promotions.php"
        
        static let announcements = "/announcements.php"
        
        static let search = "/search.php"
    }
}
