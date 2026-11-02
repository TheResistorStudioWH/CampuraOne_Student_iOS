import Foundation
import CamapKit

@MainActor private final class CatalogFixture {
    var productReads = 0
    var held: CheckedContinuation<Product, Never>?
    var holdProduct = false
    var failProduct = false
    let main = MainShop(shopID: 1, shopName: "食堂", shopAddress: nil, shopSlogan: nil, subShopsList: [1], productsList: [1, 2], adIDs: [], shopLogo: nil, shopImg: nil, saleIDs: [2], schoolID: 1, areaID: nil, accountID: 1)
    let sub = SubShop(shopID: 1, shopName: "咖啡档口", shopAddress: nil, productsList: [1], shopImg: nil, mainShopID: 1, saleList: [1, 2], takeOutLink: nil, accountID: 2)
    let product = Product(productID: 1, productName: "咖啡", productPrice: 12, productImg: nil, productIntro: nil, mainShopID: 1, subShopID: 1)
    let direct = Product(productID: 2, productName: "米饭", productPrice: 2, productImg: nil, productIntro: nil, mainShopID: 1, subShopID: nil)
    func repository() -> ContentPreviewRepository {
        ContentPreviewRepository(client: .init(schoolID: { 1 }, shops: { _ in [self.main] }, subShops: { _ in [self.sub] }, product: { id in
            self.productReads += 1
            if self.failProduct { throw APIClientError.invalidPayload("removed") }
            if self.holdProduct { self.holdProduct = false; return await withCheckedContinuation { self.held = $0 } }
            await Task.yield()
            return id == 2 ? self.direct : self.product
        }, products: { reference in
            if case .subShop = reference { return [self.product] }
            return [self.product, self.direct]
        }, promotions: {
            [SaleEvent(saleID: 1, productID: 1, saleRule: "第二杯半价", startTime: .distantPast, endTime: .distantFuture),
             SaleEvent(saleID: 2, productID: nil, saleRule: "全店活动", startTime: .distantPast, endTime: .distantFuture),
             SaleEvent(saleID: 3, productID: nil, saleRule: "无归属", startTime: .distantPast, endTime: .distantFuture),
             SaleEvent(saleID: 4, productID: 1, saleRule: "过期", startTime: .distantPast, endTime: .distantPast)]
        }, boundPlace: { _ in nil }))
    }
}

@main @MainActor struct ContentPreviewChecks {
    static var count = 0
    static func check(_ value: @autoclosure () -> Bool, _ message: String) {
        precondition(value(), message); count += 1
    }

    static func main() async throws {
        let fixture = CatalogFixture()
        let repository = fixture.repository()
        repository.bind(userID: 1)
        async let first = repository.detail(.product(1))
        async let duplicate = repository.detail(.product(1))
        let (product, same) = try await (first, duplicate)
        check(fixture.productReads == 1 && product.id == same.id, "Concurrent detail requests are coalesced")
        check(product.merchants.first?.id == "sub-shop-1", "A product navigates to its actual sub-shop")
        check(product.promotions.map(\.saleID) == [1], "Expired promotions are excluded from product offers")
        let direct = try await repository.detail(.product(2))
        check(direct.merchants.first?.id == "main-shop-1", "Direct products retain the main-shop owner")
        let main = try await repository.detail(.mainShop(1))
        let sub = try await repository.detail(.subShop(1, mainShopID: nil))
        check(main.title != sub.title && main.id != sub.id, "Equal numeric main/sub IDs never collide")
        check(main.children.count == 1 && sub.parent?.id == main.id, "Parent and child browse links are preserved")
        check(repository.boundPlace(for: product.merchants[0]) == nil, "An absent formal map binding never guesses a destination")
        let multi = try await repository.detail(.promotion(2))
        check(Set(multi.merchants.map(\.id)) == ["main-shop-1", "sub-shop-1"], "Unbound-product promotion preserves explicitly associated shops")
        let orphan = try await repository.detail(.promotion(3))
        check(orphan.merchants.isEmpty, "Orphan promotions never inherit an arbitrary shop")
        check(CampusContentReference.search(kind: "shop", id: "sub-shop-1", targetID: 1)?.id == "sub-shop-1", "Search preserves the sub-shop namespace")
        check(CampusContentReference.search(kind: "shop", id: "shop-1", targetID: 1) == nil, "Ambiguous legacy shop references are not routed as a main shop")
        let browser = ContentBrowserStore(repository: repository)
        browser.bind(userID: 1); browser.open(.mainShop(1))
        let root = browser.current!
        root.categoryID = 2; root.scrollID = "product-2"
        browser.push(.product(1)); browser.back()
        check(browser.current === root && root.categoryID == 2 && root.scrollID == "product-2", "Back restores the existing page's category and scroll anchor")
        browser.open(.product(1)); let page = browser.current!
        await page.model.load(); browser.didLoad(page)
        check(browser.recent?.id == "product-1", "Successfully loaded content updates recent browsing")
        browser.bind(userID: nil)
        check(!browser.isPresented && browser.recent == nil, "Logout clears preview and recent browsing")

        repository.bind(userID: 1); fixture.holdProduct = true
        let late = Task { try await repository.detail(.product(1)) }
        while fixture.held == nil { await Task.yield() }
        repository.bind(userID: 2)
        fixture.held?.resume(returning: fixture.product); fixture.held = nil
        do { _ = try await late.value; fatalError("Late account response was accepted") } catch { check(true, "Late account response cannot publish into a new account") }

        try await routePreview()
        print("Content preview checks passed: \(count)")
    }

