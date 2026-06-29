//
//  HomePageView.swift
//  CampuraOne
//
//  Created by LShayc1own on 21/05/2026.
//

import SwiftUI
import Combine
import SwiftData
import UIKit

#Preview("app - 已登录") {
    ContentView()
        .modelContainer(PreviewContainer.app)
}

#Preview("app - 未登录") {
    ContentView()
        .modelContainer(PreviewContainer.empty)
}

struct HomePageView: View {
    
    let userProfile: AppUser?
    
    @State var nowTime = ClassNowTime().timeString
    
    let bgTransitionContainer: Namespace.ID
    let openDetail: (_ detail: SelectedDashboardDetail) -> Void
    @Binding var isOpened: Bool
    
    @State var selectedDay: MiniDayType = .today
    @State private var salesTimelineMode: SalesTimelineMode = .random
    
    @State var courseTableRefreshID = UUID()
    @State var schoolCalendarRefreshID = UUID()
    
    
    @State private var salesTimelineRefreshID = 0
    @Binding var scrollOffset: CGFloat

    
    @State private var studentViewModel: LoadableListViewModel<Student>?
    
    
    enum MiniDayType: String, CaseIterable, Identifiable {
        case today
        case tomorrow
        
        var id: Self { self }
        
        var title: String {
            switch self {
            case .today:
                return "今"
            case .tomorrow:
                return "明"
            }
        }
        
        var date: Date {
            switch self {
            case .today:
                return Date()
            case .tomorrow:
                return Calendar.current.date(
                    byAdding: .day,
                    value: 1,
                    to: Date()
                ) ?? Date().addingTimeInterval(24 * 60 * 60)
            }
        }
    }

    enum DashboardTileKind {
        case courseTable
        case smallAd
        case salesTimeline
        case toolbox
        case schoolCalendar
        
        var id: String {
            switch self {
            case .courseTable:
                return "courseTable"
            case .smallAd:
                return "smallAd"
            case .salesTimeline:
                return "salesTimeline"
            case .toolbox:
                return "toolbox"
            case .schoolCalendar:
                return "schoolCalendar"
            }
        }
        
        var title: String {
            switch self {
            case .courseTable:
                return "课程表"
            case .smallAd:
                return "推荐广告"
            case .salesTimeline:
                return "最近促销"
            case .toolbox:
                return "工具箱"
            case .schoolCalendar:
                return "校历"
            }
        }
        
        var displayTitle: String {
            switch self {
            case .smallAd:
                return ""
            default:
                return title
            }
        }
        
        var systemImage: String {
            switch self {
            case .courseTable:
                return "calendar.badge.clock"
            case .smallAd:
                return "sparkles.rectangle.stack.fill"
            case .salesTimeline:
                return "tag.fill"
            case .toolbox:
                return "square.grid.2x2.fill"
            case .schoolCalendar:
                return "calendar"
            }
        }
        
        var displaySystemImage: String {
            switch self {
            case .smallAd:
                return ""
            default:
                return systemImage
            }
        }
        
        var detailView: AnyView {
            switch self {
            case .courseTable:
                return AnyView(CourseTableDetail())
            case .smallAd:
                return AnyView(AD_SmallModule())
            case .salesTimeline:
                return AnyView(SalesTimeLineDetailView())
            case .toolbox:
                return AnyView(ToolBoxModule())
            case .schoolCalendar:
                return AnyView(SchoolCalendarDetail())
            }
        }
        
        var selectedDetail: SelectedDashboardDetail {
            SelectedDashboardDetail(
                id: id,
                title: title,
                systemImage: systemImage,
                view: detailView
            )
        }
    }

