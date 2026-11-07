import SwiftUI
import PetaKitUIX
import MarkdownUI
import CamapKit

struct RoutePreviewHeader: View {
    @ObservedObject var route: RoutePreviewStore
    @ObservedObject private var navigation = StudentNavigationStore.shared
    let onBack: () -> Void
    let onClose: () -> Void
    @Environment(\.dynamicTypeSize) private var typeSize

    private var title: String {
        if route.selectedSource != nil { return "通知原文" }
        if route.isSelectingOrigin { return "从哪里出发" }
        if navigation.isGuiding { return "步行导航" }
        return navigation.plan != nil && !navigation.isCurrent ? "路线待更新" : "路线预览"
    }

    var body: some View {
        PreviewPanelHeader(
            title: title,
            subtitle: route.selectedSource == nil ? navigation.plan?.destination?.name ?? route.target?.title : nil,
            showBack: true, onBack: onBack, onClose: onClose
        ) {
            if route.isSelectingOrigin, !route.originOptions.isEmpty {
                MapPanelAction(title: "在地图上选起点", symbol: "hand.tap", action: route.showOverview)
                    .accessibilityIdentifier("route.origin.onMap")
            } else if route.selectedSource == nil, !route.isSelectingOrigin {
                if let plan = navigation.plan, plan.hasRoute, !navigation.isGuiding, !typeSize.isAccessibilitySize {
                    RouteTravelSummary(plan: plan).opacity(navigation.isCurrent ? 1 : 0.5)
                }
                HStack(spacing: 10) {
                    if navigation.isGuiding {
                        MapPanelAction(title: route.waitingAtStop ? "继续出发" : route.hasArrived ? "完成" : "结束导航",
                                       symbol: route.waitingAtStop ? "arrow.right" : "stop.circle",
                                       prominent: route.waitingAtStop,
                                       tint: route.waitingAtStop ? .accentColor : .red) {
                            if route.waitingAtStop { route.continueFromStop() }
                            else { route.stopGuidance() }
                        }
                        .accessibilityIdentifier("route.guidance.action")
                        #if DEMO
                        if !route.waitingAtStop && !route.hasArrived {
                            MapPanelIconButton(title: route.isPlaying ? "暂停行走" : "继续行走",
                                               symbol: route.isPlaying ? "pause.fill" : "play.fill", tint: .accentColor) {
                                if route.isPlaying { route.pausePlayback() } else { route.play() }
                            }
                        }
                        #endif
                    } else {
                        MapPanelAction(title: route.origin == nil ? "选择起点" : "修改起点", symbol: "location.circle") {
                            route.isSelectingOrigin = true
                        }
                        .disabled(navigation.isWorking || route.isCalculating)
                        .accessibilityIdentifier("route.changeOrigin")
                    }
                    MapPanelIconButton(title: "查看全程", symbol: "arrow.up.left.and.arrow.down.right", tint: .accentColor, action: route.showOverview)
                        .disabled(navigation.plan?.hasRoute != true || !navigation.isCurrent)
                        .accessibilityIdentifier("route.overview")
                    if !navigation.isGuiding {
                        MapPanelIconButton(title: "重新规划路线", symbol: "arrow.clockwise", tint: .accentColor) {
                            Task { await route.calculate() }
                        }
                        .disabled(navigation.isWorking || route.isCalculating || route.origin == nil)
                        .accessibilityIdentifier("route.recalculate")
                    }
                }
            }
        }
    }
}

