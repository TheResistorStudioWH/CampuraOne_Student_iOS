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
        root.categoryID = 2; root.placeLevelID = "floor-2"; root.placeQuery = "咖啡"; root.scrollID = "product-2"
        browser.push(.product(1)); browser.back()
        check(browser.current === root && root.categoryID == 2 && root.placeLevelID == "floor-2" && root.placeQuery == "咖啡" && root.scrollID == "product-2", "Back restores the existing page's category and scroll anchor")
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

        try await offlineMapMerchants()
        try await mapMerchants()
        try await routePreview()
        print("Content preview checks passed: \(count)")
    }

    static func offlineMapMerchants() async throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let document = try Camap.read(from: root.appendingPathComponent("CampuraOne/OfflineResources/school-1-v2.camap"))
        let data = try Data(contentsOf: root.appendingPathComponent("CampuraOne/OfflineResources/Marketing/map-merchants.json"))
        let rows = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
        let entries: [[String: Any]] = rows.map { row in
            ["placeID": (row["mapLocation"] as! [String: Any])["placeID"]!, "shopType": "main",
             "shopID": row["shopID"]!, "mainShopID": row["shopID"]!, "mapLocation": row["mapLocation"]!]
        }
        let object: [String: Any] = ["schoolID": 1, "masterId": document.masterId!,
            "mapRevision": document.baseRevision!, "mapHash": "fixture", "bindings": entries]
        let catalog = try JSONDecoder().decode(CampusMerchantBindings.self, from: JSONSerialization.data(withJSONObject: object))
        let snapshot = CampusMapSnapshot(schoolID: 1, document: document, etag: "fixture")
        check(rows.count == 106 && catalog.validatedEntries(in: snapshot).count == 106, "All offline merchants match the actual bundled map's UUID, frame, building, floor and revision")
        check(Set(catalog.bindings.map(\.placeID)).count == rows.count, "Offline merchant places are unique")
        let map = CampusMapStore(client: .init(school: { 1 }, fetch: { _, _ in .document(snapshot) }, merchants: { _ in catalog }))
        await map.load(userID: 1)
        check(map.merchantMarkers.reduce(0) { $0 + $1.count } == 106 && map.merchantMarkers.count < 106,
              "Indoor merchant markers group by their explicit building and preserve all shops")
        check(map.merchantMarkers.filter { $0.count > 1 }.allSatisfy { marker in
            if case .place(let id) = marker.reference { return document.features.contains { $0.id == id && $0.kind == "building" } }
            return false
        }, "Grouped shop markers open the actual published building")
        let original = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("CampuraOne/OfflineResources/Marketing/catalog.json"))) as! [String: Any]
        let fixtureShops = original["shops"] as! [[String: Any]]
        check(fixtureShops.allSatisfy { row in rows.contains { $0["shopID"] as? Int == row["shopID"] as? Int && ($0["mapLocation"] as! [String: Any])["placeID"] as? String == (row["mapLocation"] as! [String: Any])["placeID"] as? String } }, "Existing promotion merchants retain their original map associations")
    }

    static func mapMerchants() async throws {
        let frameID = "30000000-0000-4000-8000-000000000001"
        let masterID = "30000000-0000-4000-8000-000000000002"
        let placeID = "30000000-0000-4000-8000-000000000003"
        let secondID = "30000000-0000-4000-8000-000000000004"
        let document = CamapDocument(masterId: masterID, baseRevision: 2,
            frames: [.init(id: frameID, name: "校园")], features: [
                .init(id: placeID, frameId: frameID, kind: "merchant", name: "同名商户", geometry: .point(.init(0, 0))),
                .init(id: secondID, frameId: frameID, kind: "merchant", name: "同名商户", geometry: .point(.init(10, 0)))
            ])
        let snapshot = CampusMapSnapshot(schoolID: 1, document: document, etag: "\"map-hash\"")
        let location = CampusMerchantBindings.Location(masterId: masterID, mapRevision: 2, placeID: placeID,
            frameId: frameID, buildingId: nil, levelId: nil)
        let second = CampusMerchantBindings.Location(masterId: masterID, mapRevision: 2, placeID: secondID,
            frameId: frameID, buildingId: nil, levelId: nil)
        let entries = [
            CampusMerchantBindings.Entry(placeID: placeID, shopType: "main", shopID: 1, mainShopID: 1, mapLocation: location),
            CampusMerchantBindings.Entry(placeID: secondID, shopType: "sub", shopID: 1, mainShopID: 2, mapLocation: second)
        ]
        var catalog = CampusMerchantBindings(schoolID: 1, masterId: masterID, mapRevision: 2, mapHash: "map-hash", bindings: entries)
        var failed = false
        var held: CheckedContinuation<CampusMerchantBindings, Never>?
        var hold = false
        let map = CampusMapStore(client: .init(school: { 1 }, fetch: { _, _ in .document(snapshot) }, merchants: { _ in
            if failed { throw APIClientError.invalidResponse }
            if hold { return await withCheckedContinuation { held = $0 } }
            return catalog
        }))
        await map.load(userID: 1)
        check(map.merchants.count == 2, "Published shop bindings load with the map")
        map.focus(on: [placeID, "missing"])
        check(map.focusRequest?.featureIDs == [placeID] && map.selectedFrameID == frameID,
              "Explicit map focus only references existing published features")

        check(map.merchant(at: placeID)?.reference == .mainShop(1), "Map UUID resolves a main shop explicitly")
        check(map.merchant(at: secondID)?.reference == .subShop(1, mainShopID: 2), "Same numeric main/sub shop IDs stay separate")
        check(map.routeTarget(for: .subShop(1, mainShopID: 2))?.destination == secondID, "Shop route uses its own published feature")
        check(map.routeTarget(for: .mainShop(99)) == nil, "Same names never invent shop associations")
        catalog = .init(schoolID: 2, masterId: masterID, mapRevision: 2, mapHash: "map-hash", bindings: entries)
        await map.load(userID: 1, force: true)
        check(map.merchants.isEmpty && map.merchantError != nil, "Other-school associations are rejected")
        catalog = .init(schoolID: 1, masterId: masterID, mapRevision: 1, mapHash: "map-hash", bindings: entries)
        check(catalog.validatedEntries(in: snapshot).isEmpty, "Stale map revision cannot resolve business identities")
        catalog = .init(schoolID: 1, masterId: masterID, mapRevision: 2, mapHash: "old-hash", bindings: entries)
        check(!catalog.matches(snapshot), "Map hash must also match")
        let malformed = CampusMerchantBindings.Entry(placeID: secondID, shopType: "sub", shopID: 1, mainShopID: 2, mapLocation: location)
        catalog = .init(schoolID: 1, masterId: masterID, mapRevision: 2, mapHash: "map-hash", bindings: [malformed])
        check(catalog.validatedEntries(in: snapshot).isEmpty, "Inconsistent location UUID cannot link another feature")
        failed = true
        await map.load(userID: 1, force: true)
        check(map.snapshot != nil && map.merchants.isEmpty && map.merchantError != nil, "Association failure preserves map with an explicit error")
        failed = false; hold = true
        let request = Task { await map.load(userID: 1, force: true) }
        while held == nil { await Task.yield() }
        map.bind(userID: 2)
        held?.resume(returning: .init(schoolID: 1, masterId: masterID, mapRevision: 2, mapHash: "map-hash", bindings: entries))
        await request.value
        check(map.snapshot == nil && map.merchants.isEmpty && map.focusRequest == nil, "Old account's in-flight bindings and focus never enter the new account")
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
        var unavailable = true
        let retryMap = CampusMapStore(client: .init(school: { 1 }, fetch: { _, _ in
            if unavailable { throw APIClientError.invalidResponse }
            return .document(.init(schoolID: 1, document: document, etag: plan.mapHash))
        }))
        let retryPreview = RoutePreviewStore(navigation: navigation, map: retryMap)
        retryPreview.bind(userID: 1); retryPreview.open(.nextCourse)
        await retryPreview.prepare()
        check(retryPreview.preparationError != nil, "Unavailable map exposes a preparation error")
        unavailable = false
        await retryPreview.prepare()
        check(retryPreview.preparationError == nil && retryPreview.isSelectingOrigin && commands.isEmpty,
              "Retry clears the old error and reaches the manual-origin screen without planning silently")
        retryPreview.close()
        let preview = RoutePreviewStore(navigation: navigation, map: map)
        preview.bind(userID: 1); preview.open(.nextCourse)
        await preview.prepare()
        check(preview.isSelectingOrigin && commands.isEmpty, "Uncalibrated map waits for a manual origin without a request")
        check(preview.originOptions.count == 2, "Manual origins come from connected published nodes")
        await preview.selectOrigin(preview.originOptions[0])
        check(commands.last?.action == .start && commands.last?.recommendationsEnabled == nil, "Preview only starts after origin selection, using the account recommendation preference")
        check(navigation.presentationMode == .preview && !navigation.isGuiding, "A ready preview never enables navigation guidance")
        let before = commands.count
        await navigation.updateLocation(.node(id: b, frameID: frameID), at: .distantFuture)
        check(commands.count == before, "GPS updates never mutate a route preview")
        if let overlay = navigation.plan?.overlays.first {
            let previousCommands = commands.count
            preview.focusOverlay(overlay.id)
            check(preview.focusedOverlayID == overlay.id && commands.count == previousCommands,
                  "Viewing a notice location only focuses the server's existing overlay, without planning again")
            let focusEvent = preview.fitRequest
            preview.focusOverlay("not-a-published-overlay")
            check(preview.fitRequest == focusEvent, "An unknown overlay cannot fabricate a map location")
        }
        let overview = preview.mapBrowsingRequest
        let mutationsBeforeOverview = commands.count
        preview.showOverview()
        check(preview.mapBrowsingRequest != overview && preview.focusedOverlayID == nil && commands.count == mutationsBeforeOverview && navigation.presentationMode == .preview,
              "Map overview is a presentation action, not a navigation restart or model request")
        let origin = preview.origin
        map.displayMode = .original; map.displayMode = .drawing
        check(preview.origin == origin && navigation.plan != nil, "Basemap switches keep route and selected origin")
        preview.close()
        check(navigation.plan == nil && !preview.isPresented && preview.focusedOverlayID == nil, "Closing clears the route and notice focus immediately")
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
