//
//  ContentView.swift
//  CampuraOne
//
//  Created by LShayc1own on 19/05/2026.
//


import SwiftUI
import SwiftData

extension Notification.Name {
    static let scrollHomePageToTop = Notification.Name("scrollHomePageToTop")
}

#Preview("app - 已登录") {
    ContentView()
        .modelContainer(PreviewContainer.app)
}

#Preview("app - 未登录") {
    ContentView()
        .modelContainer(PreviewContainer.empty)
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
        userProfile: AppUser?
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
            MapView()
        }
    }
}

struct SelectedDashboardDetail {
    let id: String
    let title: String
    let systemImage: String
    let view: AnyView
}

struct ContentView: View {
    @Environment(\.colorScheme) var colorScheme
    
    @StateObject private var userProfileViewModel = LoadableListViewModel<AppUser>(loader: {
        [try await RemoteDataService.shared.fetchUserProfile(userID: 5)]
    })
    
    @StateObject private var announcementStore = AnnouncementStore()
    
    private var userProfile: AppUser? {
        userProfileViewModel.items.first
    }
    
    let tabBarList: [AppTab] = [
        .dashboard,
        .map
    ]
    
    @AppStorage("TabBarDisappear") var hiddenTabBar = false
    @State var currentTab: AppTab = .dashboard
    
    @State var showAvatarName = false
    @State var showTopBg = false
    @State var showTopToolbar = false
    
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
                currentTab.content(
                    namespace: bgTransitionContainer,
                    openDetail: openDetail,
                    isOpened: $isOpenedDetail,
                    scrollOffset: $scrollOffset,
                    userProfile: userProfile
                )
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            
            if selectedDetail == nil {
                
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
                .zIndex(1000)
            }
            
        }
        .environmentObject(announcementStore)
        .environment(\.announcementGeometryNamespace, bgTransitionContainer)
        .environment(\.announcementToolbarVisible, showTopToolbar)
        .ignoresSafeArea()
        .task {
            await userProfileViewModel.load()
        }
        .task(id: userProfile?.studentID) {
            await announcementStore.load(for: userProfile)
        }
        
        
        .onChange(of: currentTab) {
            print(currentTab)
            print(showAvatarName)
            switch currentTab {
                case .dashboard:
                    showAvatarName = false
                case .map:
                    showAvatarName = true
                    showTopToolbar = false
            }
            print(showAvatarName)
        }
        
        .onChange(of: scrollOffset) {
            if scrollOffset >= 0.1 {
                showTopBg = true
            } else {
                showTopBg = false
            }
            
            if scrollOffset >= screen.height/15 {
                showAvatarName = true
            } else {
                showAvatarName = false
            }
            
            if scrollOffset >= screen.height/12 {
//                withAnimation {
                    showTopToolbar = true
//                }
            } else {
//                withAnimation {
                    showTopToolbar = false
//                }
            }
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
        TapLight()
        
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
                            .allowsHitTesting(true)
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
        announcementStore.announces
            .filter { $0.type.isMarkdown }
            .sorted { lhs, rhs in
                (lhs.endTime ?? .distantFuture) < (rhs.endTime ?? .distantFuture)
            }
    }
    
    
    @State private var selectedMarkdownAnnounce: AnnouncementItem?
    
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
                selectedMarkdownAnnounce = markdownAnnounces.first
            }
            
            HStack(spacing: 10) {
                Image(systemName: "megaphone.fill")
                    .announcementMatchedGeometry(
                        id: "announcement.short.icon",
                        namespace: announcementNamespace,
                        isSource: isToolbarVisible
                    )
                
                toolbarAnnouncementLabels()
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
        
        
        .sheet(item: $selectedMarkdownAnnounce) { announce in
            MarkdownAnnouncementSheet(announce: announce)
        }
    }
    
    @ViewBuilder
    private func toolbarAnnouncementLabels() -> some View {
        if shortAnnounces.isEmpty {
            Text("0")
                .font(.caption.bold())
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
