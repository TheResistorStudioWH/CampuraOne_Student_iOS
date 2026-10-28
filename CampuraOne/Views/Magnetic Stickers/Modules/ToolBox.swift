//
//  ToolBox.swift
//  CampuraOne
//
//  Created by LShayc1own on 25/05/2026.
//

import SwiftUI
import SwiftData

#Preview("app - 已登录") {
    PreviewAppView()
}

#Preview("app - 未登录") {
    PreviewAppView(signedIn: false)
}

struct ToolBoxTile: View {
    let context: DashboardTileContext

    var body: some View {
        DashboardTile(
            descriptor: DashboardTileDescriptor(id: "toolbox", title: "工具箱", systemImage: "square.grid.2x2.fill"),
            context: context
        ) {
            ToolBoxModule()
        } toolBar: {
            EmptyView()
        }
    }
}

struct ToolBoxModule: View {
    var body: some View {
        VStack(spacing: 6) {
            row(.restroom, .errands)
            row(.medicalSupplies, .feminineSupplies)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ leading: ToolboxShortcut, _ trailing: ToolboxShortcut) -> some View {
        HStack(spacing: 6) {
            tool(leading)
            tool(trailing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tool(_ shortcut: ToolboxShortcut) -> some View {
        VStack(spacing: 4) {
            Image(systemName: shortcut.symbol)
                .font(.title3.weight(.medium))
                .foregroundStyle(.tint)
            Text(shortcut.title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .beButton {

        }
        .buttonStyle(.plain)
        .accessibilityLabel(shortcut.accessibilityTitle)
        .accessibilityHint("功能待开放")
    }
}

private enum ToolboxShortcut {
    case restroom, errands, medicalSupplies, feminineSupplies

    var title: String {
        switch self {
        case .restroom: "卫生间"
        case .errands: "找跑腿"
        case .medicalSupplies: "医疗用品"
        case .feminineSupplies: "女性用品"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .restroom: "找最近的卫生间"
        case .errands: "找跑腿"
        case .medicalSupplies: "寻找医疗用品售卖点"
        case .feminineSupplies: "寻找女性用品售卖点"
        }
    }

    var symbol: String {
        switch self {
        case .restroom: "toilet.fill"
        case .errands: "figure.run"
        case .medicalSupplies: "cross.case.fill"
        case .feminineSupplies: "bag.fill"
        }
    }
}
