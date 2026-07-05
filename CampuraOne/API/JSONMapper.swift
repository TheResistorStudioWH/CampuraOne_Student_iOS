//
//  JSONMapper.swift
//  CampuraOne
//
//  Created by LShayc1own on 25/05/2026.
//

import Foundation
import SwiftyJSON

enum JSONMapper {
    
    // MARK: - 用户
    
    static func makeAppUser(from json: JSON) -> AppUser {
        AppUser(
            userID: json["userID"].intValue,
            userName: json["userName"].stringValue,
            userImg: json["userImg"].string,
            shopIDs: json["shopIDs"].arrayValue.map { $0.intValue },
            studentID: json["studentID"].int,
            createdAt: json["createdAt"].string?.toDate(),
            updatedAt: json["updatedAt"].string?.toDate()
        )
    }
    
    // MARK: - 学生
    
    static func makeStudent(from json: JSON) -> Student {
        Student(
            studentID: json["studentID"].intValue,
            studentName: json["studentName"].stringValue,
            gender: json["gender"].string,
            schoolID: json["schoolID"].intValue,
            compoundID: json["compoundID"].intValue,
            departmentID: json["departmentID"].intValue,
            classID: json["classID"].intValue,
            createdAt: json["createdAt"].string?.toDate(),
            updatedAt: json["updatedAt"].string?.toDate()
        )
    }
    
    // MARK: - 学校
    
    static func makeSchool(from json: JSON) -> School {
        School(
            schoolID: json["schoolID"].intValue,
            schoolName: json["schoolName"].stringValue,
            schoolAddress: makeStringArray(from: json["schoolAddress"]),
            schoolLogo: json["schoolLogo"].string,
            passwordHash: json["passwordHash"].string ?? json["password_hash"].string,
            areaIDs: makeIntArray(from: json["areaIDs"]),
            compoundIDs: makeIntArray(from: json["compoundIDs"]),
            schoolCalendar: json["schoolCalendar"].string,
            createdAt: json["createdAt"].string?.toDate(),
            updatedAt: json["updatedAt"].string?.toDate()
        )
    }
    
    static func makeCampus(from json: JSON) -> Campus {
        Campus(
            areaID: json["areaID"].intValue,
            areaName: json["areaName"].stringValue,
            areaAddress: makeStringArray(from: json["areaAddress"]),
            schoolID: json["schoolID"].intValue,
            createdAt: json["createdAt"].string?.toDate(),
            updatedAt: json["updatedAt"].string?.toDate()
        )
    }
    
    static func makeSchoolCalendar(from json: JSON) -> SchoolCalendar {
        SchoolCalendar(
            calendarID: json["calendarID"].intValue,
            content: json["content"].stringValue
        )
    }
    
    static func makeCourseTable(from json: JSON) -> CourseTable {
        CourseTable(
            tableID: json["tableID"].intValue,
            schoolID: json["schoolID"].intValue,
            compoundID: json["compoundID"].intValue,
            departmentID: json["departmentID"].intValue,
            content: json["content"].stringValue,
            classID: json["classID"].intValue,
            createdAt: json["createdAt"].string?.toDate(),
            updatedAt: json["updatedAt"].string?.toDate()
        )
    }
    
    // MARK: - 商户
    
    static func makeMainShop(from json: JSON) -> MainShop {
        MainShop(
            shopID: json["shopID"].intValue,
            shopName: json["shopName"].stringValue,
            shopAddress: json["shopAddress"].arrayValue.map { $0.stringValue },
            shopSlogan: json["shopSlogan"].string,
            subShopsList: json["subShopsList"].array?.map { $0.intValue },
            productsList: json["productsList"].array?.map { $0.intValue },
            adIDs: json["adIDs"].array?.map { $0.intValue },
            shopLogo: json["shopLogo"].string,
            shopImg: json["shopImg"].string,
            saleIDs: json["saleIDs"].array?.map { $0.intValue },
            schoolID: json["schoolID"].intValue,
            areaID: json["areaID"].int,
            accountID: json["accountID"].intValue
        )
    }
    
    static func makeSubShop(from json: JSON) -> SubShop {
        SubShop(
            shopID: json["shopID"].intValue,
            shopName: json["shopName"].stringValue,
            shopAddress: json["shopAddress"].arrayValue.map { $0.stringValue },
            productsList: json["productsList"].array?.map { $0.intValue },
            shopImg: json["shopImg"].string,
            mainShopID: json["mainShopID"].intValue,
            saleList: json["saleList"].array?.map { $0.intValue },
            takeOutLink: json["takeOutLink"].string,
            accountID: json["accountID"].intValue
        )
    }
    