struct RoutePreviewPanel: View {
    @ObservedObject var route: RoutePreviewStore
    @ObservedObject private var navigation = StudentNavigationStore.shared
    @ObservedObject private var map = CampusMapStore.shared
    @State private var stopRequest = ""
    @State private var originQuery = ""
    @State private var destinationQuery = ""
    @State private var routeScrollID: String?
    @State private var sourceScrollID: String?
    @State private var originScrollID: String?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let source = route.selectedSource { sourceContent(source).id("source.top") }
                else if let error = route.preparationError {
                    message("校园路线暂不可用", error, symbol: "map")
                    MapPanelAction(title: "重新读取地图", symbol: "arrow.clockwise") { Task { await route.prepare() } }
                } else if route.isSelectingOrigin { originPicker.id("origins.top") }
                else if navigation.isWorking || route.isCalculating {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("正在规划校园路线").font(.headline)
                        Text("正在确认通行道路和沿途通知…").font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 28)
                    .accessibilityElement(children: .combine)
                } else {
                    if let error = navigation.errorMessage {
                        MapPanelMessage(title: "路线尚未更新", message: error, symbol: "exclamationmark.triangle", tint: .orange)
                        MapPanelAction(title: navigation.requiresRestart ? "重新规划" : "重试", symbol: "arrow.clockwise") { Task { await route.calculate() } }
                            .disabled(route.origin == nil)
                    }
                    if navigation.requiresReplan || navigation.requiresRestart {
                        Text("路线信息已变化，请重新规划后查看。").foregroundStyle(.orange)
                    }
                    if let plan = navigation.plan { planContent(plan) }
                    else if navigation.errorMessage == nil { ProgressView("正在准备路线…") }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 32)
            .scrollTargetLayout()
        }
        .scrollPosition(id: contentScrollPosition, anchor: .top)
        .id(route.selectedSource.map { "source-\($0.id)" } ?? (route.isSelectingOrigin ? "origins" : "route"))
        .scrollIndicators(.automatic)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: scenePhase) { _, phase in if phase != .active { route.pausePlayback() } }
        .onChange(of: navigation.plan?.planID) { _, _ in route.refreshRouteFit() }
        .onChange(of: navigation.previewSuggestionID) { _, _ in route.refreshRouteFit() }
        .onChange(of: navigation.requiresReplan) { _, invalid in if invalid { route.stopGuidance() } }
        .task(id: route.requestID) { if route.origin == nil { await route.prepare() } }
    }

    private var contentScrollPosition: SwiftUI.Binding<String?> {
        let source = route.selectedSource != nil
        let origin = route.isSelectingOrigin
        return SwiftUI.Binding(
            get: { source ? sourceScrollID : origin ? originScrollID : routeScrollID },
            set: { value in
                if source { sourceScrollID = value }
                else if origin { originScrollID = value }
                else { routeScrollID = value }
            }
        )
    }

    private var originPicker: some View {
        let options = route.originOptions.filter {
            originQuery.isEmpty || $0.name.localizedStandardContains(originQuery.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return VStack(alignment: .leading, spacing: 16) {
            if route.canUseCurrentLocation {
                MapPanelAction(title: "使用当前位置", symbol: "location.fill", prominent: true) {
                    dismissKeyboard()
                    Task { await route.useCurrentLocation() }
                }
                .accessibilityIdentifier("route.origin.current")
            } else {
                Label("可从校园地点中选一个起点，也可以在地图上点选。", systemImage: "location.slash")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if route.originOptions.count > 6 {
                MapPanelSearchField(prompt: "查找起点", text: $originQuery)
            }
            if route.originOptions.isEmpty {
                message("暂无可用起点", "学校还没有发布可通行的路网，可以稍后刷新地图再试。", symbol: "point.topleft.down.curvedto.point.bottomright.up")
            } else if options.isEmpty {
                message("没有找到匹配起点", "试试其他地点名称。", symbol: "magnifyingglass")
            } else {
                Text("校园起点").font(.headline).accessibilityAddTraits(.isHeader)
                ForEach(options) { option in
                    choiceRow(option.name, symbol: "mappin.circle", selected: route.origin == option.origin) {
                        dismissKeyboard()
                        Task { await route.selectOrigin(option) }
                    }
                    .accessibilityIdentifier("route.origin.\(option.id)")
                }
            }
        }
        .disabled(navigation.isWorking || route.isCalculating)
    }

    @ViewBuilder private func planContent(_ plan: NavigationPlan) -> some View {
        if plan.hasRoute, let timing = plan.timing {
            if typeSize.isAccessibilitySize { RouteTravelSummary(plan: plan) }
            if !navigation.isGuiding {
                MapPanelAction(title: "开始导航", symbol: "location.north.fill", prominent: true) { route.startGuidance() }
                    .disabled(!navigation.isCurrent || navigation.isWorking)
                    .accessibilityIdentifier("route.startGuidance")
            }
            RouteJourneyCard(plan: plan, originName: route.originName) {
                route.stopGuidance()
                route.isSelectingOrigin = true
            }
            .disabled(navigation.isWorking || route.isCalculating)
            .id("route.itinerary")
            RouteScheduleAllowance(plan: plan).id("route.allowance")
            if timing.dwellSeconds > 0 {
                Label("途中停留约 \(minutes(timing.dwellSeconds)) 分钟，已计入总用时", systemImage: "pause.circle")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if navigation.isGuiding { guidanceControls }
            else {
                waypointContent(plan)
                recommendationContent(plan).id("route.recommendations")
            }
            Text("步行时间为估计值；路线按本次起点计算。")
                .font(.caption).foregroundStyle(.secondary)
        } else if plan.status == "unreachable" {
            message("暂时没有可通行路线", "已发布路网中无法连通所选起终点，请尝试其他起点或等待学校更新。", symbol: "figure.walk.diamond")
        } else if plan.status == "needs_destination" || plan.status == "needs_place_resolution" {
            message("请选择地点", plan.status == "needs_destination" ? "暂时没有可匹配的下一节课，请选择校园目的地。" : "请确认这次要前往的具体地点。", symbol: "mappin.and.ellipse")
            destinationChoices(plan)
        } else {
            message("暂时无法展示路线", "请重新规划，或选择其他起点和目的地。", symbol: "map")
        }
        if let frame = map.snapshot?.document.frames.first(where: { $0.id == plan.route?.frameId }), frame.bindings["mapkit"] == nil {
            Label(map.displayMode == .original ? "地图未校准，请切换到绘制图查看路线" : "未校准：路线仅表示校园内部关系", systemImage: "exclamationmark.triangle")
                .font(.subheadline).foregroundStyle(.orange)
                .beButton { if map.displayMode == .original { map.displayMode = .drawing } }
        }
        if !plan.overlays.isEmpty {
            Text("沿途提醒").font(.headline).id("route.notices").accessibilityAddTraits(.isHeader)
            ForEach(plan.overlays) { overlay in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .center, spacing: 8) {
                        Label(overlay.name, systemImage: overlay.kind == "closure" ? "hand.raised" : "exclamationmark.triangle")
                            .font(.subheadline.bold()).foregroundStyle(.orange)
                        Spacer(minLength: 0)
                        MapPanelIconButton(title: "在地图上查看：\(overlay.name)", symbol: "scope", tint: .orange) {
                            route.focusOverlay(overlay.id)
                        }
                        .disabled(!navigation.isCurrent)
                        .accessibilityIdentifier("route.notice.map.\(overlay.id)")
                    }
                    Text(avoidanceText(overlay)).font(.subheadline)
                    if let source = plan.sources.first(where: { $0.announceID == overlay.sourceID && $0.version == overlay.sourceVersion }) {
                        Label(source.title ?? "查看来源通知", systemImage: "doc.text")
                            .font(.subheadline.weight(.medium)).foregroundStyle(Color.accentColor)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                            .beButton { openSource(source) }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("route.source.\(source.announceID)")
                    }
                }
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        if !plan.warnings.isEmpty {
            Text("路线提示").font(.headline)
            ForEach(Array(plan.warnings.enumerated()), id: \.offset) { _, warning in
                Label(warningText(warning.code), systemImage: "info.circle").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func margin(_ seconds: Int) -> String { seconds < 60 ? "\(seconds) 秒" : "\(seconds / 60) 分钟" }
    private func minutes(_ seconds: Int) -> Int { max(1, Int(ceil(Double(seconds) / 60))) }

    private var guidanceControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            if route.hasArrived {
                Label("已到达目的地附近", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                Text("请沿实际建筑入口前往目的地。").font(.caption).foregroundStyle(.secondary)
            } else if route.waitingAtStop {
                Label("已到达\(route.nextStop?.name ?? "途经点")附近", systemImage: "cup.and.saucer.fill")
                MapPanelAction(title: "取餐完成，继续出发", symbol: "arrow.right", prominent: true) { route.continueFromStop() }
            } else {
                Label("剩余约 \(Int(ceil(max(0, route.guidanceGeometry.total - route.guidanceDistance)))) 米", systemImage: "figure.walk")
            }
            HStack(spacing: 20) {
                #if DEMO
                if !route.hasArrived && !route.waitingAtStop {
                    MapPanelIconButton(title: route.isPlaying ? "暂停" : "播放", symbol: route.isPlaying ? "pause.fill" : "play.fill", tint: .accentColor) {
                        if route.isPlaying { route.pausePlayback() } else { route.play() }
                    }
                    MapPanelIconButton(title: "下一步", symbol: "forward.end", tint: .accentColor, action: route.nextGuidanceStep)
                }
                MapPanelIconButton(title: "重播", symbol: "arrow.counterclockwise", tint: .accentColor, action: route.startGuidance)
                #endif
                MapPanelAction(title: "结束导航", symbol: "stop.circle", tint: .red, action: route.stopGuidance)
            }
            .font(.subheadline.weight(.semibold)).foregroundStyle(Color.accentColor)
        }
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder private func waypointContent(_ plan: NavigationPlan) -> some View {
        if !plan.waypoints.isEmpty {
            Text("途经安排").font(.headline)
            ForEach(plan.waypoints) { stop in
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Label(stop.name, systemImage: "mappin.circle.fill").font(.subheadline.bold())
                        Text("预计停留 \(minutes(stop.dwellSeconds)) 分钟").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    MapPanelIconButton(title: "移除途经点：\(stop.name)", symbol: "minus.circle", tint: .accentColor) {
                        Task { await navigation.removeStop(stop.id) }
                    }
                        .disabled(navigation.isWorking || !navigation.isCurrent)
                }
                .padding(14).background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    @ViewBuilder private func recommendationContent(_ plan: NavigationPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("顺路推荐", systemImage: "sparkles").font(.headline)
                Spacer()
                Toggle("自动推荐", isOn: SwiftUI.Binding(get: { plan.recommendationsEnabled }, set: { enabled in
                    Task { await navigation.setRecommendations(enabled) }
                })).labelsHidden().accessibilityLabel("自动推荐途经点")
            }
            if !plan.suggestions.isEmpty {
                Text("结合绕路耗时、停留时间与上课余量比较，确认后再加入路线。")
                    .font(.caption).foregroundStyle(.secondary)
                ForEach(Array(plan.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        suggestionCard(suggestion, preferred: index == 0, expired: suggestion.expiresAt <= context.date)
                    }
                }
            } else if plan.waypoints.isEmpty {
                Text(plan.recommendationsEnabled ? "可以输入途经需求，再评估是否顺路。" : "自动推荐已关闭，仍可主动评估一次途经需求。")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(Array(plan.decisions.enumerated()), id: \.offset) { _, decision in
                let name = map.snapshot?.document.features.first(where: { $0.id == decision.placeID })?.name ?? "候选地点"
                Text("\(name)：\(decision.reasonCode == "insufficient_time" ? "停留后可能影响准时到达，暂不推荐" : "目前没有合适的通行方案")")
                    .font(.caption).foregroundStyle(.secondary)
                if let extra = decision.extraSeconds {
                    Text("比直接前往多用约 \(minutes(extra)) 分钟（含停留）")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            #if DEMO
            if plan.waypoints.isEmpty && plan.suggestions.isEmpty {
                MapPanelAction(title: "评估顺路取咖啡", symbol: "cup.and.saucer") {
                    Task { await navigation.evaluateStop("顺路取已下单的咖啡，停留两分钟") }
                }
            }
            #else
            HStack {
                TextField("例如：顺路取咖啡", text: $stopRequest).textFieldStyle(.roundedBorder)
                MapPanelIconButton(title: "评估途经需求", symbol: "arrow.up.circle.fill", tint: .accentColor) {
                    dismissKeyboard()
                    Task { await navigation.evaluateStop(stopRequest) }
                }
                    .disabled(stopRequest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            #endif
        }
        .disabled(navigation.isWorking || !navigation.isCurrent)
    }

    private func suggestionCard(_ suggestion: NavigationSuggestion, preferred: Bool, expired: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(suggestion.name, systemImage: "cup.and.saucer.fill").font(.headline)
                Spacer()
                if expired { Text("已过期").font(.caption).foregroundStyle(.secondary) }
                else if preferred { Text("推荐").font(.caption.bold()).foregroundStyle(Color.accentColor) }
            }
            Text("多用约 \(minutes(suggestion.extraSeconds)) 分钟 · 停留 \(minutes(suggestion.dwellSeconds)) 分钟")
                .font(.subheadline)
            Text("全程 \(Int(suggestion.route.distanceMeters.rounded())) 米 · 约 \(minutes(suggestion.timing.totalSeconds)) 分钟")
                .font(.caption).foregroundStyle(.secondary)
            if let remaining = suggestion.timing.remainingSeconds {
                Text(remaining >= 0 ? "预留提前到达时间后，仍余 \(margin(remaining))" : "预计可能晚到，不建议添加")
                    .font(.caption).foregroundStyle(remaining >= 0 ? Color.green : .orange)
            }
            #if DEMO
            Text("按已下单、到店取餐估算；不含现场排队。")
                .font(.caption2).foregroundStyle(.secondary)
            #else
            if suggestion.openingStatus == "unknown" {
                Text("营业状态及实际等待时间请以商家为准。")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            #endif
            if expired {
                Text("建议已过期，请重新规划后再查看。").font(.caption).foregroundStyle(.secondary)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { suggestionActions(suggestion, expired: expired) }
                VStack(spacing: 10) { suggestionActions(suggestion, expired: expired) }
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.accentColor.opacity(preferred ? 0.09 : 0.04), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.accentColor.opacity(preferred ? 0.35 : 0.12)))
    }

    @ViewBuilder private func suggestionActions(_ suggestion: NavigationSuggestion, expired: Bool) -> some View {
        MapPanelAction(title: navigation.previewSuggestionID == suggestion.id ? "收起预览" : "比较路线", symbol: "map") {
            navigation.previewSuggestion(navigation.previewSuggestionID == suggestion.id ? nil : suggestion.id)
        }
        .disabled(expired)
        .accessibilityIdentifier("route.suggestion.preview")
        MapPanelAction(title: "加入途经点", symbol: "plus.circle.fill", prominent: true) {
            Task { await navigation.acceptSuggestion(suggestion.id) }
        }
        .disabled(suggestion.timing.late || expired)
        .accessibilityIdentifier("route.suggestion.accept")
    }

    @ViewBuilder private func destinationChoices(_ plan: NavigationPlan) -> some View {
        let choices = plan.placeChoices ?? []
        let published = map.snapshot?.document.features.filter {
            $0.levelId == nil && ["building", "merchant", "poi", "gate"].contains($0.kind)
        }.map { NavigationPlace(placeID: $0.id, name: $0.campusDisplayName, kind: $0.kind, frameId: $0.frameId, category: nil) } ?? []
        let candidates = choices.isEmpty ? published : choices
        if candidates.count > 6 { MapPanelSearchField(prompt: "查找目的地", text: $destinationQuery) }
        let matches = candidates.filter { destinationQuery.isEmpty || $0.name.localizedStandardContains(destinationQuery) }
        if matches.isEmpty {
            message("没有找到匹配地点", "试试其他名称，或稍后刷新校园地图。", symbol: "mappin.slash")
        }
        ForEach(matches) { choice in
            choiceRow(choice.name, symbol: "mappin.and.ellipse") {
                dismissKeyboard()
                Task { await route.chooseDestination(choice) }
            }
        }
    }

    @ViewBuilder private func sourceContent(_ source: NavigationSource) -> some View {
        if let notice = navigation.sourceNotice {
            if let title = source.title { Text(title).font(.title2.bold()) }
            if let date = source.publishedAt {
                Label(date.formatted(.dateTime.year().month().day().hour().minute().locale(Locale(identifier: "zh_CN"))),
                      systemImage: "calendar")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Markdown(notice.content).textSelection(.enabled)
        } else if let error = navigation.sourceError {
            message("来源通知暂不可查看", error, symbol: "doc.text.magnifyingglass")
            MapPanelAction(title: "重新读取通知", symbol: "arrow.clockwise") {
                Task { await navigation.loadSource(source) }
            }
        } else { ProgressView("正在读取通知原文…") }
    }

    private func openSource(_ source: NavigationSource) {
        route.pausePlayback()
        route.selectedSource = source
        Task { await navigation.loadSource(source) }
    }

    private func avoidanceText(_ overlay: NavigationOverlay) -> String {
        switch overlay.avoidanceStatus {
        case "excluded": return "通知明确封闭的道路或入口已从路线中排除。"
        case "avoided": return "根据来源通知，路线已避开此处。"
        case "not_fully_avoided": return "此处存在施工提醒，当前路线未能完全避开。"
        default: return "此处有通知影响，暂时无法生成可通行路线。"
        }
    }

    private func warningText(_ code: String) -> String {
        switch code {
        case "notice_analysis_incomplete": return "部分通知的道路影响尚未分析完成，请同时留意学校通知。"
        case "late_fixed_stops_preserved": return "已保留指定途经点，预计可能晚到。"
        case "missing_entrance": return "目的建筑尚未关联室外入口，路线止于附近校园道路。"
        case "ai_rate_limited", "ai_upstream_unavailable": return "智能建议暂不可用，当前显示基础路线。"
        default: return "路线存在补充提示，请留意地图标记和来源通知。"
        }
    }

    private func choiceRow(_ title: String, symbol: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol).foregroundStyle(Color.accentColor).frame(width: 28)
            Text(title).font(.subheadline.weight(.medium)).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Image(systemName: selected ? "checkmark.circle.fill" : "chevron.right")
                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                .font(selected ? .body : .caption)
        }
        .padding(14).frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .background(Color.accentColor.opacity(selected ? 0.11 : 0.045), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .beButton(action).buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func message(_ title: String, _ description: String, symbol: String) -> some View {
        MapPanelMessage(title: title, message: description, symbol: symbol)
    }
}
