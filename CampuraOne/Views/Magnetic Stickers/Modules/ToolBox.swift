//
//  ToolBox.swift
//  CampuraOne
//
//  Created by LShayc1own on 25/05/2026.
//

import SwiftUI
import SwiftData

#Preview("app - 已登录") {
    ContentView()
        .modelContainer(PreviewContainer.app)
}

#Preview("app - 未登录") {
    ContentView()
        .modelContainer(PreviewContainer.empty)
}

struct ToolBoxModule: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            tool("找最近的卫生间", symbol: "figure.stand")
            tool("跑腿", symbol: "figure.run")
            tool("快递外卖", symbol: "shippingbox")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    private func tool(_ name: String, symbol: String) -> some View {
        Label {
            Text(name).font(.caption.weight(.medium)).lineLimit(1)
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .frame(width: 24)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
