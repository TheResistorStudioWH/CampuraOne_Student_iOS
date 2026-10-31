import SwiftUI
import PetaKitUIX

/// Local settings placeholders; no networking or live-model configuration is changed.
struct AIModelSettingsView: View {
    @AppStorage private var encodedOptions: String
    @State private var apiKeys: [AIFunction: String] = [:]

    init(userID: Int) {
        _encodedOptions = AppStorage(wrappedValue: "{}", "campura.ai.model-options.\(userID)")
    }

    var body: some View {
        Form {
            Section {
                Text("为不同功能分别选择模型。当前预设仅提供 Qwen。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } footer: {
                Text("此处为设置预留，暂不改变实际使用的模型。")
            }

            ForEach(AIFunction.allCases) { feature in
                Section {
                    Picker("模型", selection: option(feature, \.source)) {
                        Text("Qwen · 通义千问").tag(AIModelSource.qwen)
                        Text("自定义 API").tag(AIModelSource.custom)
                    }
                    .accessibilityIdentifier("ai.model.\(feature.rawValue)")

                    if options(for: feature).source == .custom {
                        TextField("API 地址", text: option(feature, \.endpoint), axis: .vertical)
                            .keyboardType(.URL)
                            .textContentType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("ai.endpoint.\(feature.rawValue)")

                        TextField("模型 ID", text: option(feature, \.modelID))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityIdentifier("ai.modelID.\(feature.rawValue)")

                        SecureField("API Key", text: Binding(
                            get: { apiKeys[feature] ?? "" },
                            set: { apiKeys[feature] = $0 }
                        ))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .privacySensitive()
                        .accessibilityIdentifier("ai.apiKey.\(feature.rawValue)")
                    }
                } header: {
                    Label(feature.title, systemImage: feature.symbol)
                } footer: {
                    Text(options(for: feature).source == .custom
                         ? "自定义 API 暂未启用。API Key 暂不保存或发送，离开页面后清空。"
                         : feature.description)
                }
            }
        }
        .navigationTitle("AI 模型")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { apiKeys.removeAll() }
    }

    private var savedOptions: [String: AIModelOptions] {
        guard let data = encodedOptions.data(using: .utf8),
              let options = try? JSONDecoder().decode([String: AIModelOptions].self, from: data) else { return [:] }
        return options
    }

    private func options(for feature: AIFunction) -> AIModelOptions {
        savedOptions[feature.rawValue] ?? AIModelOptions()
    }

    private func option<Value>(_ feature: AIFunction,
                               _ keyPath: WritableKeyPath<AIModelOptions, Value>) -> Binding<Value> {
        Binding(get: { options(for: feature)[keyPath: keyPath] }, set: { value in
            var all = savedOptions
            var options = all[feature.rawValue] ?? AIModelOptions()
            options[keyPath: keyPath] = value
            all[feature.rawValue] = options
            guard let data = try? JSONEncoder().encode(all), let text = String(data: data, encoding: .utf8) else { return }
            encodedOptions = text
        })
    }
}

private enum AIFunction: String, CaseIterable, Identifiable {
    case routeRecommendation, routePlanning, announcementSummary
    var id: Self { self }

    var title: String {
        switch self {
        case .routeRecommendation: return "路线推荐"
        case .routePlanning: return "路线规划"
        case .announcementSummary: return "通知摘要"
        }
    }
    var symbol: String {
        switch self {
        case .routeRecommendation: return "sparkles"
        case .routePlanning: return "point.topleft.down.to.point.bottomright.curvepath"
        case .announcementSummary: return "text.bubble"
        }
    }
    var description: String {
        switch self {
        case .routeRecommendation: return "结合日程与偏好，推荐合适的目的地和途经点。"
        case .routePlanning: return "结合校园地图与通知，辅助安排路线。"
        case .announcementSummary: return "提炼通知中的重点事项。"
        }
    }
}

private enum AIModelSource: String, Codable {
    case qwen, custom
}

private struct AIModelOptions: Codable {
    var source: AIModelSource = .qwen
    var endpoint = ""
    var modelID = ""
    // API keys intentionally never enter this persisted value.
}

#Preview("AI 模型设置") {
    NavigationStack {
        AIModelSettingsView(userID: 0)
    }
}
