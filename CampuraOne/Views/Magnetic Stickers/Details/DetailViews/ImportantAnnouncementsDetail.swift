import SwiftUI
import MarkdownUI

/// 重要通知的列表和阅读页；入口留在通知磁贴中。
struct MarkdownAnnouncementsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let announces: [AnnouncementItem]
    @State private var sortByDeadline = false

    private var activeNotices: [AnnouncementItem] {
        let notices = announces.activeMarkdown(at: Date())
        guard sortByDeadline else { return notices }
        return notices.sorted {
            if $0.endTime != $1.endTime {
                return ($0.endTime ?? .distantFuture) < ($1.endTime ?? .distantFuture)
            }
            return $0.announceID > $1.announceID
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text("当前有效")
                            .foregroundStyle(.secondary)
                        Text("\(activeNotices.count) 条")
                            .fontWeight(.semibold)
                            .foregroundStyle(.red)
                            .contentTransition(.numericText())
                        Spacer()
                        Menu {
                            Picker("排列方式", selection: $sortByDeadline) {
                                Text("最近发布").tag(false)
                                Text("即将截止").tag(true)
                            }
                        } label: {
                            Label(sortByDeadline ? "即将截止" : "最近发布", systemImage: "arrow.up.arrow.down")
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityLabel("通知排序")
                        .accessibilityValue(sortByDeadline ? "即将截止" : "最近发布")
                    }
                    .font(.subheadline)

                    if activeNotices.isEmpty {
                        ContentUnavailableView(
                            "暂时没有重要通知",
                            systemImage: "checkmark.bubble",
                            description: Text("仍在有效期内的学校通知会显示在这里。")
                        )
                        .frame(maxWidth: .infinity)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(activeNotices) { notice in
                                ImportantNoticeCard(notice: notice)
                                    .jumpView(to: reader(for: notice.announceID))
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("重要通知")
            .navigationBarTitleDisplayMode(.large)
            .animation(reduceMotion ? nil : .snappy(duration: 0.24), value: sortByDeadline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .beButton { dismiss() }
                        .accessibilityLabel("关闭重要通知")
                }
            }
        }
        .tint(.red)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(30)
    }

    @ViewBuilder private func reader(for id: Int) -> some View {
        if let notice = activeNotices.first(where: { $0.announceID == id }) {
            ImportantNoticeReader(notice: notice)
        } else {
            ContentUnavailableView(
                "通知已失效", systemImage: "doc.badge.clock",
                description: Text("这条通知已结束或已被学校撤回。")
            )
        }
    }
}