    // MARK: - 商品分类
    
    static func makeProductCategory(from json: JSON) -> ProductCategory {
        ProductCategory(
            categoryID: json["categoryID"].intValue,
            categoryName: json["categoryName"].stringValue,
            categoryIcon: json["categoryIcon"].string,
            categoryColor: json["categoryColor"].string,
            createdAt: json["createdAt"].string?.toDate(),
            updatedAt: json["updatedAt"].string?.toDate()
        )
    }
    
    // MARK: - 商品
    static func makeProduct(from json: JSON) -> Product {
        let categoryJSON = json["category"]
        let category: ProductCategory?
        
        if categoryJSON.exists(), categoryJSON.type != .null {
            category = makeProductCategory(from: categoryJSON)
        } else if json["categoryName"].exists() {
            category = ProductCategory(
                categoryID: json["categoryID"].intValue,
                categoryName: json["categoryName"].stringValue,
                categoryIcon: json["categoryIcon"].string,
                categoryColor: json["categoryColor"].string,
                createdAt: nil,
                updatedAt: nil
            )
        } else {
            category = nil
        }
        
        return Product(
            productID: json["productID"].intValue,
            productName: json["productName"].stringValue,
            categoryID: json["categoryID"].int,
            category: category,
            productPrice: json["price"].doubleValue,
            productImg: json["productImg"].string,
            productIntro: json["productIntro"].string,
            mainShopID: json["mainShopID"].intValue,
            subShopID: json["subShopID"].int
        )
    }
    
    // MARK: - 广告
    
    static func makeAdvertisement(from json: JSON) -> Advertisement {
        Advertisement(
            adID: json["adID"].intValue,
            saleID: json["saleID"].intValue,
            startTime: json["startTime"].stringValue.toDate() ?? Date(),
            endTime: json["endTime"].string?.toDate(),
            type: json["type"].stringValue,
            img: json["img"].stringValue
        )
    }
    // MARK: - 促销事件
    static func makePromotionEvent(from json: JSON) -> SaleEvent {
        SaleEvent(
            saleID: json["saleID"].intValue,
            productID: json["productID"].int,
            saleRule: json["saleRule"].string,
            startTime: json["startTime"].stringValue.toDate() ?? Date(),
            endTime: json["endTime"].string?.toDate()
        )
    }
    
    // MARK: - 搜索
    
    /// 把 search.php 返回的一条促销、商品或商户结果，
    /// 转换成统一的 SearchResultItem。
    static func makeSearchResult(from json: JSON) -> SearchResultItem {
        let typeString = json["type"].stringValue
        let kind = SearchResultItem.Kind(rawValue: typeString) ?? .product
        
        let categoryJSON = json["category"]
        let categoryID: Int?
        let categoryName: String?
        let categoryIcon: String?
        let categoryColor: String?
        
        if categoryJSON.exists(),
           categoryJSON.type != .null {
            categoryID = categoryJSON["categoryID"].int
            categoryName = categoryJSON["categoryName"].string
            categoryIcon = categoryJSON["categoryIcon"].string
            categoryColor = categoryJSON["categoryColor"].string
        } else {
            categoryID = json["categoryID"].int
            categoryName = json["categoryName"].string
            categoryIcon = json["categoryIcon"].string
            categoryColor = json["categoryColor"].string
        }
        
        let targetID = json["targetID"].intValue
        let fallbackID = "\(kind.rawValue)-\(targetID)"
        
        return SearchResultItem(
            id: json["id"].string ?? fallbackID,
            targetID: targetID,
            kind: kind,
            title: json["title"].stringValue,
            subtitle: json["subtitle"].string,
            imageURL: json["imageURL"].string,
            categoryID: categoryID,
            categoryName: categoryName,
            categoryIcon: categoryIcon,
            categoryColor: categoryColor
        )
    }
    
    /// suggestions 与 results 都使用统一的 SearchResultItem 结构。
    /// 这里通过 kind + targetID 复用同一次 smart 请求中的完整结果对象，
    /// 找不到对应结果时返回 nil，不伪造残缺数据。
    static func makeSearchSuggestion(
        from json: JSON,
        matching results: [SearchResultItem]
    ) -> SearchResultSuggestion? {
        let typeString = json["type"].stringValue
        guard let kind = SearchResultItem.Kind(rawValue: typeString) else {
            return nil
        }

        let targetID = json["targetID"].intValue

        guard let matchedResult = results.first(where: {
            $0.kind == kind && $0.targetID == targetID
        }) else {
            return nil
        }

        return SearchResultSuggestion(
            info: matchedResult
        )
    }
    
