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
        boundPlace: { reference in
            #if DEMO
            // The bundled campus has no verified binding for the local coffee fixture.
            return nil
            #else
            #if DEBUG
            if PreviewAPI.isEnabled, case .subShop(1, _) = reference {
                return .place(id: PreviewNavigation.merchantID, name: "生活区咖啡窗口", frameID: PreviewNavigation.frameID)
            }
            #endif
            // The current production contract has no merchant-to-CAMAP binding.
            // Never infer one from a matching name, address, or numeric shop ID.
            return nil
            #endif
        }
    )))
}
