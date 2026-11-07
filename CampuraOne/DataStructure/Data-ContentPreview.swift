import Foundation
import CamapKit

/// IDs in main_shops and sub_shops are independent namespaces.
enum CampusContentReference: Hashable, Identifiable {
    case mainShop(Int)
    case subShop(Int, mainShopID: Int?)
    case product(Int)
    case promotion(Int)
    case place(String)

    var id: String {
        switch self {
        case .mainShop(let id): return "main-shop-\(id)"
        case .subShop(let id, _): return "sub-shop-\(id)"
        case .product(let id): return "product-\(id)"
        case .promotion(let id): return "promotion-\(id)"
        case .place(let id): return "place-\(id)"
        }
    }

    static func search(kind: String, id: String, targetID: Int) -> Self? {
        guard targetID > 0 else { return nil }
        switch kind {
        case "product": return .product(targetID)
        case "promotion": return .promotion(targetID)
        case "shop" where id == "main-shop-\(targetID)": return .mainShop(targetID)
        case "shop" where id == "sub-shop-\(targetID)": return .subShop(targetID, mainShopID: nil)
        default: return nil
        }
    }
}

enum ContentMerchant: Identifiable {
    case main(MainShop)
    case sub(SubShop)

    var reference: CampusContentReference {
        switch self {
        case .main(let shop): return .mainShop(shop.shopID)
        case .sub(let shop): return .subShop(shop.shopID, mainShopID: shop.mainShopID)
        }
    }
    var id: String { reference.id }
    var name: String {
        switch self { case .main(let shop): return shop.shopName; case .sub(let shop): return shop.shopName }
    }
    var address: String? {
        switch self { case .main(let shop): return shop.shopAddress?.displayText; case .sub(let shop): return shop.shopAddress?.displayText }
    }
    var imageURL: String? {
        switch self { case .main(let shop): return shop.shopImg ?? shop.shopLogo; case .sub(let shop): return shop.shopImg }
    }
    var saleIDs: [Int] {
        switch self { case .main(let shop): return shop.saleIDs ?? []; case .sub(let shop): return shop.saleList ?? [] }
    }
}

struct ContentPreviewDetail: Identifiable {
    let reference: CampusContentReference
    let title: String
    var subtitle: String?
    var imageURL: String?
    var introduction: String?
    var product: Product?
    var promotion: SaleEvent?
    var merchants: [ContentMerchant] = []
    var children: [ContentMerchant] = []
    var products: [Product] = []
    var promotions: [SaleEvent] = []
    var parent: ContentMerchant?
    var id: String { reference.id }
}

enum RoutePreviewTarget: Equatable {
    case place(id: String, name: String, frameID: String?)
    case nextCourse

    var title: String {
        switch self { case .place(_, let name, _): return name; case .nextCourse: return "前往上课地点" }
    }
    var destination: String? {
        switch self { case .place(let id, _, _): return id; case .nextCourse: return nil }
    }
    var frameID: String? {
        switch self { case .place(_, _, let id): return id; case .nextCourse: return nil }
    }
}

// MARK: - “你刚看过”的数据类型

/// 最近浏览的内容有两种可能：
/// 1. 一个商品
/// 2. 一个促销事件
///
/// enum 的 case 可以携带不同类型的数据，这种写法叫“关联值”
/// 我之前居然还没用过这个带括号的语法,都傻愣愣的写返回类型然后在那对id…
/// 这样就不需要为了商品和促销分别再保存两个可选变量
enum RecentlyViewedItem: Identifiable {
    case product(Product)
    case sale(SaleEvent)
    
    
    var id: String {
        switch self {
        case .product(let product):
            return "product-\(product.productID)"
        case .sale(let sale):
            return "sale-\(sale.saleID)"
        }
    }
    
    var contentReference: CampusContentReference {
        switch self {
        case .product(let product): return .product(product.productID)
        case .sale(let sale): return .promotion(sale.saleID)
        }
    }

    var title: String {
        switch self {
        case .product(let product):
            return product.productName
        case .sale(let sale):
            return sale.saleRule ?? "促销活动"
        }
    }
    
    var description: String {
        switch self {
        case .product(let product):
            return product.category?.categoryName ?? "商品"
        case .sale:
            return "促销事件"
        }
    }
    
    var icon: String {
        switch self {
        case .product(let product):
            return product.category?.categoryIcon ?? "shippingbox.fill"
        case .sale:
            return "tag.fill"
        }
    }
}


/// Business identity comes from the published association, never a feature name.
nonisolated struct CampusMerchantBindings: Decodable, Sendable {
    struct Location: Decodable, Sendable {
        let masterId: String
        let mapRevision: Int
        let placeID: String
        let frameId: String
        let buildingId: String?
        let levelId: String?
    }
    struct Entry: Decodable, Sendable, Identifiable {
        let placeID: String
        let shopType: String
        let shopID: Int
        let mainShopID: Int
        let mapLocation: Location
        var id: String { placeID }
        var reference: CampusContentReference? {
            guard shopID > 0, mainShopID > 0 else { return nil }
            switch shopType {
            case "main" where shopID == mainShopID: return .mainShop(shopID)
            case "sub": return .subShop(shopID, mainShopID: mainShopID)
            default: return nil
            }
        }
    }
    let schoolID: Int
    let masterId: String
    let mapRevision: Int
    let mapHash: String
    let bindings: [Entry]

    func matches(_ snapshot: CampusMapSnapshot) -> Bool {
        schoolID == snapshot.schoolID && masterId == snapshot.document.masterId
            && mapRevision == snapshot.document.baseRevision && mapHash == snapshot.hash
    }

    func validatedEntries(in snapshot: CampusMapSnapshot) -> [Entry] {
        guard matches(snapshot) else { return [] }
        return bindings.filter { entry in
            let location = entry.mapLocation
            guard entry.reference != nil, entry.placeID == location.placeID,
                  location.masterId == masterId, location.mapRevision == mapRevision,
                  let feature = snapshot.document.features.first(where: { $0.id == entry.placeID }),
                  feature.kind == "merchant" else { return false }
            return feature.frameId == location.frameId && feature.buildingId == location.buildingId
                && feature.levelId == location.levelId
        }
    }
}