    // MARK: - 通知
    static func makeAnnouncementItem(from json: JSON) -> AnnouncementItem {
        AnnouncementItem(
            announceID: json["announceID"].intValue,
            schoolID: json["schoolID"].intValue,
            content: json["content"].stringValue,
            type: AnnouncementType(rawValue: json["type"].intValue) ?? .dailyShort,
            target: makeAnnouncementTarget(from: json["target"]),
            startTime: json["startTime"].string?.toDate(),
            endTime: json["endTime"].string?.toDate(),
            createdAt: json["createdAt"].string?.toDate(),
            updatedAt: json["updatedAt"].string?.toDate()
        )
    }
    static func makeAnnouncementTarget(from json: JSON) -> AnnouncementTarget? {
        guard json.exists(), json.type != .null else {
            return nil
        }
        
        return AnnouncementTarget(
            allSchool: json["allSchool"].boolValue,
            areaIDs: json["areaIDs"].arrayValue.map { $0.intValue },
            departmentIDs: json["departmentIDs"].arrayValue.map { $0.intValue },
            classIDs: json["classIDs"].arrayValue.map { $0.intValue },
            studentIDs: json["studentIDs"].arrayValue.map { $0.intValue }
        )
    }

    // MARK: - 通用辅助解析
    
    static func makeStringArray(from json: JSON) -> [String]? {
        if json.type == .null || !json.exists() {
            return nil
        }
        
        if let array = json.array {
            return array.map { $0.stringValue }
        }
        
        if let string = json.string, !string.isEmpty {
            let data = Data(string.utf8)
            if let decoded = try? JSONDecoder().decode([String].self, from: data) {
                return decoded
            }
            return [string]
        }
        
        return nil
    }

    static func makeIntArray(from json: JSON) -> [Int] {
        if json.type == .null || !json.exists() {
            return []
        }
        
        if let array = json.array {
            return array.map { $0.intValue }
        }
        
        if let string = json.string, !string.isEmpty {
            let data = Data(string.utf8)
            if let decoded = try? JSONDecoder().decode([Int].self, from: data) {
                return decoded
            }
            
            return string
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }
        
        return []
    }
    
    // MARK: - 数组解析

    static func makeSearchResults(from json: JSON) -> [SearchResultItem] {
        json.arrayValue.map { makeSearchResult(from: $0) }
    }
    
    static func makeSearchSuggestions(
        from json: JSON,
        matching results: [SearchResultItem]
    ) -> [SearchResultSuggestion] {
        json.arrayValue.compactMap {
            makeSearchSuggestion(
                from: $0,
                matching: results
            )
        }
    }
    
    static func makeProductCategories(from json: JSON) -> [ProductCategory] {
        json.arrayValue.map { makeProductCategory(from: $0) }
    }
    
    
    static func makeAppUsers(from json: JSON) -> [AppUser] {
        json.arrayValue.map { makeAppUser(from: $0) }
    }
    
    static func makeStudents(from json: JSON) -> [Student] {
        json.arrayValue.map { makeStudent(from: $0) }
    }
    
    static func makeSchools(from json: JSON) -> [School] {
        json.arrayValue.map { makeSchool(from: $0) }
    }
    
    static func makeCampuses(from json: JSON) -> [Campus] {
        json.arrayValue.map { makeCampus(from: $0) }
    }
    
    static func makeSchoolCalendars(from json: JSON) -> [SchoolCalendar] {
        json.arrayValue.map { makeSchoolCalendar(from: $0) }
    }
    
    static func makeCourseTables(from json: JSON) -> [CourseTable] {
        json.arrayValue.map { makeCourseTable(from: $0) }
    }
    
    static func makeMainShops(from json: JSON) -> [MainShop] {
        json.arrayValue.map { makeMainShop(from: $0) }
    }
    
    static func makeSubShops(from json: JSON) -> [SubShop] {
        json.arrayValue.map { makeSubShop(from: $0) }
    }
    
    static func makeProducts(from json: JSON) -> [Product] {
        json.arrayValue.map { makeProduct(from: $0) }
    }
    
    static func makePromotionEvents(from json: JSON) -> [SaleEvent] {
        json.arrayValue.map { makePromotionEvent(from: $0) }
    }
    
    static func makeAdvertisements(from json: JSON) -> [Advertisement] {
        json.arrayValue.map { makeAdvertisement(from: $0) }
    }
    