    @ViewBuilder
    private func dashboardTiles(layout: DashboardLayout) -> some View {
        HStack(alignment: .top, spacing: layout.gridSpacing) {
            todayColumn(layout: layout)
            regularColumn(layout: layout)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func todayColumn(layout: DashboardLayout) -> some View {
        VStack(spacing: layout.gridSpacing) {
            HStack {
                Text("Today和精选")
                    .font(.system(size: 27))
                    .bold()
                Spacer()
            }
            
            dashboardTile(.courseTable) {
                ICSCalendar_TimeLine(minimumTimelineHeight: 0, displayDate: selectedDay.date)
                    .id(courseTableRefreshID)
            } toolBar: {
                HStack(spacing: 6) {
                    CourseDayPickerMini()
                }
            }
            .frame(height: layout.smallTileHeight)
            
            dashboardTile(.smallAd) {
                AD_SmallModule()
            } toolBar: {
                EmptyView()
            }
            .frame(height: layout.smallTileHeight)
            
            dashboardTile(.salesTimeline) {
                SalesTimeLineModule(
                    mode: $salesTimelineMode,
                    refreshID: salesTimelineRefreshID
                )
            } toolBar: {
                SalesTimelineModePickerMini()
            }
            .frame(height: layout.middleTileHeight)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func regularColumn(layout: DashboardLayout) -> some View {
        VStack(spacing: layout.gridSpacing) {
            dashboardTile(.toolbox) {
                ToolBoxModule()
            } toolBar: {
                Image(systemName: "chevron.right")
            }
            .frame(height: layout.smallTileHeight)
            
            dashboardTile(.schoolCalendar) {
                SchoolCalendarModule()
                    .id(schoolCalendarRefreshID)
            } toolBar: {
                HStack(spacing: 6) {
                    RefreshTileButton {
                        schoolCalendarRefreshID = UUID()
                    }
                    Image(systemName: "chevron.right")
                }
            }
            .frame(height: layout.largeTileHeight)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func dashboardTile<Content: View, ToolBar: View>(
        _ kind: DashboardTileKind,
        @ViewBuilder content: () -> Content,
        @ViewBuilder toolBar: () -> ToolBar
    ) -> some View {
        DashboardTile(
            title: kind.displayTitle,
            systemImage: kind.displaySystemImage,
            detailID: kind.id,
            namespace: bgTransitionContainer,
            onOpen: {
                openDetail(kind.selectedDetail)
            },
            isOpened: $isOpened,
            content: content,
            toolBar: toolBar
        )
    }
    
    var body: some View {
        GeometryReader { proxy in
            let layout = DashboardLayout(screenSize: proxy.size)
            UIKitOffsetScrollView(offset: $scrollOffset) {
                ZStack {
                    VStack(spacing: layout.outerSpacing) {
                        HStack {
                            greet()
                            Spacer()
                        }
                        .padding(.bottom, screen.height/15)
                        AD_LargeBanner(advertisements: [Advertisement(adID: 1, saleID: 1, startTime: .now, endTime: .now, type: "L", img: "http://129.211.189.35/uploads/ads/imgs/ad_L_1_20260611_013346_fa6e0218.png")])
                        dashboardTiles(layout: layout)
                    }
                    .padding(.bottom)
                    
                    VStack(spacing: layout.outerSpacing) {
                        HStack {
                            greet()
                            Spacer()
                        }
                        .opacity(0)
                        
                        Announce_BannerRemoteModule(
                            userProfile: userProfile
                        )
                        .offset(y: -screen.height/37)
                        Spacer()
                    }
                }
            }
        }
        .padding(.bottom, screen.height/20)
        .task(id: userProfile?.studentID) {
            guard let studentID = userProfile?.studentID else {
                studentViewModel = nil
                return
            }
            
            let viewModel = LoadableListViewModel<Student>(loader: {
                [
                    try await RemoteDataService.shared.fetchStudentProfile(
                        studentID: studentID
                    )
                ]
            })
            
            studentViewModel = viewModel
            await viewModel.load()
        }
    }
    
    @ViewBuilder func greet() -> some View {
        VStack(alignment: .leading, spacing: 3) {
            VStack {
                switch nowTime.prefix(2) {
                    case "23":
                        Text("深夜了，晚安")
                    case "00":
                        Text("深夜了，晚安")
                    case "01":
                        Text("深夜了，晚安")
                    case "02":
                        Text("深夜了，晚安")
                    case "03":
                        Text("深夜了，晚安")
                    case "04":
                        Text("清晨，早安")
                    case "05":
                        Text("清晨，早安")
                    case "06":
                        Text("清晨，早安")
                    case "07":
                        Text("早上好！")
                    case "08":
                        Text("早上好！")
                    case "09":
                        Text("早上好！")
                    case "10":
                        Text("上午好，")
                    case "11":
                        Text("上午好，")
                    case "12":
                        Text("中午好，")
                    case "13":
                        Text("中午好，")
                    case "14":
                        Text("中午好，")
                    case "15":
                        Text("下午好，")
                    case "16":
                        Text("下午好，")
                    case "17":
                        Text("下午好，")
                    case "18":
                        Text("下午好，")
                    case "19":
                        Text("晚上好，")
                    case "20":
                        Text("晚上好，")
                    case "21":
                        Text("晚上好，")
                    case "22":
                        Text("晚上好，")
                    default:
                        Text("你好，")
                }
            }
            .font(.system(size: 39))
            .bold()
            if let studentViewModel {
                StudentGreetingLine(
                    viewModel: studentViewModel,
                    fallbackName: userProfile?.userName ?? "同学"
                )
            } else if userProfile == nil {
                Text("正在获取用户信息…")
                    .font(.system(size: 25))
                    .foregroundStyle(.secondary)
            } else {
                Text("\(userProfile?.userName ?? "同学")同学")
                    .font(.system(size: 25))
            }
        }
        .padding()
    }

private struct StudentGreetingLine: View {
    @ObservedObject var viewModel: LoadableListViewModel<Student>
    let fallbackName: String
    
    private var student: Student? {
        viewModel.items.first
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Group {
                if viewModel.isLoading && student == nil {
                    Text("正在获取学生信息…")
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(student?.studentName ?? fallbackName)同学")
                }
            }
            .font(.system(size: 25))
            
            if let errorMessage = viewModel.errorMessage,
               student == nil {
                Text("学生信息加载失败：\(errorMessage)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

    
    
    @ViewBuilder func CourseDayPickerMini() -> some View {
        HStack(spacing: 2) {
            ForEach(MiniDayType.allCases) { day in
                Text(day.title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(selectedDay == day ? .primary : .secondary)
                    .frame(width: 22, height: 22)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedDay == day ? Material.regular : Material.ultraThin)
                    }
                    .onTapGesture {
                        selectedDay = day
                        TapSoft()
                    }
                    .animation(.smooth, value: selectedDay)
            }
        }
    }

    @ViewBuilder
    func SalesTimelineModePickerMini() -> some View {
        HStack(spacing: 2) {
            ForEach(SalesTimelineMode.allCases) { option in
                Image(systemName: option.systemImage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(
                        salesTimelineMode == option
                        ? option.primaryColor
                        : Color.secondary
                    )
                    .frame(width: 22, height: 22)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                salesTimelineMode == option
                                ? Material.regular
                                : Material.ultraThin
                            )
                    }
                    .contentShape(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .onTapGesture {
                        if salesTimelineMode == option {
                            salesTimelineRefreshID += 1
                            TapSucceed()
                        } else {
                            withAnimation(.snappy) {
                                salesTimelineMode = option
                            }
                            TapSoft()
                        }
                    }
                    .accessibilityLabel(option.title)
                    .accessibilityHint(
                        salesTimelineMode == option
                        ? "再次点击可刷新当前榜单"
                        : "切换到\(option.title)"
                    )
            }
        }
    }
}

private struct RefreshTileButton: View {
    let action: () -> Void
    
    @State var switchSymbol = false
    var body: some View {
        
            Image(systemName: switchSymbol ? "arrow.trianglehead.2.clockwise" : "arrow.trianglehead.2.counterclockwise")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)
                .contentTransition(.symbolEffect(.replace.magic(fallback: .replace.byLayer), options: .nonRepeating))
        
            .frame(width: 22, height: 22)
            .background {
                Circle()
                    .fill(Material.ultraThin)
            }
            .contentShape(Circle())
            .beButton {
                switchSymbol.toggle()
                withAnimation(.snappy) {
                    action()
                }
                TapSucceed()
            }
            .animation(.smooth, value: switchSymbol)
    }
}

private struct DashboardLayout {
    let screenSize: CGSize
    
    var screenHeight: CGFloat {
        screenSize.height
    }
    
    var outerSpacing: CGFloat {
        screenHeight * 0.018
    }
    
    var gridSpacing: CGFloat {
        screenHeight * 0.014
    }
    
    var staggerOffset: CGFloat {
        smallTileHeight * 0.28
    }
   
    
    var smallTileHeight: CGFloat {
        screenHeight * 0.22
    }
    
    var middleTileHeight: CGFloat {
        screenHeight * 0.34
    }
    
    var largeTileHeight: CGFloat {
        smallTileHeight * 2 + gridSpacing
    }
}

private struct DashboardTile<Content: View, ToolBar: View>: View {
    let title: String
    let systemImage: String
    let detailID: String
    let namespace: Namespace.ID
    let onOpen: () -> Void
    
    @Binding var isOpened: Bool
    @ViewBuilder let content: Content
    @ViewBuilder let toolBar: ToolBar
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if !systemImage.isEmpty {
                    Image(systemName: systemImage)
                        .font(.headline)
                        .matchedGeometryEffect(id: "\(detailID)-icon", in: namespace)
                }
                
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: 20))
                        .bold()
                        .matchedGeometryEffect(id: "\(detailID)-title", in: namespace, properties: .position)
                }
                
                Spacer()
                toolBar
            }
            
            
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .opacity(isOpened ? 0 : 1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Material.bar)
                .matchedGeometryEffect(id: "\(detailID)-bg", in: namespace, properties: .frame)
                .shadow(color: .black.opacity(0.2), radius: 16, x: 0, y: 10)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .beButton {
            withAnimation {
                isOpened = true
            }
            onOpen()
        }
        .buttonStyle(.plain)
    }
}

private struct UIKitOffsetScrollView<Content: View>: UIViewControllerRepresentable {
    @Binding var offset: CGFloat
    let content: Content
    
    init(
        offset: Binding<CGFloat>,
        @ViewBuilder content: () -> Content
    ) {
        self._offset = offset
        self.content = content()
    }
    
    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller(rootView: content)
        controller.onOffsetChange = { value in
            offset = max(value, 0)
        }
        return controller
    }
    
    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.update(rootView: content)
        controller.onOffsetChange = { value in
            offset = max(value, 0)
        }
    }
    
    final class Controller: UIViewController, UIScrollViewDelegate {
        
        let scrollView = UIScrollView()
        let hostingController: UIHostingController<Content>
        
        var onOffsetChange: ((CGFloat) -> Void)?
        var scrollToTopObserver: NSObjectProtocol?
        
        init(rootView: Content) {
            self.hostingController = UIHostingController(rootView: rootView)
            super.init(nibName: nil, bundle: nil)
        }
        
        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        override func viewDidLoad() {
            super.viewDidLoad()
            
            view.backgroundColor = .clear
            
            scrollView.backgroundColor = .clear
            scrollView.alwaysBounceVertical = true
            scrollView.showsVerticalScrollIndicator = false
            scrollView.delegate = self
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            
            scrollToTopObserver = NotificationCenter.default.addObserver(
                forName: .scrollHomePageToTop,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.scrollToTop(animated: true)
            }
            
            view.addSubview(scrollView)
            
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: view.topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
            addChild(hostingController)
            hostingController.view.backgroundColor = .clear
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview(hostingController.view)
            hostingController.didMove(toParent: self)
            
            NSLayoutConstraint.activate([
                hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
            ])
        }
        
        deinit {
            if let scrollToTopObserver {
                NotificationCenter.default.removeObserver(scrollToTopObserver)
            }
        }
        
        private func scrollToTop(animated: Bool) {
            let topOffset = CGPoint(
                x: 0,
                y: -scrollView.adjustedContentInset.top
            )
            
            scrollView.setContentOffset(
                topOffset,
                animated: animated
            )
        }
        
        func update(rootView: Content) {
            hostingController.rootView = rootView
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            onOffsetChange?(scrollView.contentOffset.y)
        }
    }
}


