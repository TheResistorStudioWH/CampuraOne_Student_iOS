import SwiftUI

enum DashboardNotificationPreference: String, CaseIterable, Identifiable {
    case off
    case muteToday
    case muteWeek
    case on

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "关闭通知"
        case .muteToday: "今天内静音"
        case .muteWeek: "一周内静音"
        case .on: "打开"
        }
    }

    var symbol: String {
        switch self {
        case .off: "bell.slash"
        case .muteToday: "bell.and.waves.left.and.right"
        case .muteWeek: "bell.badge.slash"
        case .on: "bell.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .off: "不再接收此磁贴的通知"
        case .muteToday: "今天结束后自动打开"
        case .muteWeek: "七天后自动打开"
        case .on: "接收此磁贴的通知"
        }
    }
}

/// Notification schedulers can query the same preference without duplicating
/// mute-window and expiry rules.
struct DashboardNotificationSettings {
    private let featureID: String
    private let defaults: UserDefaults

    init(featureID: String, defaults: UserDefaults = .standard) {
        self.featureID = featureID
        self.defaults = defaults
    }

    func preference(at date: Date = .now, calendar: Calendar = .current) -> DashboardNotificationPreference {
        let saved = defaults.string(forKey: preferenceKey).flatMap(DashboardNotificationPreference.init(rawValue:)) ?? .on
        guard let until = muteUntil(at: date) else { return saved }
        if until <= date {
            set(.on, at: date, calendar: calendar)
            return .on
        }
        return saved
    }

    var allowsNotifications: Bool {
        preference() == .on
    }

    func set(_ preference: DashboardNotificationPreference, at date: Date = .now, calendar: Calendar = .current) {
        defaults.set(preference.rawValue, forKey: preferenceKey)
        let mutedUntil: Date?
        switch preference {
        case .muteToday:
            mutedUntil = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))
        case .muteWeek:
            mutedUntil = calendar.date(byAdding: .day, value: 7, to: date)
        case .off, .on:
            mutedUntil = nil
        }

        if let mutedUntil {
            defaults.set(mutedUntil.timeIntervalSince1970, forKey: muteUntilKey)
        } else {
            defaults.removeObject(forKey: muteUntilKey)
        }
    }

    func muteUntil(at date: Date = .now) -> Date? {
        let timestamp = defaults.double(forKey: muteUntilKey)
        guard timestamp > 0 else { return nil }
        let until = Date(timeIntervalSince1970: timestamp)
        return until > date ? until : nil
    }

    private var preferenceKey: String { "campura.dashboard.\(featureID).notification-preference" }
    private var muteUntilKey: String { "campura.dashboard.\(featureID).notification-muted-until" }
}

struct DashboardNotificationSettingsView: View {
    let featureTitle: String
    @State private var preference: DashboardNotificationPreference
    private let settings: DashboardNotificationSettings

    init(featureID: String, featureTitle: String) {
        self.featureTitle = featureTitle
        settings = DashboardNotificationSettings(featureID: featureID)
        _preference = State(initialValue: settings.preference())
    }

    var body: some View {
        List {
            Section {
                ForEach(DashboardNotificationPreference.allCases) { option in
                    Button {
                        withAnimation(.smooth(duration: 0.2)) {
                            preference = option
                        }
                        settings.set(option)
                        TapSoft()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: option.symbol)
                                .font(.title3)
                                .frame(width: 28)
                                .foregroundStyle(Color.accentColor)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title).foregroundStyle(.primary)
                                Text(option.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                            if preference == option {
                                Image(systemName: "checkmark")
                                    .font(.headline)
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("\(featureTitle)通知")
            } footer: {
                Text("当前先保存通知偏好；各磁贴的具体提醒功能将分别接入此设置。")
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("管理当前功能磁贴的通知")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { preference = settings.preference() }
    }
}

struct DashboardTileSettingsView: View {
    let featureID: String
    let featureTitle: String

    var body: some View {
        List {
            NavigationLink {
                DashboardNotificationSettingsView(featureID: featureID, featureTitle: featureTitle)
            } label: {
                Label("管理当前功能磁贴的通知", systemImage: "bell.badge")
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("磁贴设置") {
    NavigationStack {
        DashboardTileSettingsView(featureID: "courseTable", featureTitle: "日程表")
    }
}

#Preview("磁贴通知设置") {
    NavigationStack {
        DashboardNotificationSettingsView(featureID: "courseTable", featureTitle: "日程表")
    }
}
