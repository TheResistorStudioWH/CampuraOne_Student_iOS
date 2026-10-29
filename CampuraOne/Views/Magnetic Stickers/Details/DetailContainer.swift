//
//  DetailContainer.swift
//  CampuraOne
//
//  Created by Lin Shay on 08/06/2026.
//

import SwiftUI
import PetaKitUIX
import SwiftData
import UIKit

#Preview("app - 已登录") {
    PreviewAppView()
}

struct DetailContainer: View {
    var selectedDetail: SelectedDashboardDetail
    let namespace: Namespace.ID
    @Binding var isOpened: Bool
    let onClose: () -> Void
    @State private var isShowingSettings = false
    
    var body: some View {
        GeometryReader { geometry in
            let context = DashboardDetailContext(
                descriptor: selectedDetail.descriptor,
                namespace: namespace,
                safeAreaInsets: EdgeInsets(
                    top: max(geometry.safeAreaInsets.top, windowSafeArea.top),
                    leading: max(geometry.safeAreaInsets.leading, windowSafeArea.left),
                    bottom: max(geometry.safeAreaInsets.bottom, windowSafeArea.bottom),
                    trailing: max(geometry.safeAreaInsets.trailing, windowSafeArea.right)
                ),
                controls: AnyView(detailControls)
            )

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Material.bar)
                .matchedGeometryEffect(id: "\(selectedDetail.id)-bg", in: namespace, properties: .frame)
                .overlay {
                    selectedDetail.presentation(in: context)
                }
                .ignoresSafeArea()
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                DashboardTileSettingsView(featureID: selectedDetail.id, featureTitle: selectedDetail.title)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
    private var detailControls: some View {
        VStack(spacing: 6) {
            Image(systemName: "xmark")
                .font(.title3.weight(.bold))
                .frame(width: DashboardDetailChrome.controlsWidth, height: DashboardDetailChrome.controlsWidth)
                .background(.regularMaterial, in: Circle())
                .beButton {
                    onClose()
                    withAnimation {
                        isOpened = false
                    }
                }
            .accessibilityLabel("关闭\(selectedDetail.title)")

            Image(systemName: "chevron.down")
                .font(.headline.bold())
                .rotationEffect(.degrees(isShowingSettings ? 180 : 0))
                .frame(width: DashboardDetailChrome.controlsWidth, height: 32)
                .contentShape(Rectangle())
                .beButton {
                    withAnimation(.smooth(duration: 0.24)) {
                        isShowingSettings = true
                    }
                }
            .accessibilityLabel("展开磁贴设置")
            .accessibilityHint("管理当前功能磁贴的通知")
        }
        .buttonStyle(.plain)
    }

    private var windowSafeArea: UIEdgeInsets {
        UIApplication.shared.connectedScenes
            .compactMap {
                $0 as? UIWindowScene
            }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?.safeAreaInsets ?? .zero
    }
    
}
