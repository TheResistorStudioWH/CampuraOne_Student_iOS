import SwiftUI
import PetaKitUIX
import MarkdownUI
import CamapKit

struct RoutePreviewHeader: View {
    @ObservedObject var route: RoutePreviewStore
    @ObservedObject private var navigation = StudentNavigationStore.shared
    let onBack: () -> Void
    let onClose: () -> Void

    var body: some View {
        PreviewPanelHeader(
            title: route.selectedSource != nil ? "通知原文" : route.isSelectingOrigin ? "选择起点" : "路线预览",
            subtitle: route.selectedSource == nil ? navigation.plan?.destination?.name ?? route.target?.title : nil,
            showBack: true, onBack: onBack, onClose: onClose
        ) {
            if route.selectedSource == nil, !route.isSelectingOrigin {
                HStack {
                    Label(route.originName, systemImage: "location.circle")
                        .lineLimit(1).beButton { route.isSelectingOrigin = true }
                        .accessibilityLabel("修改起点：\(route.originName)")
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .beButton(route.fitRoute).accessibilityLabel("查看全程")
                    Image(systemName: "arrow.clockwise")
                        .beButton { Task { await route.calculate() } }
                        .disabled(navigation.isWorking || route.isCalculating)
                        .accessibilityLabel("重新规划路线")
                }
                .font(.subheadline).foregroundStyle(Color.accentColor).buttonStyle(.plain)
            }
        }
    }
}

