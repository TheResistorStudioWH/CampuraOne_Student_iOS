
//
//  Announce_Banner.swift
//  CampuraOne
//
//  Created by LShayc1own on 25/05/2026.
//

import SwiftUI
import SwiftData
import MarkdownUI

#Preview("app - 已登录") {
    ContentView()
        .modelContainer(PreviewContainer.app)
}

#Preview("通知横幅 - 本地数据") {
    Announce_BannerModule(
        announces: AnnouncementItem.previewShortList
    )
}



struct Announce_BannerRemoteModule: View {
    @EnvironmentObject private var announcementStore: AnnouncementStore
    let userProfile: AppUser?
    
    var body: some View {
        Group {
            if userProfile == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 72)
            } else if userProfile?.studentID == nil {
                ContentUnavailableView(
                    "暂无通知",
                    systemImage: "megaphone",
                    description: Text("当前用户没有绑定学生信息。")
                )
            } else if announcementStore.isLoading && announcementStore.announces.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 72)
            } else if let errorMessage = announcementStore.errorMessage,
                      announcementStore.announces.isEmpty {
                ContentUnavailableView(
                    "通知加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if announcementStore.announces.isEmpty {
                ContentUnavailableView(
                    "暂无通知",
                    systemImage: "megaphone"
                )
            } else {
                Announce_BannerModule(
                    announces: announcementStore.announces
                )
            }
        }
    }
}