private struct ImportantNoticeCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let notice: AnnouncementItem

    var body: some View {
        let content = ImportantNoticeContent(notice.content)
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("重要通知", systemImage: "doc.text.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(content.cardTitle)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if !content.excerpt.isEmpty {
                    Text(content.excerpt)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .lineSpacing(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    publishedDate
                    Spacer(minLength: 0)
                    ImportantNoticeDeadline(notice: notice)
                }
                VStack(alignment: .leading, spacing: 8) {
                    publishedDate
                    ImportantNoticeDeadline(notice: notice)
                }
            }
        }
        .padding(20)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(.red.opacity(.colorScheme(light: 0.65, dark: 0.85, colorScheme)))
                .frame(width: 3, height: 24)
                .padding(.top, 20)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityHint("打开通知全文")
    }

    @ViewBuilder private var publishedDate: some View {
        if let date = notice.createdAt ?? notice.startTime {
            Text("\(ImportantNoticeDate.short.string(from: date)) 发布")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ImportantNoticeDeadline: View {
    let notice: AnnouncementItem

    var body: some View {
        let isEndingSoon = notice.endTime.map { $0.timeIntervalSinceNow <= 86_400 } ?? false
        Label {
            if let end = notice.endTime {
                Text("\(ImportantNoticeDate.short.string(from: end)) 截止")
            } else {
                Text("长期有效")
            }
        } icon: {
            Image(systemName: isEndingSoon ? "clock.badge.exclamationmark" : "calendar")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(isEndingSoon ? Color.red : Color.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background((isEndingSoon ? Color.red : Color.secondary).opacity(0.09), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct ImportantNoticeReader: View {
    let notice: AnnouncementItem
    @ScaledMetric(relativeTo: .body) private var bodySize = 17

    var body: some View {
        let content = ImportantNoticeContent(notice.content)
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Label("学校通知", systemImage: "doc.text.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                    Text(content.heading ?? "重要通知")
                        .font(.largeTitle.bold())
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 10) {
                        if let date = notice.createdAt ?? notice.startTime {
                            LabeledContent("发布时间", value: ImportantNoticeDate.full.string(from: date))
                        }
                        if let start = notice.startTime {
                            LabeledContent("生效时间", value: ImportantNoticeDate.full.string(from: start))
                        }
                        LabeledContent("截止时间", value: notice.endTime.map(ImportantNoticeDate.full.string(from:)) ?? "长期有效")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 18))
                }

                Divider()

                Markdown(content.body)
                    .markdownTheme(readingTheme)
                    .tint(.red)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
        .background(Color(uiColor: .systemBackground))
        .navigationTitle("通知全文")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: notice.content) {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("分享通知")
            }
        }
    }

    private var readingTheme: Theme {
        Theme.gitHub
            .text {
                ForegroundColor(.primary)
                BackgroundColor(nil)
                FontSize(bodySize)
            }
            .link { ForegroundColor(.red) }
            .heading1 { configuration in
                configuration.label
                    .markdownTextStyle { FontSize(.em(1.5)); FontWeight(.bold) }
                    .markdownMargin(top: 24, bottom: 12)
            }
            .heading2 { configuration in
                configuration.label
                    .markdownTextStyle { FontSize(.em(1.25)); FontWeight(.bold) }
                    .markdownMargin(top: 20, bottom: 10)
            }
            .blockquote { configuration in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 2).fill(.red.opacity(0.65)).frame(width: 3)
                    configuration.label
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(14)
                .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                .markdownMargin(top: 8, bottom: 16)
            }
            .table { configuration in
                ScrollView(.horizontal) {
                    configuration.label
                        .markdownTableBorderStyle(.init(color: .secondary.opacity(0.2)))
                        .markdownTableBackgroundStyle(.alternatingRows(.clear, .secondary.opacity(0.05)))
                }
                .markdownMargin(top: 8, bottom: 16)
            }
    }
}

/// 从现有 Markdown 提取展示文字，不修改服务端正文或凭空添加标题字段。
private struct ImportantNoticeContent {
    let heading: String?
    let body: String
    let cardTitle: String
    let excerpt: String

    init(_ source: String) {
        let markdown = source.trimmingCharacters(in: .whitespacesAndNewlines)
        let lines = markdown.components(separatedBy: .newlines)
        let first = lines.first ?? ""
        if first.range(of: #"^#{1,6}\s+\S"#, options: .regularExpression) != nil {
            heading = MarkdownContent(first).renderPlainText().trimmingCharacters(in: .whitespacesAndNewlines)
            body = lines.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            heading = nil
            body = markdown
        }
        let plain = MarkdownContent(body).renderPlainText().trimmingCharacters(in: .whitespacesAndNewlines)
        // Plain-text legacy notices retain their full body in the reader.
        cardTitle = heading ?? String(plain.components(separatedBy: .newlines).first?.prefix(60) ?? "重要通知")
        let preview = heading == nil ? plain.components(separatedBy: .newlines).dropFirst().joined(separator: " ") : plain
        excerpt = String(preview.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).prefix(180))
    }
}

private enum ImportantNoticeDate {
    static let short = formatter("M月d日 HH:mm")
    static let full = formatter("yyyy年M月d日 HH:mm")

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = format
        return formatter
    }
}

#if DEBUG
private enum ImportantNoticePreview {
    static let notices: [AnnouncementItem] = [
        notice(1, "# 图书馆东侧入口临时关闭\n\n因连廊维护施工，东侧入口暂停通行，请从**南门**进入图书馆。\n\n## 通行安排\n\n- 阅览室与借还书服务照常开放\n- 请沿现场指引绕行，勿进入施工区域\n\n> 施工期间请预留额外的步行时间。", hours: 6),
        notice(2, "# 本学期课程考核安排\n\n请同学们核对考试时间与地点，携带学生证参加考试。\n\n| 科目 | 时间 | 地点 |\n| --- | --- | --- |\n| 高等数学 | 周一 09:00 | 教学楼 A201 |\n| 大学英语 | 周三 14:00 | 教学楼 B302 |", hours: 120),
        notice(3, "# 学生事务服务指南\n\n学籍证明、校园卡补办等业务可于工作日前往学生事务中心办理。", hours: nil)
    ]

    private static func notice(_ id: Int, _ content: String, hours: Double?) -> AnnouncementItem {
        AnnouncementItem(announceID: id, schoolID: 1, content: content, type: .importantMarkdown,
                         target: nil, startTime: .now.addingTimeInterval(-86_400),
                         endTime: hours.map { .now.addingTimeInterval($0 * 3_600) },
                         createdAt: .now.addingTimeInterval(Double(-id) * 3_600), updatedAt: nil)
    }
}

#Preview("重要通知 · 浅色") {
    MarkdownAnnouncementsSheet(announces: ImportantNoticePreview.notices).preferredColorScheme(.light)
}

#Preview("重要通知 · 深色") {
    MarkdownAnnouncementsSheet(announces: ImportantNoticePreview.notices).preferredColorScheme(.dark)
}

#Preview("重要通知 · 全文") {
    NavigationStack { ImportantNoticeReader(notice: ImportantNoticePreview.notices[0]) }
}

#Preview("重要通知 · 空状态") {
    MarkdownAnnouncementsSheet(announces: [])
}
#endif