struct RoutePreviewPanel: View {
    @ObservedObject var route: RoutePreviewStore
    @ObservedObject private var navigation = StudentNavigationStore.shared
    @ObservedObject private var map = CampusMapStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let source = route.selectedSource { sourceContent(source) }
                else if let error = route.preparationError {
                    message("校园路线暂不可用", error, symbol: "map")
                    Text("重新读取地图").beButton { Task { await route.prepare() } }
                } else if route.isSelectingOrigin { originPicker }
                else if navigation.isWorking || route.isCalculating {
                    ProgressView("正在规划校园路线…").frame(maxWidth: .infinity).padding(.vertical, 30)
                } else {
                    if let error = navigation.errorMessage {
                        message("路线尚未更新", error, symbol: "exclamationmark.triangle")
                    }
                    if navigation.requiresReplan || navigation.requiresRestart {
                        Text("路线信息已变化，请重新规划后查看。").foregroundStyle(.orange)
                    }
                    if let plan = navigation.plan { planContent(plan) }
                    else if navigation.errorMessage == nil { ProgressView("正在准备路线…") }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.bottom, 28)
        }
        .scrollIndicators(.hidden)
        .task(id: route.requestID) { if route.origin == nil { await route.prepare() } }
    }

    private var originPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("从校园路网中选择出发位置。所选起点用于本次路线预览。").font(.subheadline).foregroundStyle(.secondary)
            if route.canUseCurrentLocation {
                Label("使用当前位置", systemImage: "location.fill")
                    .foregroundStyle(Color.accentColor).padding(.vertical, 8)
                    .beButton { Task { await route.useCurrentLocation() } }
            }
            if route.originOptions.isEmpty {
                message("暂无可用起点", "学校还没有发布可通行的路网。", symbol: "point.topleft.down.curvedto.point.bottomright.up")
            }
            ForEach(route.originOptions) { option in
                Label(option.name, systemImage: "mappin.circle")
                    .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                    .background(Color.accentColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
                    .contentShape(Rectangle())
                    .beButton { Task { await route.selectOrigin(option) } }.buttonStyle(.plain)
                    .accessibilityIdentifier("route.origin.\(option.id)")
            }
        }
    }

    @ViewBuilder private func planContent(_ plan: NavigationPlan) -> some View {
        if plan.hasRoute, let timing = plan.timing, let path = plan.route {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text("\(max(1, Int(ceil(Double(timing.walkingSeconds) / 60)))) 分钟")
                    .font(.largeTitle.bold()).foregroundStyle(Color.accentColor)
                Text(path.distanceMeters.formatted(.number.precision(.fractionLength(0))) + " 米")
                    .font(.headline).foregroundStyle(.secondary)
            }
            Label("预计 \(timing.estimatedArrival.formatted(date: .omitted, time: .shortened)) 到达", systemImage: "figure.walk")
            if let schedule = plan.schedule {
                VStack(alignment: .leading, spacing: 6) {
                    Text(schedule.title).font(.headline)
                    Text("\(schedule.location) · \(Date(timeIntervalSince1970: schedule.startAt).formatted(date: .abbreviated, time: .shortened))")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            if let remaining = timing.remainingSeconds {
                Label(remaining >= 0 ? "保守估计仍有 \(remaining / 60) 分钟余量" : "可能晚到约 \(Int(ceil(Double(-remaining) / 60))) 分钟",
                      systemImage: remaining >= 0 ? "checkmark.circle" : "exclamationmark.triangle")
                    .font(.subheadline).foregroundStyle(remaining >= 0 ? Color.green : .orange)
            }
            Text("步行时间为估计值；路线按本次起点计算。")
                .font(.caption).foregroundStyle(.secondary)
        } else if plan.status == "unreachable" {
            message("暂时没有可通行路线", "已发布路网中无法连通所选起终点，请尝试其他起点或等待学校更新。", symbol: "figure.walk.diamond")
        } else if plan.status == "needs_destination" || plan.status == "needs_place_resolution" {
            message("请选择地点", plan.status == "needs_destination" ? "暂时没有可匹配的下一节课，请选择校园目的地。" : "请确认这次要前往的具体地点。", symbol: "mappin.and.ellipse")
            destinationChoices(plan)
        }
        if let frame = map.snapshot?.document.frames.first(where: { $0.id == plan.route?.frameId }), frame.bindings["mapkit"] == nil {
            Label(map.displayMode == .original ? "地图未校准，请切换到绘制图查看路线" : "未校准：路线仅表示校园内部关系", systemImage: "exclamationmark.triangle")
                .font(.subheadline).foregroundStyle(.orange)
                .beButton { if map.displayMode == .original { map.displayMode = .drawing } }
        }
        if !plan.overlays.isEmpty {
            Text("沿途提醒").font(.headline)
            ForEach(plan.overlays) { overlay in
                VStack(alignment: .leading, spacing: 8) {
                    Label(overlay.name, systemImage: overlay.kind == "closure" ? "hand.raised" : "exclamationmark.triangle")
                        .font(.subheadline.bold()).foregroundStyle(.orange)
                    Text(avoidanceText(overlay)).font(.subheadline)
                    if let source = plan.sources.first(where: { $0.announceID == overlay.sourceID && $0.version == overlay.sourceVersion }) {
                        Label(source.title ?? "查看来源通知", systemImage: "doc.text")
                            .font(.caption).foregroundStyle(Color.accentColor)
                            .beButton { openSource(source) }
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

    @ViewBuilder private func destinationChoices(_ plan: NavigationPlan) -> some View {
        let choices = plan.placeChoices ?? []
        if !choices.isEmpty {
            ForEach(choices) { choice in
                Label(choice.name, systemImage: "mappin").padding(.vertical, 8)
                    .beButton { Task { await route.chooseDestination(choice) } }
            }
        } else if let document = map.snapshot?.document {
            ForEach(document.features.filter { $0.levelId == nil && ["building", "merchant", "poi", "gate"].contains($0.kind) }, id: \.id) { place in
                Label(place.name, systemImage: "mappin").padding(.vertical, 8)
                    .beButton {
                        Task { await route.chooseDestination(.init(placeID: place.id, name: place.name, kind: place.kind, frameId: place.frameId, category: nil)) }
                    }
            }
        }
    }

    @ViewBuilder private func sourceContent(_ source: NavigationSource) -> some View {
        if let notice = navigation.sourceNotice {
            if let title = source.title { Text(title).font(.title2.bold()) }
            if let date = source.publishedAt { Text(date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) }
            Markdown(notice.content).textSelection(.enabled)
        } else if let error = navigation.sourceError {
            message("来源通知暂不可查看", error, symbol: "doc.text.magnifyingglass")
        } else { ProgressView("正在读取通知原文…") }
    }

    private func openSource(_ source: NavigationSource) {
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
        case "ai_rate_limited", "ai_upstream_unavailable": return "智能建议暂不可用，当前显示基础路线。"
        default: return "路线存在补充提示，请留意地图标记和来源通知。"
        }
    }

    private func message(_ title: String, _ description: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol).font(.headline)
            Text(description).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
