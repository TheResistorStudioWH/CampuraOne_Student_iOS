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
    @State private var announcementBannerHeight: CGFloat = 0
    @State private var advertisementBannerHeight: CGFloat = 0

    private enum ScrollAnchor: Hashable {
        case top
    }

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
        .frame(minWidth: 0, maxWidth: .infinity)
    }

    @ViewBuilder private func regularColumn(layout: DashboardLayout) -> some View {
        VStack(spacing: layout.gridSpacing) {
            ToolBoxTile(context: tileContext)
                .frame(height: layout.smallTileHeight)

            SchoolCalendarTile(context: tileContext)
                .frame(height: layout.largeTileHeight)
        }
        .frame(minWidth: 0, maxWidth: .infinity)
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = DashboardLayout(screenSize: proxy.size)
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical) {
                    ZStack(alignment: .top) {
                        VStack(spacing: 0) {
                            Color.clear
                                .frame(height: announcementBannerHeight
                                       + advertisementBannerHeight
                                       + layout.bannerSpacing
                                )
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)

                            dashboardTiles(layout: layout)
                        }

                        VStack(spacing: 0) {
                            Color.clear
                                .frame(
                                    height: announcementBannerHeight + layout.bannerSpacing
                                )
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)

                            AD_LargeBannerRemoteModule()
                                .readSize { size in
                                    if abs(advertisementBannerHeight - size.height) > 0.5 {
                                        advertisementBannerHeight = size.height
                                    }
                                }
                        }

                        VStack(spacing: 0) {
                            HStack {
                                greet()
                                Spacer()
                            }

                            Announce_BannerRemoteModule(userProfile: userProfile)
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .readSize { size in
                            if abs(announcementBannerHeight - size.height) > 0.5 {
                                announcementBannerHeight = size.height
                            }
                        }
                        .zIndex(2)
                    }
                    // Width comes from the viewport, never a tile's changing ideal size.
                    .frame(width: proxy.size.width)
                    .id(ScrollAnchor.top)
                    .padding(.bottom)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.always, axes: .vertical)
                .onScrollGeometryChange(for: CGFloat.self) { geometry in
                    max(0, geometry.contentOffset.y + geometry.contentInsets.top)
                } action: { _, newOffset in
                    scrollOffset = newOffset
                }
                .onReceive(NotificationCenter.default.publisher(for: .scrollHomePageToTop)) { _ in
                    withAnimation(.smooth) {
                        scrollProxy.scrollTo(ScrollAnchor.top, anchor: .top)
                    }
                }
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
    
    var bannerSpacing: CGFloat {
        screenHeight / 30
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
