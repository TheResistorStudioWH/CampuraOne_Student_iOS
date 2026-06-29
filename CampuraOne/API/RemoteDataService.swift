//
//  RemoteDataService.swift
//  CampuraOne
//
//  Created by LShayc1own on 25/05/2026.
//

import Swift
import Combine
import SwiftyJSON

final class RemoteDataService {
    
    static let shared = RemoteDataService()
    
    private init() { }
    
    // MARK: - 请求当前用户
    
    func fetchCurrentUser() async throws -> AppUser {
        let json = try await APIClient.shared.get(url: APIConfig.api_download(APIConfig.Path.currentUser))
        
        // 假设后端返回：
        // {
        //   "data": {
        //      "userID": 1,
        //      "userName": "琳曦",
        //      ...
        //   }
        // }
        return JSONMapper.makeAppUser(from: json["data"])
    }
    // MARK: - 请求用户信息
    
    func fetchUserProfile(userID: Int) async throws -> AppUser {
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.currentUser),
            parameters: [
                "userID": userID
            ]
        )
        
        return JSONMapper.makeAppUser(from: json["data"])
    }
    
    // MARK: - 请求学生信息
    
    func fetchStudentProfile(studentID: Int) async throws -> Student {
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.studentProfile),
            parameters: [
                "studentID": studentID
            ]
        )
        
        return JSONMapper.makeStudent(from: json["data"])
    }
    
    // MARK: - 请求学校数据
    
    func fetchSchool(schoolID: Int) async throws -> School {
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.school),
            parameters: [
                "schoolID": schoolID
            ]
        )
        
        return JSONMapper.makeSchool(from: json["data"])
    }

    // MARK: - 请求校区列表
    
    func fetchCampuses(schoolID: Int) async throws -> [Campus] {
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.campuses),
            parameters: [
                "schoolID": schoolID
            ]
        )
        
        return json["data"].arrayValue.map {
            JSONMapper.makeCampus(from: $0)
        }
    }
    
    // MARK: - 请求学校校历 ICS
    
    func fetchSchoolCalendarICS(schoolID: Int) async throws -> String {
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.schoolCalendar),
            parameters: [
                "schoolID": schoolID
            ]
        )
        
        let data = json["data"]
        
        if let content = data["content"].string {
            return content
        }
        
        if let schoolCalendar = data["schoolCalendar"].string {
            return schoolCalendar
        }
        
        return data.stringValue
    }
    
    // MARK: - 请求班级课程表 ICS
    
    func fetchCourseTable(
        schoolID: Int,
        compoundID: Int,
        departmentID: Int,
        classID: Int
    ) async throws -> CourseTable {
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.courseTable),
            parameters: [
                "schoolID": schoolID,
                "compoundID": compoundID,
                "departmentID": departmentID,
                "classID": classID
            ]
        )
        
        return JSONMapper.makeCourseTable(from: json["data"])
    }
    
    func fetchCourseTableICS(
        schoolID: Int,
        compoundID: Int,
        departmentID: Int,
        classID: Int
    ) async throws -> String {
        let courseTable = try await fetchCourseTable(
            schoolID: schoolID,
            compoundID: compoundID,
            departmentID: departmentID,
            classID: classID
        )
        
        return courseTable.content
    }
    
    // MARK: - 请求商户列表
    
    func fetchMainShops(schoolID: Int) async throws -> [MainShop] {
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.shops),
            parameters: [
                "schoolID": schoolID
            ]
        )
        
        return json["data"].arrayValue.map {
            JSONMapper.makeMainShop(from: $0)
        }
    }
    
    // MARK: - 请求附属商户列表
    
    func fetchSubShops(mainShopID: Int) async throws -> [SubShop] {
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.subShops),
            parameters: [
                "mainShopID": mainShopID
            ]
        )
        
        return json["data"].arrayValue.map {
            JSONMapper.makeSubShop(from: $0)
        }
    }
    
    // MARK: - 请求商品分类
    
    func fetchProductCategories() async throws -> [ProductCategory] {
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.productCategories)
        )
        
        return JSONMapper.makeProductCategories(from: json["data"])
    }
    
    func fetchProductCategory(categoryID: Int) async throws -> ProductCategory {
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.productCategories),
            parameters: [
                "categoryID": categoryID
            ]
        )
        
        return JSONMapper.makeProductCategory(from: json["data"])
    }
    
    // MARK: - 请求单个商品
    
    func fetchProduct(productID: Int) async throws -> Product {
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.products),
            parameters: [
                "productID": productID
            ]
        )
        
        let data = json["data"]
        
        if let firstProductJSON = data.arrayValue.first {
            return JSONMapper.makeProduct(from: firstProductJSON)
        }
        
        return JSONMapper.makeProduct(from: data)
    }
    
    // MARK: - 请求主商户下全部商品
    
    func fetchProducts(
        mainShopID: Int,
        categoryID: Int? = nil
    ) async throws -> [Product] {
        var parameters: [String: Any] = [
            "mainShopID": mainShopID
        ]
        
        if let categoryID {
            parameters["categoryID"] = categoryID
        }
        
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.products),
            parameters: parameters
        )
        
        return JSONMapper.makeProducts(from: json["data"])
    }
    
    // MARK: - 请求主商户直营商品
    
    func fetchDirectProducts(
        mainShopID: Int,
        categoryID: Int? = nil
    ) async throws -> [Product] {
        var parameters: [String: Any] = [
            "mainShopID": mainShopID,
            "scope": "direct"
        ]
        
        if let categoryID {
            parameters["categoryID"] = categoryID
        }
        
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.products),
            parameters: parameters
        )
        
        return JSONMapper.makeProducts(from: json["data"])
    }
    
    // MARK: - 请求附属商户商品
    
    func fetchProducts(
        subShopID: Int,
        categoryID: Int? = nil
    ) async throws -> [Product] {
        var parameters: [String: Any] = [
            "subShopID": subShopID
        ]
        
        if let categoryID {
            parameters["categoryID"] = categoryID
        }
        
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.products),
            parameters: parameters
        )
        
        return JSONMapper.makeProducts(from: json["data"])
    }

    // MARK: - 按分类请求全部商品
    
    func fetchProducts(categoryID: Int) async throws -> [Product] {
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.products),
            parameters: [
                "categoryID": categoryID
            ]
        )
        
        return JSONMapper.makeProducts(from: json["data"])
    }
    
    // MARK: - 请求促销事件列表
    
    func fetchPromotionEvents(
        productID: Int? = nil,
        onlyActive: Bool = false
    ) async throws -> [SaleEvent] {
        var parameters: [String: Any] = [:]
        
        if let productID {
            parameters["productID"] = productID
        }
        
        if onlyActive {
            parameters["onlyActive"] = 1
        }
        
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.promotions),
            parameters: parameters
        )
        
        return json["data"].arrayValue.map {
            JSONMapper.makePromotionEvent(from: $0)
        }
    }
    
    // MARK: - 请求广告列表
    
    func fetchAdvertisements(
        saleID: Int? = nil,
        type: String? = nil,
        onlyActive: Bool = false
    ) async throws -> [Advertisement] {
        var parameters: [String: Any] = [:]
        
        if let saleID {
            parameters["saleID"] = saleID
        }
        
        if let type, !type.isEmpty {
            parameters["type"] = type
        }
        
        if onlyActive {
            parameters["onlyActive"] = 1
        }
        
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.advertisements),
            parameters: parameters
        )
        
        return json["data"].arrayValue.map {
            JSONMapper.makeAdvertisement(from: $0)
        }
    }
    
    func fetchLargeAdvertisements(onlyActive: Bool = false) async throws -> [Advertisement] {
        try await fetchAdvertisements(
            type: "L",
            onlyActive: onlyActive
        )
    }
    
    func fetchSmallAdvertisements(onlyActive: Bool = false) async throws -> [Advertisement] {
        try await fetchAdvertisements(
            type: "S",
            onlyActive: onlyActive
        )
    }
    
    // MARK: - 搜索促销、商品与商户
    
    /// 统一搜索接口。
    ///
    /// 后端 search.php 会根据 mode 决定搜索范围：
    /// - smart：搜索促销、商品和商户，并返回智能排序的顶部猜测胶囊
    /// - all：搜索促销、商品和商户，结果顺序固定为促销 > 商品 > 商户
    /// - product：只搜索商品
    /// - shop：只搜索商户
    ///
    /// 返回值同时包含 suggestions 和 results。
    /// 普通模式下 suggestions 会是空数组。
    func search(
        query: String,
        mode: SearchPickerItem,
        schoolID: Int? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> (
        suggestions: [SearchResultSuggestion],
        results: [SearchResultItem]
    ) {
        var parameters: [String: Any] = [
            "q": query,
            "mode": mode.searchAPIMode,
            "limit": limit,
            "offset": offset
        ]
        
        if let schoolID {
            parameters["schoolID"] = schoolID
        }
        
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.search),
            parameters: parameters
        )
        
        let data = json["data"]
        
        /// 先解析促销、商品和商户的完整结果，
        /// 再让 suggestions 通过 kind + targetID 复用对应对象。
        let results = JSONMapper.makeSearchResults(
            from: data["results"]
        )
        
        let suggestions = JSONMapper.makeSearchSuggestions(
            from: data["suggestions"],
            matching: results
        )
        
        return (
            suggestions: suggestions,
            results: results
        )
    }
    
    /// 给通用 LoadableListViewModel 使用的便捷方法。
    ///
    /// LoadableListViewModel 只需要一个数组，所以这里仅返回 results。
    /// 智能搜索顶部 suggestions 仍然通过上面的 search(...) 获取。
    func fetchSearchResults(
        query: String,
        mode: SearchPickerItem,
        schoolID: Int? = nil,
        limit: Int = 20,
        offset: Int = 0
    ) async throws -> [SearchResultItem] {
        let response = try await search(
            query: query,
            mode: mode,
            schoolID: schoolID,
            limit: limit,
            offset: offset
        )
        
        return response.results
    }
    
    // MARK: - 请求学校通知列表

    func fetchAnnouncements(
        schoolID: Int,
        type: AnnouncementType? = nil,
        areaID: Int? = nil,
        departmentID: Int? = nil,
        classID: Int? = nil,
        studentID: Int? = nil
    ) async throws -> [AnnouncementItem] {
        var parameters: [String: Any] = [
            "schoolID": schoolID
        ]
        
        if let type {
            parameters["type"] = type.rawValue
        }
        
        if let areaID {
            parameters["areaID"] = areaID
        }
        
        if let departmentID {
            parameters["departmentID"] = departmentID
        }
        
        if let classID {
            parameters["classID"] = classID
        }
        
        if let studentID {
            parameters["studentID"] = studentID
        }
        
        let json = try await APIClient.shared.get(
            url: APIConfig.api_download(APIConfig.Path.announcements),
            parameters: parameters
        )
        
        return json["data"].arrayValue.map {
            JSONMapper.makeAnnouncementItem(from: $0)
        }
    }


    // MARK: - 请求当前学生可见通知
    
    func fetchVisibleAnnouncements(
        schoolID: Int,
        areaID: Int? = nil,
        departmentID: Int? = nil,
        classID: Int? = nil,
        studentID: Int? = nil,
        type: AnnouncementType? = nil
    ) async throws -> [AnnouncementItem] {
        
        let announcements = try await fetchAnnouncements(
            schoolID: schoolID,
            type: type,
            areaID: areaID,
            departmentID: departmentID,
            classID: classID,
            studentID: studentID
        )
        
        return announcements.filter { announcement in
            isAnnouncementVisible(
                announcement,
                areaID: areaID,
                departmentID: departmentID,
                classID: classID,
                studentID: studentID
            )
        }
    }
    
    private func isAnnouncementVisible(
        _ announcement: AnnouncementItem,
        areaID: Int?,
        departmentID: Int?,
        classID: Int?,
        studentID: Int?
    ) -> Bool {
        guard let target = announcement.target else {
            return true
        }
        
        if target.allSchool {
            return true
        }
        
        if let areaID, target.areaIDs.contains(areaID) {
            return true
        }
        
        if let departmentID, target.departmentIDs.contains(departmentID) {
            return true
        }
        
        if let classID, target.classIDs.contains(classID) {
            return true
        }
        
        if let studentID, target.studentIDs.contains(studentID) {
            return true
        }
        
        return false
    }
}