struct Announce_BannerModule: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.announcementGeometryNamespace) private var announcementNamespace
    @Environment(\.announcementToolbarVisible) private var isToolbarVisible
    
    var title: String
    var message: String
    var summary: String
    var dateText: String
    
    var announces: [AnnouncementItem]
    
    @State private var isExpand = false
    @State private var showMore = false
    @State private var selectedMarkdownAnnounce: AnnouncementItem?
    @State private var selectedShortAnnounce: AnnouncementItem?
    
    init(
        title: String,
        message: String,
        summary: String,
        dateText: String,
        announces: [AnnouncementItem]
    ) {
        self.title = title
        self.message = message
        self.summary = summary
        self.dateText = dateText
        self.announces = announces
    }
    
    init(announces: [AnnouncementItem]) {
        let supportedAnnounces = announces.filter {
            $0.type.isShortAnnouncement || $0.type.isMarkdown
        }
        
        let sortedShortAnnounces = supportedAnnounces
            .filter { $0.type.isShortAnnouncement }
            .sorted { lhs, rhs in
                (lhs.endTime ?? .distantFuture) < (rhs.endTime ?? .distantFuture)
            }
        
        let firstShortAnnounce = sortedShortAnnounces.first
        let emergencyCount = sortedShortAnnounces.filter {
            $0.type == .emergencyShort
        }.count
        
        self.title = firstShortAnnounce?.typeTitle ?? "校园通知"
        self.message = firstShortAnnounce?.content ?? "暂无新的短通知"
        self.summary = emergencyCount > 0
            ? "共 \(sortedShortAnnounces.count) 条短通知，其中 \(emergencyCount) 条为紧急通知"
            : "共 \(sortedShortAnnounces.count) 条短通知，暂无紧急通知"
        self.dateText = firstShortAnnounce?.displayDateText ?? ""
        self.announces = supportedAnnounces
    }
    
    var body: some View {
        HStack(alignment: .top) {
            importantReservedBar()
            normalShortBar()
        }
        .padding(.horizontal)
        .onChange(of: isExpand) {
            if !isExpand {
                showMore = false
            }
        }
        .animation(.bouncy, value: isExpand)
        .sheet(item: $selectedMarkdownAnnounce) { announce in
            MarkdownAnnouncementSheet(announce: announce)
        }
        .sheet(item: $selectedShortAnnounce) { announce in
            ShortAnnouncementsSheet(
                announces: shortAnnounces,
                initiallyExpandedAnnounceID: announce.announceID
            )
        }
    }

    private var markdownAnnounces: [AnnouncementItem] {
        announces
            .filter { $0.type == .importantMarkdown }
            .sorted { lhs, rhs in
                (lhs.createdAt ?? .distantPast) > (rhs.createdAt ?? .distantPast)
            }
    }
    
    private var shortAnnounces: [AnnouncementItem] {
        announces
            .filter { $0.type.isShortAnnouncement }
            .sorted { lhs, rhs in
                (lhs.endTime ?? .distantFuture) < (rhs.endTime ?? .distantFuture)
            }
    }
    
    @ViewBuilder func bannerBG(color: Color? = nil) -> some View {
        if let color {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(color)
                    .padding(.horizontal, 2)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Material.regular)
                    .padding(.horizontal, 2)
            }
        } else {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Material.regular)
                .padding(.horizontal, 2)
        }
    }
    
    @ViewBuilder func importantReservedBar() -> some View {
        let markdownCount = markdownAnnounces.count
        let countText = markdownCount > 0 ? String(markdownCount) : "0"
        
        HStack(spacing: 5) {
            Image(systemName: "exclamationmark.octagon.fill")
                .announcementMatchedGeometry(
                    id: "announcement.important.icon",
                    namespace: announcementNamespace,
                    isSource: !isToolbarVisible
                )
            
            Text(countText)
                .announcementMatchedGeometry(
                    id: "announcement.important.count",
                    namespace: announcementNamespace,
                    isSource: !isToolbarVisible
                )
        }
        .font(.title)
        .fontDesign(.monospaced)
        .foregroundStyle(markdownCount > 0 ? .red : .secondary)
        .padding()
        .background {
            bannerBG(color: (markdownCount > 0 ? Color.red : Color.secondary).opacity(0.6))
        }
        .beButton {
            selectedMarkdownAnnounce = markdownAnnounces.first
        }
        .disabled(markdownAnnounces.isEmpty)
    }
    
   
    
    @ViewBuilder func normalShortBar() -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top) {
                Image(systemName: "megaphone.fill")
                    .announcementMatchedGeometry(
                        id: "announcement.short.icon",
                        namespace: announcementNamespace,
                        isSource: !isToolbarVisible
                    )
                    .opacity(!isToolbarVisible ? 1 : 0)
                    .offset(y: 9)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.headline)
                            .lineLimit(1)
                            .overlay(alignment: .leading) {
                                announcesLabels(announces: shortAnnounces)
                                    .announcementMatchedGeometry(
                                        id: "announcement.short.labels",
                                        namespace: announcementNamespace,
                                        isSource: !isToolbarVisible
                                    )
                                    .opacity(!isToolbarVisible ? 1 : 0)
                                    .offset(y: -16)
                            }
                        
                        Text(dateText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack(alignment: .top) {
                        if #available(iOS 26.0, *) {
                            Image(systemName: "text.line.2.summary")
                                .font(.system(size: 14))
                        } else {
                            Image("compatible.text.line.2.summary")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                        }
                        
                        Text(message)
                            .font(.subheadline)
                            .lineLimit(isExpand ? .max : 1)
                    }
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpand ? 90 : 0), anchor: .center)
            }
            
            if isExpand {
                if showMore {
                    VStack(spacing: 8) {
                        ForEach(shortAnnounces) { announce in
                            ShortAnnounceListCard(announce: announce)
                                .contentShape(Rectangle())
                                .beButton {
                                    selectedShortAnnounce = announce
                                }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 3)
                }
                
                HStack(alignment: .top) {
                    Image(systemName: "megaphone.fill")
                        .opacity(0)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text(showMore ? "收起" : "查看完整信息")
                            .font(.subheadline)
                            .beButton {
                                withAnimation(.easeInOut) {
                                    showMore.toggle()
                                }
                            }
                        
                        Label(summary, systemImage: "sparkles")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    if showMore {
                        Text("收起全部")
                            .font(.subheadline)
                            .beButton {
                                isExpand.toggle()
                            }
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(alignment: .top) {
            bannerBG()
                .shadow(
                    color: .black.opacity(.colorScheme(light: 0.15, dark: 0.4, colorScheme)),
                    radius: 3,
                    x: -1,
                    y: 1
                )
        }
        .beButton {
            isExpand.toggle()
        }
        .buttonStyle(.plain)
    }
}

struct ShortAnnounceListCard: View {
    @Environment(\.colorScheme) private var colorScheme
    
    var announce: AnnouncementItem
    
    var body: some View {
        HStack {
            Circle()
                .frame(width: 7)
                .foregroundStyle(announce.type == .emergencyShort ? .orange : .secondary)
            
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text(announce.content)
                        .font(.footnote)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text(announce.remainingTimeText)
                        .font(.system(size: 10))
                        .bold()
                        .padding(3)
                        .background {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(announce.remainingStatusColor.opacity(0.45))
                                .shadow(
                                    color: .black.opacity(.colorScheme(light: 0.15, dark: 0.4, colorScheme)),
                                    radius: 3,
                                    x: -1,
                                    y: 1
                                )
                        }
                }
                
                Text(announce.dateRangeText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct MarkdownAnnouncementSheet: View {
    @Environment(\.dismiss) private var dismiss
    let announce: AnnouncementItem
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("重要通知", systemImage: "exclamationmark.octagon.fill")
                        .font(.title2.bold())
                        .foregroundStyle(.red)
                    
                    if !announce.dateRangeText.isEmpty {
                        Text(announce.dateRangeText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Markdown(announce.content)
                        .markdownTheme(.gitHub)
                        .tint(.accentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(announce.typeTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Text("完成")
                        .beButton {
                            dismiss()
                        }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

struct ShortAnnouncementsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let announces: [AnnouncementItem]
    let initiallyExpandedAnnounceID: Int
    
    @State private var expandedAnnounceID: Int
    
    init(
        announces: [AnnouncementItem],
        initiallyExpandedAnnounceID: Int
    ) {
        self.announces = announces
        self.initiallyExpandedAnnounceID = initiallyExpandedAnnounceID
        self._expandedAnnounceID = State(initialValue: initiallyExpandedAnnounceID)
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if announces.isEmpty {
                    ContentUnavailableView(
                        "暂无短通知",
                        systemImage: "megaphone"
                    )
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(announces) { announce in
                                    ShortAnnouncementCard(
                                        announce: announce,
                                        isExpanded: expandedAnnounceID == announce.announceID
                                    ) {
                                        withAnimation(.snappy) {
                                            expandedAnnounceID = announce.announceID
                                        }
                                    }
                                    .id(announce.announceID)
                                }
                            }
                            .padding(16)
                        }
                        .background(Color(uiColor: .systemGroupedBackground))
                        .task {
                            await Task.yield()
                            withAnimation(.snappy) {
                                proxy.scrollTo(initiallyExpandedAnnounceID, anchor: .center)
                            }
                        }
                    }
                }
            }
            .navigationTitle("短通知")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Text("完成")
                        .beButton {
                            dismiss()
                        }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

private struct ShortAnnouncementCard: View {
    let announce: AnnouncementItem
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(announce.typeTitle)
                            .font(.headline)
                        Text("·")
                        
                        typeLabel(type: announce.type)
                    }
                    
                    if isExpanded {
                        Text(announce.dateRangeText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                }
                
                Spacer()
                
                Text(announce.remainingTimeText)
                    .font(.caption2.bold())
                    .foregroundStyle(announce.remainingStatusColor)
                
                Image(systemName: "chevron.down")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            
            Group {
                if isExpanded {
                    Text(announce.content)
                        .textSelection(.enabled)
                } else {
                    Text(announce.content)
                        .lineLimit(2)
                }
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    isExpanded ? Color.accentColor.opacity(0.35) : Color.clear,
                    lineWidth: 1
                )
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .beButton {
            onTap()
        }
        .buttonStyle(.plain)
    }
    
    
    @ViewBuilder func typeLabel(type: AnnouncementType) -> some View {
        Text(type == .emergencyShort ? "紧急" : "普通")
            .font(.caption)
            .padding(3)
            .background(alignment: .center) {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .foregroundStyle(announce.type == .emergencyShort ? .orange.opacity(0.4) : .secondary)
            }
    }
}

struct announcesLabels: View {
    let announces: [AnnouncementItem]
    var body: some View {
        HStack(spacing: 4) {
            let displayAnnounces = Array(announces.prefix(4))
            
            ForEach(displayAnnounces) { item in
                Circle()
                    .frame(width: 6)
                    .foregroundStyle(item.type == .emergencyShort ? .orange : .secondary)
            }
            
            if announces.count > 4 {
                Text("+\(announces.count - 4)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .bold()
                    .padding(.leading, 1)
            }
        }
    }
}


private extension AnnouncementItem {
    var displayDateText: String {
        if let startTime {
            return startTime.announceDateText
        }
        
        if let createdAt {
            return createdAt.announceDateText
        }
        
        return ""
    }
    
    var dateRangeText: String {
        let startText = startTime?.announceFullDateText ?? "长期"
        let endText = endTime?.announceFullDateText ?? "长期有效"
        return "\(startText) - \(endText)"
    }
    
    var remainingTimeText: String {
        guard let endTime else {
            return "长期"
        }
        
        let now = Date()
        
        guard endTime > now else {
            return "已结束"
        }
        
        let remainingSeconds = endTime.timeIntervalSince(now)
        
        if remainingSeconds < 60 * 60 {
            let minutes = max(1, Int(ceil(remainingSeconds / 60)))
            return "\(minutes)min"
        }
        
        if remainingSeconds < 60 * 60 * 24 {
            let hours = Int(ceil(remainingSeconds / 3600))
            return "\(hours)h"
        }
        
        let components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: now,
            to: endTime
        )
        
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        
        var result = ""
        
        if year > 0 {
            result += "\(year)y"
        }
        
        if month > 0 {
            result += "\(month)m"
        }
        
        if day > 0 || result.isEmpty {
            result += "\(day)d"
        }
        
        return result
    }
    
    var remainingStatusColor: Color {
        guard let startTime, let endTime else {
            return .green
        }
        
        let now = Date()
        
        guard endTime > now else {
            return .red
        }
        
        let totalDuration = endTime.timeIntervalSince(startTime)
        guard totalDuration > 0 else {
            return .red
        }
        
        let remainingDuration = endTime.timeIntervalSince(now)
        let remainingRatio = remainingDuration / totalDuration
        
        if remainingRatio <= 1.0 / 3.0 {
            return .red
        } else if remainingRatio <= 0.5 {
            return .yellow
        } else {
            return .green
        }
    }
    
    static var previewShortList: [AnnouncementItem] {
        let now = Date()
        
        return [
            AnnouncementItem(
                announceID: 1,
                schoolID: 1,
                content: "今晚 22:00 至 23:00 将进行校园网络维护，期间部分服务可能短暂不可用。",
                type: .emergencyShort,
                target: nil,
                startTime: now.addingTimeInterval(-60 * 60 * 24),
                endTime: now.addingTimeInterval(60 * 60 * 24 * 2),
                createdAt: now,
                updatedAt: now
            ),
            AnnouncementItem(
                announceID: 2,
                schoolID: 1,
                content: "图书馆本周六延长开放至 22:30，请同学们合理安排自习时间。",
                type: .dailyShort,
                target: nil,
                startTime: now.addingTimeInterval(-60 * 60 * 24 * 2),
                endTime: now.addingTimeInterval(60),
                createdAt: now,
                updatedAt: now
            ),
            AnnouncementItem(
                announceID: 3,
                schoolID: 1,
                content: "食堂二楼窗口今日推出限时套餐优惠。",
                type: .dailyShort,
                target: nil,
                startTime: now.addingTimeInterval(-60 * 60 * 2),
                endTime: now.addingTimeInterval(60 * 60 * 10),
                createdAt: now,
                updatedAt: now
            )
        ]
    }
}

private extension Date {
    var announceDateText: String {
        formatted(date: .abbreviated, time: .omitted)
    }
    
    var announceFullDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return formatter.string(from: self)
    }
}