    static func makeAnnouncementItems(from json: JSON) -> [AnnouncementItem] {
        json.arrayValue.map { makeAnnouncementItem(from: $0) }
    }
}

extension String {
    
    func toDate() -> Date? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: trimmed) {
            return date
        }
        
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: trimmed) {
            return date
        }
        
        let dateFormats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd"
        ]
        
        for dateFormat in dateFormats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = dateFormat
            
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        
        return nil
    }
    
}

// MARK: - 示例 JSON

/*
 下面这些 JSON 是给后端接口用的示例格式。
 推荐统一返回结构：
 {
   "code": 200,
   "message": "success",
   "data": ...
 }
 
 注意：
 1. Date 建议统一使用 ISO8601 字符串，例如："2026-05-25T08:00:00Z"
 2. 可为空字段可以返回 null
 3. 数组字段即使没有数据，也建议返回 []，这样客户端解析更稳定
 */

/*
MARK: - 学校信息 /school_profile.php?schoolID=1

{
  "code": 200,
  "message": "success",
  "data": {
    "schoolID": 1,
    "schoolName": "测试学校",
    "schoolLogo": "https://example.com/school-logo.png",
    "schoolAddress": ["测试省", "测试市", "测试区"],
    "schoolCalendar": "BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR",
    "areaIDs": [1],
    "compoundIDs": [],
    "createdAt": "2026-05-27 16:57:23",
    "updatedAt": "2026-06-03 17:23:20"
  }
}
*/

/*
MARK: - 校区列表 /campuses.php?schoolID=1

{
  "code": 200,
  "message": "success",
  "data": [
    {
      "areaID": 1,
      "areaName": "主校区",
      "areaAddress": ["中国", "浙江省", "杭州市"],
      "schoolID": 1,
      "createdAt": "2026-05-25T00:00:00Z",
      "updatedAt": "2026-05-25T00:00:00Z"
    }
  ]
}
*/

/*
MARK: - 课程表 /course_table.php?schoolID=1&compoundID=1&departmentID=1&classID=1

{
  "code": 200,
  "message": "success",
  "data": {
    "tableID": 1,
    "schoolID": 1,
    "compoundID": 1,
    "departmentID": 1,
    "classID": 1,
    "content": "BEGIN:VCALENDAR\nVERSION:2.0\nEND:VCALENDAR",
    "createdAt": "2026-05-25T00:00:00Z",
    "updatedAt": "2026-05-25T00:00:00Z"
  }
}
*/

/*
 MARK: - 学校通知 /announcements?schoolID=1

 {
   "code": 200,
   "message": "success",
   "data": [
     {
       "announceID": 1,
       "schoolID": 1,
       "content": "今晚二楼窗口提前到 20:00 结束营业。",
       "type": 0,
       "target": {
         "allSchool": true,
         "areaIDs": [],
         "departmentIDs": [],
         "classIDs": [],
         "studentIDs": []
       },
       "startTime": "2026-05-25T00:00:00Z",
       "endTime": "2026-06-01T15:59:59Z",
       "createdAt": "2026-05-25T00:00:00Z",
       "updatedAt": "2026-05-25T00:00:00Z"
     },
     {
       "announceID": 2,
       "schoolID": 1,
       "content": "生活区 A 栋将在 14:00-16:00 临时停水，请提前储水。",
       "type": 1,
       "target": {
         "allSchool": false,
         "areaIDs": [1],
         "departmentIDs": [],
         "classIDs": [],
         "studentIDs": []
       },
       "startTime": "2026-05-25T00:00:00Z",
       "endTime": "2026-05-25T16:00:00Z",
       "createdAt": "2026-05-25T00:00:00Z",
       "updatedAt": "2026-05-25T00:00:00Z"
     },
     {
       "announceID": 3,
       "schoolID": 1,
       "content": "## 期末考试安排\n\n请同学们登录教务系统查看个人考试时间。\n\n- 考试周：第 18-19 周\n- 请携带学生证\n- 禁止携带电子设备",
       "type": 2,
       "target": {
         "allSchool": false,
         "areaIDs": [],
         "departmentIDs": [1, 2],
         "classIDs": [],
         "studentIDs": []
       },
       "startTime": "2026-05-25T00:00:00Z",
       "endTime": "2026-06-30T15:59:59Z",
       "createdAt": "2026-05-25T00:00:00Z",
       "updatedAt": "2026-05-25T00:00:00Z"
     }
   ]
 }
 */
