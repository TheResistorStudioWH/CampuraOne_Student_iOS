//
//  ICSSchoolCalendar.swift
//  CampuraOne
//
//  Created by Lin Shay on 11/06/2026.
//

import SwiftUI
import SwiftData

#Preview("app - 已登录") {
    ContentView()
        .modelContainer(PreviewContainer.app)
}

struct ICSSchoolCalendar: View {
    @StateObject private var viewModel = LoadableListViewModel<RemoteSchoolCalendarEvent>(loader: {
        try await RemoteSchoolCalendarService.shared.fetchSchoolCalendar(schoolID: 1)
    })
    
    @StateObject private var schoolNameViewModel = LoadableListViewModel<String>(loader: {
        try await RemoteSchoolCalendarService.shared.fetchSchoolName(schoolID: 1)
    })
    
    private let calendar = Calendar.current
    
    private var events: [RemoteSchoolCalendarEvent] {
        viewModel.items
    }
    
    private var schoolName: String {
        schoolNameViewModel.items.first ?? "你的学校"
    }
    
    private var groupedEvents: [(month: Date, events: [RemoteSchoolCalendarEvent])] {
        let grouped = Dictionary(grouping: events.sortedByStartTime) { event in
            calendar.startOfMonth(for: event.startTime)
        }
        
        return grouped
            .map { ($0.key, $0.value.sortedByStartTime) }
            .sorted { $0.month < $1.month }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(errorMessage)
                } else if events.isEmpty {
                    emptyView
                } else {
                    fullCalendarContent
                }
            }
            .padding()
        }
        .task {
            async let loadCalendar: Void = viewModel.load()
            async let loadSchoolName: Void = schoolNameViewModel.load()
            _ = await (loadCalendar, loadSchoolName)
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(schoolName)
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            
            Text("查看本学期重要安排")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
    
    private var fullCalendarContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            todayCard
            
            ForEach(groupedEvents, id: \.month) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Text(monthTitle(group.month))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    
                    VStack(spacing: 10) {
                        ForEach(group.events) { event in
                            FullCalendarEventRow(event: event)
                        }
                    }
                }
            }
        }
    }
    
    private var todayCard: some View {
        let todayEvents = events.events(on: Date())
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sun.max.fill")
                    .foregroundStyle(.tint)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.headline)
                    Text(dayTitle(Date()))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            if todayEvents.isEmpty {
                Text("今天暂无校历事项")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(todayEvents.prefix(3)) { event in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(.tint)
                            .frame(width: 6, height: 6)
                        Text(event.title)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.tint.opacity(0.12))
        }
    }
    
    private var emptyView: some View {
        ContentUnavailableView(
            "暂无校历",
            systemImage: "calendar",
            description: Text("服务器暂时没有返回校历数据")
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            Text("校历加载失败：\(message)")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: date)
    }
    
    private func dayTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEEE"
        return formatter.string(from: date)
    }
}

struct ICSSchoolCalendarMini: View {
    @StateObject private var viewModel = LoadableListViewModel<RemoteSchoolCalendarEvent>(loader: {
        try await RemoteSchoolCalendarService.shared.fetchSchoolCalendar(schoolID: 1)
    })

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    
    private let calendar = Calendar.current
    
    private var events: [RemoteSchoolCalendarEvent] {
        viewModel.items
    }
    
