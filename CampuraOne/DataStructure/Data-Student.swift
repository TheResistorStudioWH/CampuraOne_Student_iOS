//
//  Data-Student.swift
//  CampuraOne
//
//  Created by LShayc1own on 21/05/2026.
//

import Foundation
import SwiftData

// 数据模型：用户
@Model
final class AppUser {
    @Attribute(.unique) var userID: Int // 用户ID
    
    var userName: String // 用户名称
    var userImg: String? // 用户头像，可为空
    
    
    var shopIDs: [Int] // 管理的商户ID列表，可为空
    var studentID: Int? // 绑定的学生ID，可为空
    var createdAt: Date? // 创建时间
    var updatedAt: Date? // 更新时间
    
    init(
        userID: Int,
        userName: String,
        userImg: String? = nil,
        shopIDs: [Int] = [],
        studentID: Int? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.userID = userID
        self.userName = userName
        self.userImg = userImg
        self.shopIDs = shopIDs
        self.studentID = studentID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - AppUser 头像相关方法

extension AppUser {
    
    /// 用户头像 URL
    /// 只负责把 String 转成 URL，不在这里直接写 UI
    var avatarURL: URL? {
        guard let userImg else { return nil }
        return URL(string: userImg)
    }
    
    /// 是否有可用头像
    var hasAvatar: Bool {
        avatarURL != nil
    }
}

// 数据模型：学生
@Model
final class Student {
    @Attribute(.unique) var studentID: Int // 学生ID
    
    var studentName: String // 学生姓名
    var gender: String? // 学生性别，可为空
    var schoolID: Int // 所属学校ID
    var compoundID: Int // 所属院ID
    var departmentID: Int // 所属系ID
    var classID: Int // 所属班级ID
    var createdAt: Date? // 创建时间
    var updatedAt: Date? // 更新时间
    
    init(
        studentID: Int,
        studentName: String,
        gender: String? = nil,
        schoolID: Int,
        compoundID: Int,
        departmentID: Int,
        classID: Int,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.studentID = studentID
        self.studentName = studentName
        self.gender = gender
        self.schoolID = schoolID
        self.compoundID = compoundID
        self.departmentID = departmentID
        self.classID = classID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
