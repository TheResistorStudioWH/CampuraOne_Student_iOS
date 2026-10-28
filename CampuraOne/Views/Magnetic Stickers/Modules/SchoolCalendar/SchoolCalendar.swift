//
//  SchoolCalendar.swift
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

struct SchoolCalendarTile: View {
    let context: DashboardTileContext
    @State private var refreshID = UUID()

    var body: some View {
        DashboardTile(
            descriptor: SchoolCalendarDetail.tileDescriptor,
            context: context,
            titleAction: open
        ) {
            ICSSchoolCalendarMini(onOpen: open)
                .id(refreshID)
        } toolBar: {
            HStack(spacing: 6) {
                SchoolCalendarRefreshButton {
                    refreshID = UUID()
                }
                Image(systemName: "chevron.right")
                    .beButton(open)
                    .buttonStyle(.plain)
                    .accessibilityLabel("打开完整校历")
            }
        }
    }

    private func open() {
        context.open(SchoolCalendarDetail())
    }
}

private struct SchoolCalendarRefreshButton: View {
    let action: () -> Void
    @State private var switchSymbol = false

    var body: some View {
        Image(systemName: switchSymbol ? "arrow.trianglehead.2.clockwise" : "arrow.trianglehead.2.counterclockwise")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.secondary)
            .contentTransition(.symbolEffect(.replace.magic(fallback: .replace.byLayer), options: .nonRepeating))
            .frame(width: 22, height: 22)
            .background {
                Circle()
                    .fill(Material.ultraThin)
            }
            .contentShape(Circle())
            .beButton {
                switchSymbol.toggle()
                withAnimation(.snappy) {
                    action()
                }
                TapSucceed()
            }
            .animation(.smooth, value: switchSymbol)
    }
}
