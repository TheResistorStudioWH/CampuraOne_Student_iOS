#if DEBUG
import Foundation
import SwiftyJSON
import UIKit

/// 仅 Xcode Canvas 启用。未知接口直接报错，绝不回退到生产服务器。
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
    private static let imageURL = "https://preview.invalid/campus.png"
    private static let category: [String: Any] = [
        "categoryID": 1, "categoryName": "餐饮", "categoryIcon": "cup.and.saucer.fill", "categoryColor": "#ED9237"
    ]
    private static let products: [[String: Any]] = [
        ["productID": 1, "productName": "校园拿铁", "price": 12.0,
         "categoryID": 1, "category": category, "productImg": imageURL,
         "productIntro": "课间的一杯咖啡。", "mainShopID": 1, "subShopID": 1],
        ["productID": 2, "productName": "手作三明治", "price": 9.9,
         "categoryID": 1, "category": category, "productImg": imageURL,
         "productIntro": "新鲜制作的课间轻食。", "mainShopID": 1, "subShopID": 1]
    ]
    private static let shop: [String: Any] = [
        "shopID": 1, "shopName": "校园咖啡", "shopSlogan": "课间休息一下",
        "shopAddress": ["湖北省", "武汉市", "江夏区", "校园生活区"],
        "shopLogo": imageURL, "shopImg": imageURL, "schoolID": 1,
        "areaID": 1, "accountID": 1, "productsList": [1, 2], "subShopsList": [1], "saleIDs": [1, 2]
    ]

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
        case "main_shops.php": data = [shop]
        case "sub_shops.php":
            data = [["shopID": 1, "mainShopID": 1, "accountID": 1, "shopName": "生活区咖啡窗口",
                     "shopImg": imageURL, "productsList": [1, 2], "saleList": [1, 2]]]
        case "product_categories.php": data = parameters["categoryID"] == nil ? [category] as Any : category
        case "products.php":
            data = products.filter { parameters["productID"] == nil || $0["productID"] as? Int == parameters["productID"] as? Int }
        case "promotions.php":
            data = (1...2).map { id -> [String: Any] in
                ["saleID": id, "productID": id, "saleRule": id == 1 ? "咖啡第二杯半价" : "课间轻食八五折",
                 "startTime": iso(day(-1)), "endTime": iso(day(7))]
            }.filter { parameters["productID"] == nil || $0["productID"] as? Int == parameters["productID"] as? Int }
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
                ["announceID": index + 1, "schoolID": 1, "version": 1, "content": message, "type": 0,
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
            let rows: [[String: Any]] = [
                ["type": "promotion", "targetID": 1, "title": "咖啡第二杯半价", "subtitle": "校园咖啡 · 本周有效", "imageURL": imageURL],
                ["type": "product", "targetID": 1, "title": "校园拿铁", "subtitle": "咖啡 · ¥12", "category": category, "imageURL": imageURL],
                ["type": "product", "targetID": 2, "title": "手作三明治", "subtitle": "轻食 · ¥9.9", "category": category, "imageURL": imageURL],
                ["id": "main-shop-1", "type": "shop", "targetID": 1, "title": "校园咖啡", "subtitle": "生活区 · 饮品与轻食", "imageURL": imageURL]
            ]
            let rowsWithSubShop = rows + [["id": "sub-shop-1", "type": "shop", "targetID": 1, "title": "生活区咖啡窗口", "subtitle": "校园咖啡 · 档口", "imageURL": imageURL]]
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
        (1...6).map { id in
            ["adID": id, "saleID": id % 2 + 1, "type": id <= 3 ? "L" : "S",
             "img": "https://preview.invalid/ad-\(id).png", "updatedAt": "preview-1",
             "startTime": iso(day(-1)), "endTime": iso(day(7))]
        }
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

    /// 直接在内存绘制占位图，不下载图片、不写入正式图片缓存。
    private static var images: [String: UIImage] = [:]

    static func image(index: Int = 0, banner: Bool = false) -> UIImage {
        let key = "\(index)-\(banner)"
        if let image = images[key] { return image }
        let size = CGSize(width: 600, height: banner ? 200 : 600)
        let image = UIGraphicsImageRenderer(size: size).image { context in
            let colors: [UIColor] = [.systemOrange, .systemTeal, .systemIndigo]
            colors[abs(index) % colors.count].setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let symbol = UIImage(systemName: ["cup.and.saucer.fill", "fork.knife", "book.fill"][abs(index) % 3])?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            let side = size.height * 0.32
            symbol?.draw(in: CGRect(x: (size.width - side) / 2, y: size.height * 0.16, width: side, height: side))
            let text = ["课间来杯咖啡", "今天吃点好的", "校园阅读时光"][abs(index) % 3]
            (text as NSString).draw(in: CGRect(x: 32, y: size.height * 0.62, width: size.width - 64, height: 70),
                                   withAttributes: [.font: UIFont.systemFont(ofSize: banner ? 27 : 34, weight: .semibold), .foregroundColor: UIColor.white])
        }
        images[key] = image
        return image
    }
}
#endif
