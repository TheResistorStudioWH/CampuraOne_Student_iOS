import Foundation

extension RoutePreviewStore {
    static let shared = RoutePreviewStore(navigation: .shared, map: .shared)
}

extension ContentBrowserStore {
    static let shared = ContentBrowserStore(repository: ContentPreviewRepository(client: .init(
        schoolID: { try await RemoteDataService.shared.fetchMyStudentProfile().schoolID },
        shops: { try await RemoteDataService.shared.fetchMainShops(schoolID: $0) },
        subShops: { try await RemoteDataService.shared.fetchSubShops(mainShopID: $0) },
        product: { try await RemoteDataService.shared.fetchProduct(productID: $0) },
        products: { reference in
            switch reference {
            case .mainShop(let id): return try await RemoteDataService.shared.fetchProducts(mainShopID: id)
            case .subShop(let id, _): return try await RemoteDataService.shared.fetchProducts(subShopID: id)
            default: return []
            }
        },
        promotions: { try await RemoteDataService.shared.fetchPromotionEvents() },
        boundPlace: { CampusMapStore.shared.routeTarget(for: $0) }
    )))
}
