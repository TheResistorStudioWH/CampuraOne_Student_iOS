#if DEBUG
import SwiftUI
import MapKit

/// Standalone Canvas host; all requests are intercepted by PreviewAPI.
private struct ContentPreviewCanvas: View {
    var reference: CampusContentReference?
    var target: RoutePreviewTarget?
    @ObservedObject private var browser = ContentBrowserStore.shared
    @ObservedObject private var route = RoutePreviewStore.shared
    @State private var camera: MapCameraPosition = .automatic

    var body: some View {
        CampusMapSurface(cameraPosition: $camera, location: nil, controlsTopInset: 0,
                         controlsHidden: false, navigationCameraMode: .northUp,
                         navigationCameraAvailable: false, toggleNavigationCamera: {})
            .overlay {
                ContentPreviewHost(browser: browser, route: route, openRoute: route.open, returnFromRoute: route.close)
            }
            .task {
                browser.bind(userID: 1)
                StudentNavigationStore.shared.bind(userID: 1)
                route.bind(userID: 1)
                await CampusMapStore.shared.load(userID: 1)
                if let reference { browser.open(reference) }
                if let target { route.open(target) }
            }
    }
}

#Preview("商家 · 库迪咖啡") { ContentPreviewCanvas(reference: .mainShop(6)) }
#Preview("商家 · 山麦烘焙") { ContentPreviewCanvas(reference: .mainShop(77)) }
#Preview("商品详情") { ContentPreviewCanvas(reference: .product(5)) }
#Preview("促销详情") { ContentPreviewCanvas(reference: .promotion(11)) }
#Preview("商品已移除") { ContentPreviewCanvas(reference: .product(999)) }
#Preview("大字号 · 商品") {
    ContentPreviewCanvas(reference: .product(5))
        .environment(\.dynamicTypeSize, .accessibility2)
        .preferredColorScheme(.light)
}
#Preview("地点 · 已更新") { ContentPreviewCanvas(reference: .place("removed-place")) }
#Preview("路线 · 手选起点") { ContentPreviewCanvas(target: .nextCourse) }
#Preview("路线 · 不可达") {
    ContentPreviewCanvas(target: .place(id: "10000000-0000-4000-8000-000000000020", name: "图书馆", frameID: PreviewNavigation.frameID))
}
#endif
