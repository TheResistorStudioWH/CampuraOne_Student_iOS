//
//  DataTable.swift
//  CampuraOne
//
//  Created by LShayc1own on 21/05/2026.
//

import SwiftUI
import Combine

// 数据模型：主商户
struct MainShop: Codable, Identifiable {
    
    var id: Int { shopID }
    
    let shopID: Int // 商户ID
    let shopName: String // 商户名称
    let shopAddress: [String]? // 商户地址，可为空
    let shopSlogan: String? // 商户宣传语，可为空
    let subShopsList: [Int]? // 附属商户ID列表，可为空
    let productsList: [Int]? // 商品ID列表，可为空
    let adIDs: [Int]? // 广告ID，可为空
    let shopLogo: String? // 商户Logo链接，可为空
    let shopImg: String? // 商户实拍图链接，可为空
    let saleIDs: [Int]? // 促销事件ID列表，可为空
    let schoolID: Int // 所属学校ID
    let areaID: Int? // 所属校区ID，可为空
    let accountID: Int // 管理员账户ID
}

// 数据模型：附属商户
struct SubShop: Codable, Identifiable {
    
    var id: Int { shopID }
    
    let shopID: Int // 商户ID
    let shopName: String // 商户名称
    let shopAddress: [String]? // 商户地址，可为空
    let productsList: [Int]? // 商品ID列表，可为空
    let shopImg: String? // 商户实拍图链接，可为空
    let mainShopID: Int // 所属主商户ID
    let saleList: [Int]? // 促销事件ID列表，可为空
    let takeOutLink: String? // 外卖服务链接，可为空
    let accountID: Int // 管理员账户ID
}

// 数据模型：商品分类
struct ProductCategory: Codable, Identifiable {
    
    var id: Int { categoryID }
    
    let categoryID: Int // 分类ID
    let categoryName: String // 分类名称
    let categoryIcon: String? // SF Symbol 名称，可为空
    let categoryColor: String? // 分类颜色标识，可为空
    let createdAt: Date? // 创建时间，可为空
    let updatedAt: Date? // 更新时间，可为空
}

// 数据模型：商品
struct Product: Codable, Identifiable {
    
    var id: Int { productID }
    
    let productID: Int // 商品ID
    let productName: String // 商品名称
    var categoryID: Int? = nil // 商品分类ID，可为空
    var category: ProductCategory? = nil // 后端联表返回的分类详情，可为空
    let productPrice: Double // 商品价格
    let productImg: String? // 商品图片链接，可为空
    let productIntro: String? // 商品介绍，可为空
    let mainShopID: Int // 所属主商户ID
    let subShopID: Int? // 所属附属商户ID，可为空。为空时表示主商户直营商品
}
