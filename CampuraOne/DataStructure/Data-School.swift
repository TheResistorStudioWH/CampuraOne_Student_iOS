//
//  Data-School.swift
//  CampuraOne
//
//  Created by LShayc1own on 21/05/2026.
//

import Foundation
import SwiftData

// 数据模型：学校
@Model
final class School {
    @Attribute(.unique) var schoolID: Int // 学校ID
    
    var schoolName: String // 学校名称
    var schoolAddress: [String]? // 学校地址，数据库中为 JSON，可为空
    var schoolLogo: String? // 学校Logo链接，可为空
    
    // 管理员登录密码 Hash
    // 对应数据库 schools.passwordHash / password_hash 一类字段。
    // 注意：正式项目里客户端一般不应该长期保存密码 Hash，之后登录完成后更推荐保存 token。
    var passwordHash: String?
    
    var areaIDs: [Int] // 包含的校区ID列表
    var compoundIDs: [Int] // 包含的院ID列表
    var schoolCalendar: String? // 校历（ICS格式），可为空
    var createdAt: Date? // 创建时间，可为空
    var updatedAt: Date? // 更新时间，可为空
    
    init(
        schoolID: Int,
        schoolName: String,
        schoolAddress: [String]? = nil,
        schoolLogo: String? = nil,
        passwordHash: String? = nil,
        areaIDs: [Int] = [],
        compoundIDs: [Int] = [],
        schoolCalendar: String? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.schoolID = schoolID
        self.schoolName = schoolName
        self.schoolAddress = schoolAddress
        self.schoolLogo = schoolLogo
        self.passwordHash = passwordHash
        self.areaIDs = areaIDs
        self.compoundIDs = compoundIDs
        self.schoolCalendar = schoolCalendar
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// 数据模型：校区
@Model
final class Campus {
    @Attribute(.unique) var areaID: Int // 校区ID
    
    var areaName: String // 校区名称
    var areaAddress: [String]? // 校区地址，数据库中为 JSON，可为空
    var schoolID: Int // 所属学校ID
    var createdAt: Date? // 创建时间，可为空
    var updatedAt: Date? // 更新时间，可为空
    
    init(
        areaID: Int,
        areaName: String,
        areaAddress: [String]? = nil,
        schoolID: Int,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.areaID = areaID
        self.areaName = areaName
        self.areaAddress = areaAddress
        self.schoolID = schoolID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// 数据模型：校历
@Model
final class SchoolCalendar {
    
    @Attribute(.unique) var calendarID: Int // 校历ID
    var content: String // 校历内容（ICS格式）
    
    init(
        calendarID: Int,
        content: String
    ) {
        self.calendarID = calendarID
        self.content = content
    }
    
}

// 数据模型：课程表
@Model
final class CourseTable {
    @Attribute(.unique) var tableID: Int // 课程表ID
    
    var schoolID: Int // 所属学校ID
    var compoundID: Int // 所属院ID
    var departmentID: Int // 所属系ID
    var content: String // 课程表内容（ICS格式）
    var classID: Int // 所属班级ID
    var createdAt: Date? // 创建时间，可为空
    var updatedAt: Date? // 更新时间，可为空
    
    init(
        tableID: Int,
        schoolID: Int,
        compoundID: Int,
        departmentID: Int,
        content: String,
        classID: Int,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.tableID = tableID
        self.schoolID = schoolID
        self.compoundID = compoundID
        self.departmentID = departmentID
        self.content = content
        self.classID = classID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
