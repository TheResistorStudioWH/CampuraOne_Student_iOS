//
//  HomePageView.swift
//  CampuraOne
//
//  Created by LShayc1own on 21/05/2026.
//

import SwiftUI
import PetaToolKit
import Combine
import SwiftData
import UIKit

#Preview("app - 已登录") {
    PreviewAppView()
}

#Preview("app - 未登录") {
    PreviewAppView(signedIn: false)
}

struct HomePageView: View {
    
    let userProfile: AppUser?
    var weatherSnapshot: HomeWeatherSnapshot = .demo
    
    @State var nowTime = ClassNowTime().timeString
    
    let bgTransitionContainer: Namespace.ID
    let openDetail: (_ detail: SelectedDashboardDetail) -> Void
    @Binding var isOpened: Bool
    
    @Binding var scrollOffset: CGFloat
    @State private var studentViewModel: LoadableListViewModel<Student>?

    private var tileContext: DashboardTileContext {
        DashboardTileContext(
            namespace: bgTransitionContainer,
            isOpened: $isOpened,
            openDetail: openDetail
        )
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

            CourseTableTile(context: tileContext)
                .frame(height: layout.smallTileHeight)

            SmallAdvertisementTile(context: tileContext)
                .frame(height: layout.smallTileHeight)

            SalesTimelineTile(context: tileContext)
                .frame(height: layout.middleTileHeight)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private func regularColumn(layout: DashboardLayout) -> some View {
        VStack(spacing: layout.gridSpacing) {
            ToolBoxTile(context: tileContext)
                .frame(height: layout.smallTileHeight)

            SchoolCalendarTile(context: tileContext)
                .frame(height: layout.largeTileHeight)
        }
        .frame(maxWidth: .infinity)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = DashboardLayout(screenSize: proxy.size)
            UIKitOffsetScrollView(offset: $scrollOffset) {
                
                VStack(spacing: layout.outerSpacing) {
                    
                    HStack {
                        greet()
                        Spacer()
                    }

                    

                    // Reserve the same 3:1 slot in loading, empty and loaded states.
                    ZStack {
                        VStack {
                            Spacer()
                            dashboardTiles(layout: layout)
                        }
                        
                        
                        VStack {
                            Color.clear
                                .aspectRatio(3, contentMode: .fit)
                                .padding(.horizontal)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                            AD_LargeBannerRemoteModule()
                            
                                .zIndex(3)
                            Spacer()
                        }
                        VStack {
                            Announce_BannerRemoteModule(userProfile: userProfile)
                                
                            Spacer()
                        }
                        .zIndex(2)
                        
                    }
                    

                    
                }
                .padding(.bottom)
            }
        }
        .padding(.bottom, screen.height/20)
        .task(id: userProfile?.studentID) {
            guard userProfile?.studentID != nil else {
                studentViewModel = nil
                return
            }
            
            let viewModel = LoadableListViewModel<Student>(loader: {
                [
                    try await RemoteDataService.shared.fetchMyStudentProfile()
                ]
            })
            
            studentViewModel = viewModel
            await viewModel.load()
        }
    }
    
    @ViewBuilder func greet(isPlaceholder: Bool = false) -> some View {
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
            HStack(alignment: .center, spacing: 8) {
                Group {
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
                .lineLimit(1)
                Spacer(minLength: 0)
                HomeWeatherBadge(snapshot: weatherSnapshot, isPresentationActive: !isPlaceholder)
                    .fixedSize()
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
