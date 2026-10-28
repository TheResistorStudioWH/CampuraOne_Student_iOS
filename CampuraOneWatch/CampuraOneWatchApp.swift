import SwiftUI

@main
struct CampuraOneWatchApp: App {
    @StateObject private var store = WatchScheduleStore(api: WatchAPI(transport: WatchAlamofireTransport.send))
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchRootView()
                .environmentObject(store)
                .task { await store.start() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { Task { await store.refreshIfNeeded() } }
                }
        }
    }
}

struct WatchRootView: View {
    @EnvironmentObject private var store: WatchScheduleStore
    @State private var selection: WatchCalendarKind?

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "--watch-calendar"), arguments.indices.contains(index + 1) {
            _selection = State(initialValue: WatchCalendarKind(rawValue: arguments[index + 1]))
        }
        #endif
    }

    var body: some View {
        NavigationSplitView {
            List(WatchCalendarKind.allCases, selection: $selection) { kind in
                NavigationLink(value: kind) {
                    HStack(spacing: 10) {
                        Image(systemName: kind.symbol)
                            .font(.title3)
                            .foregroundStyle(kind.tint)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(kind.title).font(.headline)
                            Text(summary(kind))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 5)
                }
                .accessibilityIdentifier("calendar.open.\(kind.rawValue)")
            }
            .navigationTitle("域校屿")
        } detail: {
            if let selection {
                WatchCalendarView(kind: selection)
                    .id(selection)
            } else {
                Text("选择课表或校历")
            }
        }
    }

    private func summary(_ kind: WatchCalendarKind) -> String {
        let model = store.list(kind)
        if model.isLoading && model.items.isEmpty { return "正在更新" }
        if model.errorMessage != nil && model.items.isEmpty { return "轻点重试" }
        let today = WatchCalendarData.events(on: Date(), kind: kind, entries: model.items)
        return today.isEmpty ? "今天没有安排" : "今天 \(today.count) 项安排"
    }
}

extension WatchCalendarKind {
    var tint: Color { self == .courses ? .cyan : .purple }
}
