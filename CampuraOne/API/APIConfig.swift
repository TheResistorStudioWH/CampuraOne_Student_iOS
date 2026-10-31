//
//  APIConfig.swift
//  CampuraOne
//
//  Created by LShayc1own on 25/05/2026.
//


import Foundation

enum APIConfig {
    
    static let baseURL = "https://campura.one"
    
    static func api_download(_ path: String) -> String {
        baseURL + "/api/download" + path
    }
    
    static func api_upload(_ path: String) -> String {
        baseURL + "/api/upload" + path
    }
    
    static func api_auth(_ path: String) -> String {
        baseURL + "/api/auth/user/student" + path
    }

    static func api_ai(_ path: String) -> String {
        baseURL + "/api/OnlyAI" + path
    }

    static func api_navigation(_ path: String) -> String {
        baseURL + "/api/navigation" + path
    }

    enum NavigationPath {
        static let plan = "/plan.php"
        static let preferences = "/preferences.php"
        static let feedback = "/feedback.php"
    }

    enum AIPath {
        static let announcementSummary = "/announcement_summary.php"
    }
    
    enum DLPath {
        static let currentUser = "/user_profile.php"
        static let studentProfile = "/student_profile.php"
        
        static let school = "/school_profile.php"
        static let campuses = "/campuses.php"
        static let campusMap = "/campus_map.php"
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
    
    enum ULPath {
        
    }
    
    enum AuthPath {
        static let login = "/login.php"
    }
}