    private var weekDays: [Date] {
        let today = calendar.startOfDay(for: Date())
        return (0..<8).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: today)
        }
    }

    private var selectedDateEvents: [RemoteSchoolCalendarEvent] {
        events.events(on: selectedDate)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.errorMessage != nil {
                miniErrorView
            } else {
                weekStrip
                Divider().opacity(0.35)
                weekEventList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task {
            await viewModel.load()
        }
    }
    
    private var weekStrip: some View {
        VStack(spacing: 2) {
            ForEach(0..<2, id: \.self) { rowIndex in
                HStack(spacing: 2) {
                    ForEach(rowDays(rowIndex), id: \.self) { day in
                        miniDayCell(day)
                            .beButton {
                                withAnimation(.snappy) {
                                    selectedDate = calendar.startOfDay(for: day)
                                }
                            }
                    }
                }
            }
        }
    }

    private func rowDays(_ rowIndex: Int) -> [Date] {
        let startIndex = rowIndex * 4
        let endIndex = min(startIndex + 4, weekDays.count)
        return Array(weekDays[startIndex..<endIndex])
    }

    private func miniDayCell(_ day: Date) -> some View {
        let dayEvents = events.events(on: day)
        let isToday = calendar.isDateInToday(day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        
        return VStack(spacing: 2) {
            Text(dayNumber(day))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(width: 20, height: 20)
                .background {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.12))
                }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(weekdaySymbol(day))
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                
                Circle()
                    .fill(dayEvents.isEmpty ? Color.clear : Color.accentColor)
                    .frame(width: 4, height: 4)
                    .shadow(radius: 5)
            }
            
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(isToday && !isSelected ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
        }
    }
    
    private var weekEventList: some View {
        VStack(alignment: .leading, spacing: 6) {
            if selectedDateEvents.isEmpty {
                Text(emptySelectedDateTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ForEach(selectedDateEvents.prefix(3)) { event in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(event.occurs(on: selectedDate) ? Color.accentColor : Color.secondary.opacity(0.35))
                            .frame(width: 4, height: 20)
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text(event.title)
                                .font(.caption)
                                .fontWeight(event.occurs(on: selectedDate) ? .bold : .semibold)
                                .lineLimit(1)
                            
                            Text(miniDateTitle(event))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                if selectedDateEvents.count > 3 {
                    Text("还有 \(selectedDateEvents.count - 3) 项")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private var miniErrorView: some View {
        VStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("校历加载失败")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func weekdaySymbol(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
    
    private func dayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var emptySelectedDateTitle: String {
        if calendar.isDateInToday(selectedDate) {
            return "今天暂无校历事项"
        }
        
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        if calendar.isDate(selectedDate, inSameDayAs: tomorrow) {
            return "明天暂无校历事项"
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日暂无事项"
        return formatter.string(from: selectedDate)
    }

    private func miniDateTitle(_ event: RemoteSchoolCalendarEvent) -> String {
        if event.occurs(on: selectedDate), calendar.isDateInToday(selectedDate) {
            return "今天"
        }
        
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        if event.occurs(on: selectedDate), calendar.isDate(selectedDate, inSameDayAs: tomorrow) {
            return "明天"
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日"
        return formatter.string(from: event.startTime)
    }
}

private struct FullCalendarEventRow: View {
    let event: RemoteSchoolCalendarEvent
    private let calendar = Calendar.current
    
    private var isToday: Bool {
        event.occurs(on: Date())
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 2) {
                Text(dayNumber(event.startTime))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(isToday ? .white : .primary)
                Text(monthShort(event.startTime))
                    .font(.caption2)
                    .foregroundStyle(isToday ? .white.opacity(0.85) : .secondary)
            }
            .frame(width: 52, height: 52)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isToday ? Color.accentColor : Color.secondary.opacity(0.12))
            }
            
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(event.title)
                        .font(.headline)
                        .lineLimit(2)
                    
                    if isToday {
                        Text("TODAY")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.tint, in: Capsule())
                    }
                }
                
                Text(dateRangeTitle(event))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if let content = event.content, !content.isEmpty {
                    Text(content)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(isToday ? Color.accentColor.opacity(0.10) : Color.secondary.opacity(0.08))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(isToday ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
        }
    }
    
    private func dayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func monthShort(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月"
        return formatter.string(from: date)
    }
    
    private func dateRangeTitle(_ event: RemoteSchoolCalendarEvent) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy年M月d日"
        
        if event.isAllDay,
           let endTime = event.endTime,
           !calendar.isDate(event.startTime, inSameDayAs: endTime) {
            let displayEnd = calendar.date(byAdding: .day, value: -1, to: endTime) ?? endTime
            if calendar.isDate(event.startTime, inSameDayAs: displayEnd) {
                return formatter.string(from: event.startTime)
            }
            return "\(formatter.string(from: event.startTime)) - \(formatter.string(from: displayEnd))"
        }
        
        guard let endTime = event.endTime else {
            return formatter.string(from: event.startTime)
        }
        
        if calendar.isDate(event.startTime, inSameDayAs: endTime) {
            return formatter.string(from: event.startTime)
        }
        
        return "\(formatter.string(from: event.startTime)) - \(formatter.string(from: endTime))"
    }
}

private struct RemoteSchoolCalendarDocument: Decodable {
    let schoolID: Int
    let content: String
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case schoolID
        case content
        case updatedAt
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schoolID = try container.decodeFlexibleIntIfPresent(forKey: .schoolID) ?? 0
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
        updatedAt = try container.decodeFlexibleDateIfPresent(forKey: .updatedAt)
    }
}

private struct RemoteSchoolCalendarEvent: Identifiable, Codable {
    let uid: String
    let title: String
    let content: String?
    let startTime: Date
    let endTime: Date?
    let isAllDay: Bool
    
    var id: String { uid }
    
    init(
        uid: String,
        title: String,
        content: String? = nil,
        startTime: Date,
        endTime: Date? = nil,
        isAllDay: Bool = true
    ) {
        self.uid = uid
        self.title = title
        self.content = content
        self.startTime = startTime
        self.endTime = endTime
        self.isAllDay = isAllDay
    }
    
    func occurs(on date: Date) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let defaultEnd = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: startTime)) ?? startTime
        let eventEnd = endTime ?? defaultEnd
        
        return startTime < dayEnd && eventEnd > dayStart
    }
}

private final class RemoteSchoolCalendarService {
    static let shared = RemoteSchoolCalendarService()
    
    private init() {}
    
    func fetchSchoolName(schoolID: Int) async throws -> [String] {
        let school = try await RemoteDataService.shared.fetchSchool(schoolID: schoolID)
        return [school.schoolName]
    }
    
