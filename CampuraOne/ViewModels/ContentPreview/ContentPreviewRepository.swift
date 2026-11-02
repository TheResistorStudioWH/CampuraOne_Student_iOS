import Foundation

/// Session-scoped catalog. Coalesces detail/directory requests without persisting
/// merchant records or allowing a late response to cross student accounts.
@MainActor
final class ContentPreviewRepository {
    struct Client {
        var schoolID: () async throws -> Int
        var shops: (Int) async throws -> [MainShop]
        var subShops: (Int) async throws -> [SubShop]
        var product: (Int) async throws -> Product
        var products: (CampusContentReference) async throws -> [Product]
        var promotions: () async throws -> [SaleEvent]
        var boundPlace: (CampusContentReference) -> RoutePreviewTarget?
    }
    private let client: Client
    private var userID: Int?
    private var generation = UUID()
    private var details: [String: ContentPreviewDetail] = [:]
    private var detailDates: [String: Date] = [:]
    private var directoryDate = Date.distantPast
    private var requests: [String: Task<ContentPreviewDetail, Error>] = [:]
    private var shopRequest: Task<[MainShop], Error>?
    private var subRequests: [Int: Task<[SubShop], Error>] = [:]
    private var promotionRequest: Task<[SaleEvent], Error>?

    init(client: Client) { self.client = client }

    func bind(userID: Int?) {
        guard self.userID != userID else { return }
        self.userID = userID
        generation = UUID()
        requests.values.forEach { $0.cancel() }
        shopRequest?.cancel(); subRequests.values.forEach { $0.cancel() }; promotionRequest?.cancel()
        details = [:]; detailDates = [:]; directoryDate = .distantPast
        requests = [:]; shopRequest = nil; subRequests = [:]; promotionRequest = nil
    }

    func boundPlace(for merchant: ContentMerchant) -> RoutePreviewTarget? { client.boundPlace(merchant.reference) }

    func detail(_ reference: CampusContentReference, refresh: Bool = false) async throws -> ContentPreviewDetail {
        guard userID != nil else { throw APIClientError.invalidPayload("请先登录") }
        if !refresh, let date = detailDates[reference.id], Date().timeIntervalSince(date) < 60,
           let detail = details[reference.id] { return detail }
        if requests.isEmpty, Date().timeIntervalSince(directoryDate) >= 60 {
            shopRequest = nil; subRequests = [:]; promotionRequest = nil
            directoryDate = Date()
        }
        let ticket = generation
        let request: Task<ContentPreviewDetail, Error>
        if let pending = requests[reference.id] { request = pending }
        else {
            request = Task { try await self.fetchDetail(reference) }
            requests[reference.id] = request
        }
        defer { if ticket == generation { requests[reference.id] = nil } }
        let result = try await request.value
        try check(ticket)
        details[reference.id] = result
        detailDates[reference.id] = Date()
        return result
    }

    private func check(_ ticket: UUID) throws {
        try Task.checkCancellation()
        guard generation == ticket else { throw CancellationError() }
    }

    private func shops() async throws -> [MainShop] {
        if let task = shopRequest { return try await task.value }
        let ticket = generation
        let task = Task {
            let school = try await client.schoolID()
            try check(ticket)
            return try await client.shops(school).filter { $0.schoolID == school }
        }
        shopRequest = task
        do { let value = try await task.value; try check(ticket); return value }
        catch { if ticket == generation { shopRequest = nil }; throw error }
    }

    private func subShops(_ parentID: Int) async throws -> [SubShop] {
        if let task = subRequests[parentID] { return try await task.value }
        let ticket = generation
        let task = Task { try await client.subShops(parentID).filter { $0.mainShopID == parentID } }
        subRequests[parentID] = task
        do { let value = try await task.value; try check(ticket); return value }
        catch { if ticket == generation { subRequests[parentID] = nil }; throw error }
    }

    private func promotions() async throws -> [SaleEvent] {
        if let task = promotionRequest { return try await task.value }
        let ticket = generation
        let task = Task { try await client.promotions() }
        promotionRequest = task
        do { let value = try await task.value; try check(ticket); return value }
        catch { if ticket == generation { promotionRequest = nil }; throw error }
    }

    private func merchant(_ reference: CampusContentReference) async throws -> ContentMerchant {
        let mainShops = try await shops()
        switch reference {
        case .mainShop(let id):
            if let shop = mainShops.first(where: { $0.shopID == id }) { return .main(shop) }
        case .subShop(let id, let parentID):
            // Existing search identifies the sub-shop namespace but omits its
            // parent. Resolve only within this student's school directory.
            for parent in mainShops where parentID == nil || parent.shopID == parentID {
                if let shop = try await subShops(parent.shopID).first(where: { $0.shopID == id }) { return .sub(shop) }
            }
        default: break
        }
        throw APIClientError.invalidPayload("商家已移除或不属于当前学校")
    }

    private func owner(of product: Product) async throws -> ContentMerchant {
        try await merchant(product.subShopID.map { .subShop($0, mainShopID: product.mainShopID) } ?? .mainShop(product.mainShopID))
    }

    private func fetchDetail(_ reference: CampusContentReference) async throws -> ContentPreviewDetail {
        switch reference {
        case .mainShop, .subShop:
            let shop = try await merchant(reference)
            let products = try await client.products(shop.reference)
            let events = try await promotions()
            let productIDs = Set(products.map(\.productID))
            var detail = ContentPreviewDetail(reference: shop.reference, title: shop.name,
                subtitle: shop.address, imageURL: shop.imageURL, merchants: [shop], products: products,
                promotions: events.filter { $0.isActive() && (shop.saleIDs.contains($0.saleID) || $0.productID.map(productIDs.contains) == true) })
            switch shop {
            case .main(let main):
                detail.introduction = main.shopSlogan
                detail.children = try await subShops(main.shopID).map(ContentMerchant.sub)
            case .sub(let sub): detail.parent = try await merchant(.mainShop(sub.mainShopID))
            }
            return detail
        case .product(let id):
            let product = try await client.product(id)
            guard product.productID == id else { throw APIClientError.invalidPayload("商品已移除") }
            let shop = try await owner(of: product)
            return ContentPreviewDetail(reference: reference, title: product.productName,
                subtitle: product.category?.categoryName, imageURL: product.productImg,
                introduction: product.productIntro, product: product, merchants: [shop],
                promotions: try await promotions().filter { $0.productID == id && $0.isActive() })
        case .promotion(let id):
            guard let event = try await promotions().first(where: { $0.saleID == id }) else {
                throw APIClientError.invalidPayload("活动已移除或当前不可查看")
            }
            var detail = ContentPreviewDetail(reference: reference, title: event.displayTitle, promotion: event)
            if let productID = event.productID {
                let product = try await client.product(productID)
                guard product.productID == productID else { throw APIClientError.invalidPayload("活动关联商品已移除") }
                detail.product = product; detail.imageURL = product.productImg
                detail.merchants = [try await owner(of: product)]
            } else {
                for main in try await shops() {
                    if main.saleIDs?.contains(id) == true { detail.merchants.append(.main(main)) }
                    for sub in try await subShops(main.shopID) where sub.saleList?.contains(id) == true {
                        detail.merchants.append(.sub(sub))
                    }
                }
            }
            return detail
        case .place: throw APIClientError.invalidPayload("地点由已发布校园地图读取")
        }
    }
}
