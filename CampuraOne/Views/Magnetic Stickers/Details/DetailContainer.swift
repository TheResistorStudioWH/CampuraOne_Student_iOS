//
//  DetailContainer.swift
//  CampuraOne
//
//  Created by Lin Shay on 08/06/2026.
//

import SwiftUI
import SwiftData

#Preview("app - 已登录") {
    ContentView()
        .modelContainer(PreviewContainer.app)
}

struct DetailContainer: View {
    var selectedDetail: SelectedDashboardDetail
    let namespace: Namespace.ID
    @Binding var isOpened: Bool
    let onClose: () -> Void
    @State private var isShowingSettings = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .fill(Material.bar)
            .matchedGeometryEffect(id: "\(selectedDetail.id)-bg", in: namespace, properties: .frame)
            .overlay {
                DetailContent()
                .padding(.vertical, 16)
                .padding(.trailing, 16)
                .padding(.leading, selectedDetail.id == "courseTable" ? 0 : 16)
                .padding(.vertical, screen.height/16)
            }
            .ignoresSafeArea()
//        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        //        .ignoresSafeArea()
    }
    
    @ViewBuilder func DetailContent() -> some View {
        if selectedDetail.id == "courseTable" {
            VStack(alignment: .leading, spacing: 4) {
                detailHeader
                selectedDetail.view
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            ScrollView {
                VStack(alignment: .leading) {
                    detailHeader
                    selectedDetail.view
                }
            }
        }
    }

    private var detailHeader: some View {
        HStack {
            if selectedDetail.id != "courseTable", !selectedDetail.systemImage.isEmpty {
                Image(systemName: selectedDetail.systemImage)
                    .font(.system(size: 34, weight: .semibold))
                    .matchedGeometryEffect(id: "\(selectedDetail.id)-icon", in: namespace, properties: .frame)
            }

            if !selectedDetail.title.isEmpty {
                Text(selectedDetail.id == "courseTable" ? "日程表" : selectedDetail.title)
                    .font(.system(size: 40))
                    .fontWeight(.bold)
                    .matchedGeometryEffect(id: "\(selectedDetail.id)-title", in: namespace, properties: .position)
            }

            VStack(spacing: 6) {
                Image(systemName: "xmark")
                    .font(.title)
                    .bold()
                    .padding()
                    .background {
                        Circle().fill(Material.regular)
                    }
                    .beButton {
                        onClose()
                        withAnimation { isOpened = false }
                    }
                    .buttonStyle(.borderless)

                Button {
                    withAnimation(.smooth(duration: 0.24)) {
                        isShowingSettings = true
                    }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.headline.bold())
                        .frame(width: 44, height: 36)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("展开磁贴设置")
                .accessibilityHint("管理当前功能磁贴的通知")
                .rotationEffect(.degrees(isShowingSettings ? 180 : 0))
            }
        }
        .padding(.leading, selectedDetail.id == "courseTable" ? 16 : 0)
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                DashboardTileSettingsView(
                    featureID: selectedDetail.id,
                    featureTitle: selectedDetail.title
                )
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
    
}
