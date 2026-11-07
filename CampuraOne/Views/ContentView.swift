//
//  ContentView.swift
//  CampuraOne
//
//  Created by LShayc1own on 19/05/2026.
//


import SwiftUI
import PetaToolKit
import PetaKitUIX
import SwiftData

extension Notification.Name {
    static let scrollHomePageToTop = Notification.Name("scrollHomePageToTop")
}

#Preview("app - 已登录") {
    PreviewAppView()
}

#Preview("app - 未登录") {
    PreviewAppView(signedIn: false)
}

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case map
    
    var id: Self { self }
    
    var title: String {
        switch self {
            case .dashboard:
                return "仪表盘"
            case .map:
                return "地图"
        }
    }
    
    var icon: String {
        switch self {
            case .dashboard:
                return "app.dashed"
            case .map:
                return "map.fill"
        }
    }
    
    @ViewBuilder
    func content(
        namespace: Namespace.ID,
        openDetail: @escaping (_ detail: SelectedDashboardDetail) -> Void,
        isOpened: Binding<Bool>,
        scrollOffset: Binding<CGFloat>,
        userProfile: AppUser?,
        isActive: Bool = true
    ) -> some View {
        switch self {
        case .dashboard:
            HomePageView(
                userProfile: userProfile,
                bgTransitionContainer: namespace,
                openDetail: openDetail,
                isOpened: isOpened,
                scrollOffset: scrollOffset
            )
        case .map:
            MapView(isActive: isActive)
        }
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    let userProfile: AppUser?

    @StateObject private var announcementStore = AnnouncementStore()
    @ObservedObject private var contentBrowser = ContentBrowserStore.shared
    @ObservedObject private var routePreview = RoutePreviewStore.shared
    @State private var routeReturnTab: AppTab?
    @State private var contentReturnTab: AppTab?
    @ObservedObject private var campusMap = CampusMapStore.shared

    private var announcementLifecycle: String {
        "\(userProfile?.studentID ?? -1)-\(scenePhase == .active)"
    }

    init(userProfile: AppUser? = nil) {
        self.userProfile = userProfile
    }
    
    let tabBarList: [AppTab] = [
        .dashboard,
        .map
    ]
    
    @AppStorage("TabBarDisappear") var hiddenTabBar = false
    @State var currentTab: AppTab = .dashboard
    
    @State var showAvatarName = false
    private var showTopBg: Bool {
        currentTab == .dashboard && scrollOffset >= 0.1
    }
    private var showTopToolbar: Bool {
        currentTab == .dashboard && scrollOffset >= screen.height / 12
    }
    
    @State var scaleValue = 1.0
    @State var rotationDegrees = 0.0
    
    @State var showSheet = false
    
    @State var isOpenedDetail = false
    @State private var selectedDetail: SelectedDashboardDetail?
    
    @State var scrollOffset: CGFloat = 0
    
    @Namespace var bgTransitionContainer
    
    private func openDetail(_ detail: SelectedDashboardDetail) {
        withAnimation(.spring(duration: 0.54, bounce: 0.23, blendDuration: 0.3)) {
            selectedDetail = detail
            isOpenedDetail = true
        }
    }
    
    private func closeDetail() {
        withAnimation(.spring(duration: 0.43, bounce: 0.2, blendDuration: 0.2)) {
            selectedDetail = nil
            isOpenedDetail = false
        }
    }
    
    var body: some View {
        ZStack {
            
            NavigationStack {
                ZStack {
                    ForEach(tabBarList) { tab in
                        tab.content(
                            namespace: bgTransitionContainer,
                            openDetail: openDetail,
                            isOpened: $isOpenedDetail,
                            scrollOffset: $scrollOffset,
                            userProfile: userProfile,
                            isActive: currentTab == tab
                        )
                        .opacity(currentTab == tab ? 1 : 0)
                        .allowsHitTesting(currentTab == tab)
                        .accessibilityHidden(currentTab != tab)
                    }
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            
            if selectedDetail == nil, !contentBrowser.isPresented, !routePreview.isPresented {
                
                VStack {
                    Spacer()
                    
                    ZStack {
                        
                        barBackground()
                        
                        navigationBar()
                        
                    }
                   
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(10)
                
                topBackground()
                
                
                
                VStack {
                    HStack {
                        Spacer()
                        AccountMiniCard(
                            userProfile: userProfile,
                            showSheet: $showSheet,
                            showName: $showAvatarName
                        )
                            .padding()
                            .padding(.top, screen.height/23)
                    }
                    Spacer()
                }
                .zIndex(11)
            }
            
            if let selectedDetail {
                DetailContainer(
                    selectedDetail: selectedDetail,
                    namespace: bgTransitionContainer,
                    isOpened: $isOpenedDetail,
                    onClose: closeDetail
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(routePreview.isPresented ? 0 : 1)
                .allowsHitTesting(!routePreview.isPresented && !contentBrowser.isPresented)
                .accessibilityHidden(routePreview.isPresented || contentBrowser.isPresented)
                .zIndex(1000)
            }
            
        }
        .overlay {
            ContentPreviewHost(browser: contentBrowser, route: routePreview,
                               openRoute: { routePreview.open($0) },
                               returnFromRoute: { routePreview.close() })
        }
        .environmentObject(announcementStore)
        .environment(\.announcementGeometryNamespace, bgTransitionContainer)
        .environment(\.announcementToolbarVisible, showTopToolbar)
        .ignoresSafeArea()
        .onChange(of: userProfile?.userID, initial: true) { _, userID in
            contentBrowser.bind(userID: userID)
            routePreview.bind(userID: userID)
            #if DEBUG
            if userID != nil, PreviewAPI.isEnabled,
               let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--campura-preview-content"),
               ProcessInfo.processInfo.arguments.indices.contains(index + 1) {
                switch ProcessInfo.processInfo.arguments[index + 1] {
                case "shop": contentBrowser.open(.mainShop(77))
                case "subshop": contentBrowser.open(.subShop(1, mainShopID: 1))
                case "product": contentBrowser.open(.product(5))
                case "promotion": contentBrowser.open(.promotion(11))
                case "place":
                    currentTab = .map
                    contentBrowser.open(.place(PreviewNavigation.placePreviewID))
                case "route": routePreview.open(.nextCourse)
                default: break
                }
            }
            #endif
        }
        .task(id: contentBrowser.current?.id) {
            #if DEBUG
            await PreviewAPI.configureContentScreenshot(contentBrowser)
            #endif
        }
        .task(id: routePreview.requestID) {
            #if DEBUG
            await PreviewAPI.configureRouteScreenshot(routePreview)
            #endif
        }
        .onChange(of: campusMap.focusRequest?.id) { _, _ in
            if campusMap.focusRequest != nil, contentBrowser.isPresented, !routePreview.isPresented, currentTab != .map {
                contentReturnTab = currentTab
                currentTab = .map
            }
        }
        .onChange(of: contentBrowser.isPresented) { _, shown in
            if !shown, !routePreview.isPresented, let previous = contentReturnTab {
                currentTab = previous
                contentReturnTab = nil
                routeReturnTab = nil
            }
            if shown { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
        }
        .onChange(of: routePreview.isPresented) { _, shown in
            if shown {
                routeReturnTab = currentTab
                currentTab = .map
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            } else if let previous = routeReturnTab {
                currentTab = contentBrowser.isPresented ? previous : contentReturnTab ?? previous
                routeReturnTab = nil
                if !contentBrowser.isPresented { contentReturnTab = nil }
            }
        }
        .task(id: announcementLifecycle) {
            guard scenePhase == .active else {
                announcementStore.pause()
                return
            }
            await announcementStore.run(for: userProfile?.studentID)
        }
        
        
        .onChange(of: currentTab) {
            switch currentTab {
                case .dashboard:
                    showAvatarName = scrollOffset >= screen.height / 15
                case .map:
                    showAvatarName = true
            }
        }
        
        .onChange(of: scrollOffset) {
            guard currentTab == .dashboard else { return }
            showAvatarName = scrollOffset >= screen.height / 15
        }
        
        .animation(.spring(response: 0.6, dampingFraction: 0.76, blendDuration: 1), value: hiddenTabBar)
        .animation(.smooth, value: currentTab)
        .animation(.smooth, value: showAvatarName)
        .animation(.linear(duration: 0.2), value: showTopBg)
        .animation(.smooth, value: showTopToolbar)
        
        .sheet(isPresented: $showSheet) {
            AccountSheet()
        }
        
        
    }
    
    private func tapBarAction(item: AppTab) {
        Haptics.play(.light)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentTab = item
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.2)) {
                scaleValue = 0.75
            }
            
            withAnimation(.linear(duration: 0.2)) {
                rotationDegrees += 10
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.smooth(duration: 0.2)) {
                scaleValue = 1.11
            }
            
            withAnimation(.linear(duration: 0.2)) {
                rotationDegrees -= 10
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeInOut(duration: 0.3)) {
                scaleValue = 1.0
            }
        }
    }
    
    @ViewBuilder func navigationBar() -> some View {
        VStack {
            if hiddenTabBar == false {
                VStack {
                    Spacer()
                    
                    VStack {
                        HStack {
                            ForEach(tabBarList) { item in
                                VStack(spacing: 4) {
                                    
                                    if #available(iOS 26.0, *), item.title == "地图" {
                                        Image(systemName: item == currentTab ? "map.circle" : item.icon)
                                        
                                            .font(.system(size: 22))
                                            .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer)))
                                        
                                    } else {
                                        
                                        Image(systemName: item.icon)
                                            .font(.system(size: 22))
                                            .scaleEffect(item == currentTab ? scaleValue : 1)
                                            .rotationEffect(
                                                Angle(degrees: item == currentTab ? rotationDegrees : 0)
                                            )
                                        
                                       
                                    }
                                    
                                    Text(item.title)
                                        .font(.caption)
                                        .bold()
                                }
                                
                                .foregroundColor(item == currentTab ? .accentColor : .gray)
                                .shadow(color: .black.opacity(.colorScheme(light: 0.1, dark: 0.56, colorScheme)), radius: 10, x: 1, y: 1)
                                .frame(maxWidth: .infinity)
                                .beButton {
                                    tapBarAction(item: item)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(screen.height/96)
                    .background(alignment: .center) {
                        RoundedRectangle(cornerRadius: .infinity, style: .continuous)
                            .fill(Material.thin)
                            .opacity(0.899)
                            
                    }
                    .cornerRadius(50)
                    .padding()
                    .shadow(color: .black.opacity(0.22), radius: 10, x: 0.0, y: 0.0)
                }
                .transition(.offset(x: 0, y: 100))
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
       
    }
    
    @ViewBuilder func barBackground() -> some View {
        VStack {
            Spacer()
            
            Rectangle()
                .fill(Material.ultraThick)
                .mask(
                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(0.5),
                            .black,
                            .black
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .opacity(0.6)
                )
                .frame(height: 120)
                .allowsHitTesting(false)
                .opacity(hiddenTabBar ? 0 : 1)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    @ViewBuilder func topBackground() -> some View {
        VStack {
            Rectangle()
                .foregroundColorScheme(light: .white, dark: .black)
                .mask(
                    LinearGradient(
                        colors: [
                            .clear,
                            .black.opacity(0.4),
                            .black,
                            .black
                        ],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(height: screen.height/5)
                .allowsHitTesting(false)
                .opacity(showTopBg ? 1 : 0)
                .overlay(alignment: .leading) {
                        topToolbar()
                            .allowsHitTesting(showTopToolbar)
                            .transition(.identity)
                            .zIndex(1)
                            .opacity(showTopToolbar ? 1 : 0)
                }
            Spacer()
        }
        
        .ignoresSafeArea()
    }
    
}

struct topToolbar: View {
    @EnvironmentObject private var announcementStore: AnnouncementStore
    @Environment(\.announcementGeometryNamespace) private var announcementNamespace
    @Environment(\.announcementToolbarVisible) private var isToolbarVisible
    
    private var shortAnnounces: [AnnouncementItem] {
        announcementStore.announces
            .filter { $0.type.isShortAnnouncement }
            .sorted { lhs, rhs in
                (lhs.endTime ?? .distantFuture) < (rhs.endTime ?? .distantFuture)
            }
    }
    
    private var markdownAnnounces: [AnnouncementItem] {
        announcementStore.announces.activeMarkdown(at: Date())
    }
    
    
    @State private var showMarkdownAnnouncements = false
    
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .announcementMatchedGeometry(
                        id: "announcement.important.icon",
                        namespace: announcementNamespace,
                        isSource: isToolbarVisible
                    )
                
                Text("\(markdownAnnounces.count)")
                    .announcementMatchedGeometry(
                        id: "announcement.important.count",
                        namespace: announcementNamespace,
                        isSource: isToolbarVisible
                    )
            }
            .foregroundStyle(markdownAnnounces.count > 0 ? .red : .secondary)
            .beButton {
                showMarkdownAnnouncements = true
            }
            .disabled(markdownAnnounces.isEmpty)
            
            HStack(spacing: 10) {
                Image(systemName: "megaphone.fill")
                    .announcementMatchedGeometry(
                        id: "announcement.short.icon",
                        namespace: announcementNamespace,
                        isSource: isToolbarVisible
                    )
                
                toolbar_AnnouncementLabels()
                    .announcementMatchedGeometry(
                        id: "announcement.short.labels",
                        namespace: announcementNamespace,
                        isSource: isToolbarVisible
                    )
            }
            .beButton {
                NotificationCenter.default.post(
                    name: .scrollHomePageToTop,
                    object: nil
                )
            }
            .buttonStyle(.plain)
        }
        .font(.title)
        .fontDesign(.monospaced)
        .padding(.leading)
        
        
        .sheet(isPresented: $showMarkdownAnnouncements) {
            MarkdownAnnouncementsSheet(announces: markdownAnnounces)
        }
    }
    
    @ViewBuilder
    private func toolbar_AnnouncementLabels() -> some View {
        if shortAnnounces.isEmpty {
            Text("0")
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 5) {
                ForEach(Array(shortAnnounces.prefix(5))) { announce in
                    Circle()
                        .fill(
                            announce.type == .emergencyShort
                            ? Color.orange
                            : Color.gray
                        )
                        .frame(width: 9, height: 9)
                }
                
                if shortAnnounces.count > 5 {
                    Text("+\(shortAnnounces.count - 5)")
                        .font(.caption2.bold())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(minWidth: 9, minHeight: 9, alignment: .leading)
        }
    }
}
