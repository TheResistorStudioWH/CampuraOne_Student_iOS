import SwiftUI
import PetaKitUIX

struct NavigationHistorySection: View {
    let userID: Int
    @ObservedObject private var store = NavigationPreferencesStore.shared
    @State private var confirmClear = false
    @State private var didClear = false

    var body: some View {
        Section {
            Toggle(isOn: Binding(
                get: { store.preferences?.historyEnabled ?? false },
                set: { enabled in Task { await store.setHistoryEnabled(enabled) } }
            )) {
                Label("历史学习", systemImage: "sparkles")
            }
            .disabled(store.preferences == nil || store.isLoading || store.isSaving)
            .accessibilityIdentifier("navigation.history.enabled")

            if store.isLoading || store.isSaving { ProgressView(store.isSaving ? "正在保存…" : "正在读取设置…") }
            if let error = store.errorMessage {
                Text(error).font(.caption).foregroundStyle(.secondary)
                Text("重新读取设置")
                    .beButton { Task { await store.load(userID: userID, force: true) } }
                    .disabled(store.isLoading || store.isSaving)
            }
            if store.preferences != nil {
                // Native lazy destination: the editor must read preferences when opened.
                NavigationLink {
                    NavigationPreferencesView()
                } label: { Label("路线偏好", systemImage: "slider.horizontal.3") }
                Text("清除学习历史")
                    .foregroundStyle(.red)
                    .beButton { confirmClear = true }
                    .disabled(store.isLoading || store.isSaving)
                    .accessibilityIdentifier("navigation.history.clear")
            }
        } header: {
            Text("导航与推荐")
        } footer: {
            Text("历史学习默认关闭。开启后使用最近90天的地点操作优化推荐，不记录连续定位。关闭不会删除已有历史；清除历史不会更改手选偏好。")
        }
        .task(id: userID) { await store.load(userID: userID) }
        .confirmationDialog("清除学习历史？", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("清除历史", role: .destructive) {
                Task { didClear = await store.clearHistory() }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("仅删除学习记录及其推导偏好，保留你手动设置的路线偏好。")
        }
        .alert("学习历史已清除", isPresented: $didClear) {
            Button("好", role: .cancel) { }
        }
    }
}

private struct NavigationPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var store = NavigationPreferencesStore.shared
    @State private var draft: NavigationPreferences?
    private let categories = [("coffee", "咖啡"), ("food", "餐饮"), ("water", "饮水"), ("library", "图书馆"), ("other", "其他")]

    var body: some View {
        Form {
            if let draft {
                Section("路线") {
                    Toggle("默认主动推荐途经点", isOn: field(\.recommendationsEnabled, fallback: draft.recommendationsEnabled))
                    Toggle("无障碍通行", isOn: field(\.accessible, fallback: draft.accessible))
                    Toggle("优先已有遮挡道路", isOn: field(\.preferCovered, fallback: draft.preferCovered))
                    LabeledContent("步行速度", value: "\(draft.walkingSpeed.formatted(.number.precision(.fractionLength(1)))) 米/秒")
                    Slider(value: field(\.walkingSpeed, fallback: draft.walkingSpeed), in: 0.7...2, step: 0.1)
                        .accessibilityLabel("步行速度")
                    Stepper(value: field(\.arrivalBufferMinutes, fallback: draft.arrivalBufferMinutes), in: 0...60, step: 1) {
                        Text("提前 \(Int(draft.arrivalBufferMinutes)) 分钟到达")
                    }
                }
                categorySection("感兴趣的地点", keyPath: \.interests)
                categorySection("不推荐的地点", keyPath: \.blockedCategories)
            }
            if let message = store.errorMessage {
                Section { Text(message).font(.caption).foregroundStyle(.secondary) }
            }
        }
        .disabled(store.isSaving)
        .navigationTitle("路线偏好")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if draft == nil { draft = store.preferences } }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Group {
                    if store.isSaving { ProgressView() }
                    else { Text("保存").beButton { Task { await save() } } }
                }
                .disabled(draft == nil || store.isSaving)
            }
        }
    }

    private func field<T>(_ keyPath: WritableKeyPath<NavigationPreferences, T>, fallback: T) -> Binding<T> {
        Binding(get: { draft?[keyPath: keyPath] ?? fallback }, set: { draft?[keyPath: keyPath] = $0 })
    }

    private func categorySection(_ title: String, keyPath: WritableKeyPath<NavigationPreferences, [String]>) -> some View {
        Section(title) {
            ForEach(categories, id: \.0) { id, title in
                Toggle(title, isOn: Binding(
                    get: { draft?[keyPath: keyPath].contains(id) ?? false },
                    set: { enabled in
                        draft?[keyPath: keyPath].removeAll { $0 == id }
                        if enabled { draft?[keyPath: keyPath].append(id) }
                    }
                ))
            }
        }
    }

    private func save() async {
        guard let draft else { return }
        let success = await store.save(NavigationPreferenceUpdate(
            expectedVersion: draft.version, recommendationsEnabled: draft.recommendationsEnabled,
            interests: draft.interests, blockedCategories: draft.blockedCategories,
            walkingSpeed: draft.walkingSpeed, arrivalBufferMinutes: draft.arrivalBufferMinutes,
            accessible: draft.accessible, preferCovered: draft.preferCovered))
        if success { dismiss() }
        else if store.preferences?.version != draft.version {
            // A new version must be reviewed before another save attempt.
            self.draft = store.preferences
        }
    }
}

#Preview("历史学习设置") {
    NavigationStack {
        Form { NavigationHistorySection(userID: 1) }
            .navigationTitle("账号")
    }
}
