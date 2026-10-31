import SwiftUI
import PetaKitUIX
import CamapKit

struct CampusMapControls: View {
    struct FrameOption: Identifiable { let id: String; let name: String }
    @SwiftUI.Binding var mode: CampusMapDisplayMode
    @SwiftUI.Binding var selectedFrameID: String?
    let frames: [FrameOption]
    let isUncalibrated: Bool
    let isEditing: Bool
    let toggleEditing: () -> Void
    let resetPlacement: () -> Void

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            Menu {
                Picker("地图显示方式", selection: $mode) {
                    ForEach(CampusMapDisplayMode.allCases) { mode in
                        Label(mode.title, systemImage: mode.symbol).tag(mode)
                    }
                }
                if frames.count > 1 {
                    Picker("校园绘制区域", selection: $selectedFrameID) {
                        ForEach(frames) { frame in Text(frame.name).tag(Optional(frame.id)) }
                    }
                }
            } label: {
                Label(mode.title, systemImage: mode.symbol)
                    .labelStyle(.iconOnly)
                    .font(.subheadline.weight(.medium))
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .accessibilityLabel("地图显示方式")
            .accessibilityValue(mode.title)
            .accessibilityIdentifier("campus.map.mode")

            if isUncalibrated, mode != .original {
                HStack(spacing: 12) {
                    Label(isEditing ? "完成摆放" : "摆放", systemImage: isEditing ? "checkmark" : "hand.draw")
                        .beButton(toggleEditing)
                        .accessibilityIdentifier("campus.map.placement")
                    if isEditing {
                        Image(systemName: "arrow.counterclockwise")
                            .beButton(resetPlacement)
                            .accessibilityLabel("重置临时位置")
                    }
                }
                .font(.subheadline.weight(.medium))
                .padding(12)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                if isEditing {
                    Text("拖动移动 · 双指旋转\n位置仅保留于本次登录")
                        .font(.caption2).foregroundStyle(.secondary)
                        .padding(10)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

/// The compact map status row sits immediately above the horizontal StatusBar.
struct CampusMapStatusRow: View {
    @EnvironmentObject private var authSession: AuthSession
    @ObservedObject private var map = CampusMapStore.shared
    @ObservedObject private var navigation = StudentNavigationStore.shared

    private var isUncalibrated: Bool {
        map.snapshot?.document.frames.first(where: { $0.id == map.selectedFrameID })
            .map { $0.bindings["mapkit"] == nil } ?? false
    }

    private var statusMessage: String? {
        if let error = map.errorMessage { return "地图未更新：\(error)" }
        if !map.isLoading, map.snapshot == nil { return "校园地图尚不可用" }
        if let snapshot = map.snapshot, snapshot.document.frames.isEmpty { return "尚未发布绘制区域" }
        if let plan = navigation.plan, map.snapshot?.hash != plan.mapHash { return "地图与路线版本不一致，请刷新" }
        return nil
    }

    var body: some View {
        HStack(spacing: 8) {
            if isUncalibrated {
                Label("未校准，仅供示意", systemImage: "exclamationmark.triangle")
                    .fixedSize(horizontal: true, vertical: false)
                    .font(.system(size: 12))
                    .statusBarCapsuleStyle(tint: .orange)
            }

            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12))
                .opacity(map.isLoading ? 0 : 1)
                .overlay {
                    if map.isLoading { ProgressView().controlSize(.mini) }
                }
                .statusBarCapsuleStyle()
                .beButton(refresh)
                .buttonStyle(.plain)
                .disabled(map.isLoading || navigation.isWorking)
                .accessibilityLabel("刷新校园地图和路线")
                .accessibilityIdentifier("campus.map.refresh")

            if let statusMessage {
                Text(statusMessage)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .statusBarCapsuleStyle()
                    .accessibilityIdentifier("campus.map.message")
            }
        }
        .padding(.horizontal, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func refresh() {
        guard let userID = authSession.currentUser?.userID else { return }
        Task {
            await map.load(userID: userID, force: true)
            if navigation.plan != nil { await navigation.replan() }
        }
    }
}