    static func routePreview() async throws {
        let json = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))) as! [String: Any]
        let examples = json["examples"] as! [[String: Any]]
        let data = (examples[0]["response"] as! [String: Any])["data"] as! [String: Any]
        let plan = try NavigationCoding.decoder().decode(NavigationPlan.self, from: JSONSerialization.data(withJSONObject: data))
        var commands: [NavigationCommand] = []
        let navigation = StudentNavigationStore(client: .init(send: { command in
            commands.append(command)
            if command.action == .end { return .ended(sessionID: command.sessionID!) }
            return .plan(plan)
        }, feedback: { _ in .init(recorded: false, reasonCode: "history_disabled") }, source: { _ in nil }))
        navigation.bind(userID: 1)
        let frameID = plan.route!.frameId
        let a = "20000000-0000-4000-8000-000000000001", b = "20000000-0000-4000-8000-000000000002"
        let document = CamapDocument(id: "20000000-0000-4000-8000-000000000003", frames: [.init(id: frameID, name: "校园")],
            nodes: [.init(id: a, frameId: frameID, position: Point(0, 0), name: "出发路口"), .init(id: b, frameId: frameID, position: Point(20, 0), name: "教学路口")],
            edges: [.init(id: "20000000-0000-4000-8000-000000000004", frameId: frameID, from: a, to: b)])
        let map = CampusMapStore(client: .init(school: { 1 }, fetch: { _, _ in .document(.init(schoolID: 1, document: document, etag: plan.mapHash)) }))
        let preview = RoutePreviewStore(navigation: navigation, map: map)
        preview.bind(userID: 1); preview.open(.nextCourse)
        await preview.prepare()
        check(preview.isSelectingOrigin && commands.isEmpty, "Uncalibrated map waits for a manual origin without a request")
        check(preview.originOptions.count == 2, "Manual origins come from connected published nodes")
        await preview.selectOrigin(preview.originOptions[0])
        check(commands.last?.action == .start && commands.last?.recommendationsEnabled == false, "Preview only starts after origin selection, with proactive AI disabled")
        check(navigation.presentationMode == .preview && !navigation.isGuiding, "A ready preview never enables navigation guidance")
        let before = commands.count
        await navigation.updateLocation(.node(id: b, frameID: frameID), at: .distantFuture)
        check(commands.count == before, "GPS updates never mutate a route preview")
        let origin = preview.origin
        map.displayMode = .original; map.displayMode = .drawing
        check(preview.origin == origin && navigation.plan != nil, "Basemap switches keep route and selected origin")
        preview.close()
        check(navigation.plan == nil && !preview.isPresented, "Closing clears the route immediately")
        for _ in 0..<30 { await Task.yield() }
        check(commands.last?.action == .end && commands.last?.expectedContextVersion == plan.contextVersion, "Closing attempts server cleanup with the known version")

        var held: CheckedContinuation<NavigationResult, Never>?
        var cleanups = 0
        let lateStore = StudentNavigationStore(client: .init(send: { command in
            if command.action == .end { cleanups += 1; return .ended(sessionID: command.sessionID!) }
            return await withCheckedContinuation { held = $0 }
        }, feedback: { _ in .init(recorded: false, reasonCode: nil) }, source: { _ in nil }))
        lateStore.bind(userID: 1)
        let request = Task { await lateStore.startPreview(origin: .node(id: a, frameID: frameID), destination: nil) }
        while held == nil { await Task.yield() }
        lateStore.discardPreview()
        held?.resume(returning: .plan(plan))
        await request.value
        check(lateStore.plan == nil && lateStore.presentationMode == .none, "A response arriving after close cannot restore the route")
        check(cleanups == 1, "A late successful start is cleaned up once without replaying the start")
    }
}