    func fetchSchoolCalendar(schoolID: Int) async throws -> [RemoteSchoolCalendarEvent] {
        var components = URLComponents(string: APIConfig.api_download(APIConfig.DLPath.schoolCalendar))
        components?.queryItems = [
            URLQueryItem(name: "schoolID", value: "\(schoolID)")
        ]
        
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(RemoteSchoolCalendarAPIResponse<RemoteSchoolCalendarDocument>.self, from: data)
        
        guard apiResponse.code == 200 else {
            throw NSError(
                domain: "RemoteSchoolCalendarService",
                code: apiResponse.code,
                userInfo: [NSLocalizedDescriptionKey: apiResponse.message]
            )
        }
        
        guard let document = apiResponse.data else {
            return []
        }
        
        return SchoolCalendarICSParser.parse(document.content)
    }
}

private enum SchoolCalendarICSParser {
    static func parse(_ content: String) -> [RemoteSchoolCalendarEvent] {
        let lines = unfoldedLines(content)
        var events: [RemoteSchoolCalendarEvent] = []
        var currentEvent: [String: String]?
        
        for line in lines {
            if line == "BEGIN:VEVENT" {
                currentEvent = [:]
                continue
            }
            
            if line == "END:VEVENT" {
                if let currentEvent,
                   let event = makeEvent(from: currentEvent) {
                    events.append(event)
                }
                currentEvent = nil
                continue
            }
            
            guard currentEvent != nil else {
                continue
            }
            
            let parsedLine = parseLine(line)
            currentEvent?[parsedLine.key] = parsedLine.value
        }
        
        return events.sortedByStartTime
    }
    
    private static func unfoldedLines(_ content: String) -> [String] {
        let rawLines = content
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
        
        var lines: [String] = []
        
        for rawLine in rawLines {
            guard !rawLine.isEmpty else { continue }
            
            if rawLine.hasPrefix(" ") || rawLine.hasPrefix("\t") {
                if let last = lines.indices.last {
                    lines[last] += String(rawLine.dropFirst())
                }
            } else {
                lines.append(rawLine)
            }
        }
        
        return lines
    }
    
    private static func parseLine(_ line: String) -> (key: String, value: String) {
        guard let colonIndex = line.firstIndex(of: ":") else {
            return (line, "")
        }
        
        let keyPart = String(line[..<colonIndex])
        let value = String(line[line.index(after: colonIndex)...])
        let key = keyPart.components(separatedBy: ";").first ?? keyPart
        
        return (key, unescaped(value))
    }
    
    private static func makeEvent(from dictionary: [String: String]) -> RemoteSchoolCalendarEvent? {
        guard let startRaw = dictionary["DTSTART"],
              let startTime = parseICSDate(startRaw) else {
            return nil
        }
        
        let endTime = dictionary["DTEND"].flatMap { parseICSDate($0) }
        let uid = dictionary["UID"] ?? UUID().uuidString
        let title = dictionary["SUMMARY"] ?? "校历事项"
        let content = dictionary["DESCRIPTION"]
        
        return RemoteSchoolCalendarEvent(
            uid: uid,
            title: title,
            content: content,
            startTime: startTime,
            endTime: endTime,
            isAllDay: startRaw.count == 8
        )
    }
    
    private static func parseICSDate(_ rawValue: String) -> Date? {
        if rawValue.count == 8 {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = Calendar.current.timeZone
            formatter.dateFormat = "yyyyMMdd"
            return formatter.date(from: rawValue)
        }
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = rawValue.hasSuffix("Z") ? "yyyyMMdd'T'HHmmss'Z'" : "yyyyMMdd'T'HHmmss"
        return formatter.date(from: rawValue)
    }
    
    private static func unescaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\,", with: ",")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}

private struct RemoteSchoolCalendarAPIResponse<T: Decodable>: Decodable {
    let code: Int
    let message: String
    let data: T?
}

private extension Array where Element == RemoteSchoolCalendarEvent {
    var sortedByStartTime: [RemoteSchoolCalendarEvent] {
        sorted { $0.startTime < $1.startTime }
    }
    
    func events(on date: Date) -> [RemoteSchoolCalendarEvent] {
        filter { event in
            event.occurs(on: date)
        }
        .sortedByStartTime
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? startOfDay(for: date)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleIntIfPresent(forKey key: Key) throws -> Int? {
        if let intValue = try decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }
        
        if let stringValue = try decodeIfPresent(String.self, forKey: key) {
            return Int(stringValue)
        }
        
        return nil
    }
    
    func decodeFlexibleDateIfPresent(forKey key: Key) throws -> Date? {
        if let timestamp = try? decodeIfPresent(Double.self, forKey: key) {
            return Date(timeIntervalSince1970: timestamp)
        }

        if let timestamp = try? decodeIfPresent(Int.self, forKey: key) {
            return Date(timeIntervalSince1970: TimeInterval(timestamp))
        }
        
        guard let string = try? decodeIfPresent(String.self, forKey: key),
              !string.isEmpty else {
            return nil
        }
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: string) {
            return date
        }
        
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: string) {
            return date
        }
        
        let formatters = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd"
        ].map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            return formatter
        }
        
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return date
            }
        }
        
        return nil
    }
}
