#if DEBUG
import Foundation
import SwiftyJSON
import UIKit

/// Canvas 与独立离线构建使用；未知接口报错，不回退生产服务器。
@MainActor
enum PreviewAPI {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
            || ProcessInfo.processInfo.arguments.contains("--campura-preview")
            || Bundle.main.bundleIdentifier == "com.LX.CampuraOne.demo"
    }

    static let token = "preview.local.only"
    static let user: [String: Any] = [
        "userID": 1, "userName": "林同学", "studentID": 20260001, "shopIDs": []
    ]
    static let student: [String: Any] = [
        "studentID": 20260001, "studentName": "林同学", "schoolID": 1,
        "compoundID": 1, "departmentID": 2, "classID": 3
    ]
    private static let marketing: [String: Any] = {
        guard let url = Bundle.main.url(forResource: "catalog", withExtension: "json", subdirectory: "Marketing"),
              let data = try? Data(contentsOf: url),
              let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return value
    }()

    private static func marketingRows(_ key: String) -> [[String: Any]] {
        (marketing[key] as? [[String: Any]] ?? []).map { row in
            var row = row
            for key in ["productName", "saleRule"] {
                if let text = row[key] as? String {
                    row[key] = text.replacingOccurrences(of: "【演示】", with: "")
                        .replacingOccurrences(of: "；仅供项目展示，非商户真实优惠。", with: "")
                }
            }
            if (row["productIntro"] as? String)?.hasPrefix("【演示】") == true { row["productIntro"] = "" }
            if (row["shopSlogan"] as? String)?.hasPrefix("演示商户资料") == true { row["shopSlogan"] = "" }
            if let address = row["shopAddress"] as? [String] {
                row["shopAddress"] = address.map { $0.replacingOccurrences(of: "（演示）", with: "") }
            }
            return row
        }
    }

    static func localImage(url: String?) -> UIImage? {
        guard let url, let filename = (marketing["images"] as? [String: String])?[url],
              let path = Bundle.main.url(forResource: filename, withExtension: nil, subdirectory: "Marketing") else { return nil }
        if let image = images[url] { return image }
        guard let image = UIImage(contentsOfFile: path.path) else { return nil }
        images[url] = image
        return image
    }

    private static func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: .now))!
    }

    private static func iso(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static var assemblyDayText: String {
        Date() < day(0).addingTimeInterval(13 * 3600) ? "今天" : "明天"
    }

    private static var inspectionDayText: String {
        assemblyDayText == "今天" ? "明天" : "后天"
    }

    static func response(url: String, parameters: [String: Any]?, method: String = "GET") throws -> JSON {
        let path = URL(string: url)?.lastPathComponent ?? url
        let parameters = parameters ?? [:]
        if ["campus_map.php", "preferences.php", "feedback.php", "plan.php"].contains(path) {
            return try PreviewNavigation.response(path: path, method: method, parameters: parameters)
        }
        let data: Any
        switch path {
        case "login.php": data = ["token": token, "user": user]
        case "user_profile.php": data = user
        case "student_profile.php": data = student
        case "school_profile.php":
            data = ["schoolID": 1, "schoolName": "Campura大学", "schoolAddress": ["湖北省", "武汉市", "江夏区"],
                    "areaIDs": [1], "compoundIDs": [1], "schoolCalendar": calendarICS]
        case "campuses.php":
            data = [["areaID": 1, "areaName": "主校区", "schoolID": 1, "areaAddress": ["武汉市", "江夏区"]]]
        case "course_table.php":
            data = ["tableID": 1, "schoolID": 1, "compoundID": 1, "departmentID": 2, "classID": 3, "content": courseICS]
        case "school_calendar.php": data = ["calendarID": 1, "content": calendarICS]
        case "main_shops.php": data = marketingRows("shops")
        case "sub_shops.php": data = [] as [[String: Any]]
        case "product_categories.php":
            let categories = marketingRows("categories")
            if let id = parameters["categoryID"] as? Int {
                data = categories.first { $0["categoryID"] as? Int == id } ?? [:]
            } else { data = categories }
        case "products.php":
            data = marketingRows("products").filter { row in
                ["productID", "mainShopID", "subShopID", "categoryID"].allSatisfy { key in
                    parameters[key] == nil || row[key] as? Int == parameters[key] as? Int
                }
            }
        case "promotions.php":
            data = marketingRows("promotions").filter { row in
                (parameters["productID"] == nil || row["productID"] as? Int == parameters["productID"] as? Int)
                && (parameters["onlyActive"] as? Int != 1 || JSONMapper.makePromotionEvent(from: JSON(row)).isActive())
            }
        case "advertisements.php":
            data = advertisementRows.filter {
                (parameters["type"] == nil || $0["type"] as? String == parameters["type"] as? String)
                && (parameters["saleID"] == nil || $0["saleID"] as? Int == parameters["saleID"] as? Int)
            }
        case "announcements.php":
            let messages = [
                "辅导员通知：\(assemblyDayText)下午一点到操场集合，依次排队完成班级投票选票。请携带学生证，按班级顺序入场。",
                "\(inspectionDayText)晚上开展宿舍检查。请同学们提前整理寝室，保持消防通道畅通。",
                "教学楼附近正在施工，请绕行围挡区域，注意安全，勿从施工入口通行。",
                "本周校园活动征集志愿者，协助现场引导与秩序维护。有意参加的同学请联系班委报名。"
            ]
            data = messages.enumerated().map { index, message -> [String: Any] in
                ["announceID": index + 1, "schoolID": 1, "version": 1, "content": message, "type": index < 2 ? 1 : 0,
                 "target": ["allSchool": true], "startTime": iso(day(-1)), "endTime": iso(day(7)),
                 "createdAt": iso(day(-1).addingTimeInterval(Double(index) * 60))]
            }.filter {
                (parameters["type"] == nil || $0["type"] as? Int == parameters["type"] as? Int)
                && (parameters["announceID"] == nil || $0["announceID"] as? Int == parameters["announceID"] as? Int)
            }
        case "announcement_summary.php":
            data = ["summary": "\(assemblyDayText)下午一点到操场参加班级投票；\(inspectionDayText)晚上查寝，请提前整理宿舍；教学楼施工区域注意安全；校园活动正在征集志愿者。", "sourceIDs": [1, 2, 3, 4], "isAI": true]
        case "search.php":
            let query = (parameters["q"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let mode = parameters["mode"] as? String ?? "all"
            let products = marketingRows("products")
            let shops = marketingRows("shops")
            let productRows: [[String: Any]] = products.map { product in
                ["type": "product", "targetID": product["productID"]!, "title": product["productName"]!,
                 "subtitle": "¥\(product["price"] ?? "")", "imageURL": product["productImg"] ?? ""]
            }
            let promotionRows: [[String: Any]] = marketingRows("promotions").map { sale in
                let product = products.first { $0["productID"] as? Int == sale["productID"] as? Int }
                return ["type": "promotion", "targetID": sale["saleID"]!, "title": sale["saleRule"]!,
                        "subtitle": product?["productName"] ?? "", "imageURL": product?["productImg"] ?? ""]
            }
            let shopRows: [[String: Any]] = shops.map { shop in
                ["id": "main-shop-\(shop["shopID"]!)", "type": "shop", "targetID": shop["shopID"]!,
                 "title": shop["shopName"]!, "subtitle": (shop["shopAddress"] as? [String] ?? []).joined(separator: " · ")]
            }
            let rowsWithSubShop = promotionRows + productRows + shopRows
            let matches = rowsWithSubShop.filter { row in
                (mode == "all" || mode == "smart" || row["type"] as? String == mode)
                && (query.isEmpty || "\(row["title"] ?? "") \(row["subtitle"] ?? "")".localizedCaseInsensitiveContains(query))
            }
            let results = Array(matches.dropFirst(max(0, parameters["offset"] as? Int ?? 0)).prefix(max(0, parameters["limit"] as? Int ?? 20)))
            data = ["results": results, "suggestions": mode == "smart" ? Array(results.prefix(2)) : []]
        default:
            throw APIClientError.invalidPayload("此内容暂不可用：\(path)")
        }
        return JSON(["code": 200, "message": "Local preview data", "data": data])
    }

    static var advertisementRows: [[String: Any]] {
        marketingRows("advertisements").filter { JSONMapper.makeAdvertisement(from: JSON($0)).isActive() }
    }

    static var courseICS: String {
        // A rolling week keeps every course insight visible during rehearsal.
        let week: [[(String, Int, String)]] = [
            [("高等数学", 8, "教学楼 201室"), ("软件工程", 14, "教学楼 203室")],
            [("大学英语", 10, "教学楼 202室"), ("程序设计", 15, "教学楼 204室")],
            [("数据结构", 14, "教学楼 203室"), ("晚自习", 19, "图书馆自习区")],
            [("计算机网络", 8, "教学楼 201室"), ("体育", 10, "操场")],
            [("软件工程", 10, "教学楼 203室"), ("项目实践", 14, "教学楼 204室"), ("晚自习", 19, "图书馆自习区")],
            [("社团实践", 14, "学生活动中心")],
            [("大学英语", 10, "教学楼 202室")]
        ]
        let events = (-7...21).flatMap { offset in
            let courses = week[((offset % 7) + 7) % 7]
            return courses.enumerated().map { index, course in
                event(uid: "course-\(offset)-\(index)", title: course.0, day: offset,
                      hour: course.1, duration: 90, location: course.2)
            }
        }
        return calendar(events)
    }

    static var calendarICS: String {
        calendar([event(uid: "calendar-1", title: "社团开放日", day: 0, hour: 16, duration: 120, location: "学生活动中心"),
                  event(uid: "calendar-2", title: "校园运动会", day: 2, hour: 9, duration: 420, location: "田径场"),
                  event(uid: "calendar-3", title: "选课截止", day: 5, hour: 18, duration: 60, location: "教务系统")])
    }

    private static func calendar(_ events: [String]) -> String {
        (["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Campura//Preview//CN"] + events + ["END:VCALENDAR"]).joined(separator: "\r\n")
    }

    private static func event(uid: String, title: String, day offset: Int, hour: Int, duration: Int, location: String) -> String {
        let start = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: day(offset))!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return ["BEGIN:VEVENT", "UID:\(uid)@preview", "DTSTAMP:\(formatter.string(from: day(0)))",
                "SUMMARY:\(title)", "DTSTART:\(formatter.string(from: start))",
                "DTEND:\(formatter.string(from: start.addingTimeInterval(Double(duration) * 60)))",
                "LOCATION:\(location)", "DESCRIPTION:校园日程", "END:VEVENT"].joined(separator: "\r\n")
    }

    /// Bundled images are decoded once per app process; no network/cache fallback.
    private static var images: [String: UIImage] = [:]
}
#endif
