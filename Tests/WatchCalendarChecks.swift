import Foundation

private let courseICS = """
BEGIN:VCALENDAR
VERSION:2.0
BEGIN:VEVENT
UID:course-one
SUMMARY:程序设计
DTSTART:20261026T000000Z
DTEND:20261026T014000Z
RRULE:FREQ=WEEKLY;BYDAY=MO;UNTIL=20261130T235959Z
LOCATION:A101
END:VEVENT
END:VCALENDAR
"""

private actor WatchFixtureServer {
    enum Behavior { case success, expired, alwaysUnauthorized, badPassword, unavailable, invalidCalendar }
    let behavior: Behavior
    private(set) var loginCount = 0
    private(set) var downloadCount = 0
    init(_ behavior: Behavior = .success) { self.behavior = behavior }

    func respond(_ request: WatchHTTPRequest) async throws -> WatchHTTPResponse {
        func reply(_ code: Int = 200, _ data: Any) throws -> WatchHTTPResponse {
            WatchHTTPResponse(statusCode: code, data: try JSONSerialization.data(withJSONObject: ["code": code, "data": data]))
        }
        if request.path.hasSuffix("login.php") {
            loginCount += 1
            let number = loginCount
            precondition(request.method == .post)
            precondition(request.parameters["userName"] == WatchAccount.userName)
            precondition(request.parameters["password"] == WatchAccount.password)
            try await Task.sleep(for: .milliseconds(20))
            if behavior == .badPassword { return try reply(401, NSNull()) }
            return try reply(200, ["token": "header.token\(number).signature", "user": ["userID": 9, "studentID": 17]])
        }
        if request.path.hasSuffix("student_profile.php") {
            precondition(request.token != nil)
            return try reply(200, ["studentID": 17, "schoolID": 3, "compoundID": 4, "departmentID": 5, "classID": 6])
        }
        downloadCount += 1
        precondition(request.parameters["schoolID"] == "3", "Use the authenticated student's school")
        if request.path.hasSuffix("course_table.php") {
            precondition(request.parameters["classID"] == "6" && request.parameters["compoundID"] == "4")
        }
        if behavior == .alwaysUnauthorized || (behavior == .expired && request.token == "header.token1.signature") {
            return try reply(401, NSNull())
        }
        if behavior == .unavailable { return try reply(500, NSNull()) }
        return try reply(200, ["content": behavior == .invalidCalendar ? "<html>invalid</html>" : courseICS])
    }
}

@main struct WatchCalendarChecks {
    @MainActor static func main() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        func day(_ year: Int = 2026, _ month: Int = 10, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day))!
        }
        let scope = WatchStudentScope(studentID: 17, schoolID: 3, compoundID: 4, departmentID: 5, classID: 6)
        let document = WatchCalendarDocument(account: WatchAccount.userName, userID: 9, scope: scope, kind: .courses, content: courseICS, fetchedAt: Date())
        let entries = WatchCalendarData.parse(document)
        let displayEntry = WatchCalendarEntry(course: ICSEventItem(id: "display", title: "【演示】程序设计", startDate: day(2026, 10, 28), endDate: day(2026, 10, 28).addingTimeInterval(3600), location: nil, detail: "[Demo]备注"))!
        precondition(displayEntry.title == "程序设计" && displayEntry.notes == "备注")
        let placeholderNote = WatchCalendarEntry(course: ICSEventItem(id: "note", title: "程序设计", startDate: day(2026, 10, 28), endDate: day(2026, 10, 28).addingTimeInterval(3600), location: nil, detail: "虚构示例课表，仅供 Campura One 项目演示；不代表真实课程或节假日调课。"))!
        precondition(placeholderNote.notes == nil)
        let monday = WatchCalendarData.events(on: day(2026, 11, 2), kind: .courses, entries: entries, calendar: calendar)
        precondition(monday.count == 1 && calendar.component(.hour, from: monday[0].start) == 8)
        precondition(WatchCalendarData.events(on: day(2026, 11, 3), kind: .courses, entries: entries, calendar: calendar).isEmpty)
        precondition(WatchCalendarData.events(on: day(2026, 12, 7), kind: .courses, entries: entries, calendar: calendar).isEmpty)
        let week = WatchCalendarData.week(containing: day(2026, 11, 1), calendar: calendar)
        precondition(week.count == 7 && week.first == day(2026, 10, 26) && week.last == day(2026, 11, 1))
        let february = WatchCalendarData.monthDays(containing: day(2028, 2, 12), calendar: calendar)
        precondition(february.compactMap { $0 }.count == 29 && february.count % 7 == 0)
        precondition(WatchCalendarData.monthDays(containing: day(2026, 11, 12), calendar: calendar).prefix(6).allSatisfy { $0 == nil })
        let holiday = WatchCalendarEntry(calendarEvent: RemoteSchoolCalendarEvent(uid: "holiday", title: "假期", startTime: day(2026, 10, 30), endTime: day(2026, 11, 3)))
        precondition(holiday.occurs(on: day(2026, 11, 2), calendar: calendar))
        precondition(!holiday.occurs(on: day(2026, 11, 3), calendar: calendar), "ICS DTEND is exclusive")
        precondition(WatchCalendarData.events(on: day(2026, 10, 31), kind: .school, entries: [holiday], calendar: calendar).count == 1)
        let agenda = WatchCalendarData.agenda(kind: .school, entries: [holiday], around: day(2026, 11, 1), calendar: calendar)
        precondition(agenda.count == 1, "Multi-day events are listed once in the agenda")
        try WatchCalendarData.validateICS("")
        try WatchCalendarData.validateICS("BEGIN:VCALENDAR\nEND:VCALENDAR")
        do { try WatchCalendarData.validateICS("not a calendar"); preconditionFailure() } catch { }

        let parserEvents = SchoolCalendarICSParser.parse("""
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        UID:all-day
        SUMMARY:学期安排
        DESCRIPTION:第一行\\n第二行
         续行
        DTSTART;VALUE=DATE:20261030
        DTEND;VALUE=DATE:20261103
        END:VEVENT
        END:VCALENDAR
        """)
        precondition(parserEvents.count == 1 && parserEvents[0].isAllDay)
        precondition(parserEvents[0].content == "第一行\n第二行续行")

        for behavior in [WatchFixtureServer.Behavior.success, .expired] {
            print("Checking authentication scenario: \(behavior)")
            let server = WatchFixtureServer(behavior)
            let api = WatchAPI(transport: { try await server.respond($0) })
            async let courses = api.fetch(.courses)
            async let school = api.fetch(.school)
            let documents = try await [courses, school]
            precondition(documents.count == 2 && documents.allSatisfy { $0.scope.schoolID == 3 })
            let count = await server.loginCount
            precondition(count == (behavior == .expired ? 2 : 1), "Authentication must coalesce across calendars")
        }
        for behavior in [WatchFixtureServer.Behavior.alwaysUnauthorized, .badPassword, .unavailable, .invalidCalendar] {
            print("Checking authentication scenario: \(behavior)")
            let server = WatchFixtureServer(behavior)
            let api = WatchAPI(transport: { try await server.respond($0) })
            do { _ = try await api.fetch(.courses); preconditionFailure("Bad responses must not become empty calendars") }
            catch { }
            let count = await server.loginCount
            precondition(count == (behavior == .alwaysUnauthorized ? 2 : 1), "Retries must be bounded")
        }
        // Exercise waiter ordering: a completed initial login can resume after
        // another calendar has already invalidated it and begun renewing.
        for _ in 0..<30 {
            let server = WatchFixtureServer(.expired)
            let api = WatchAPI(transport: { try await server.respond($0) })
            async let first = api.fetch(.courses)
            async let second = api.fetch(.school)
            _ = try await (first, second)
            let count = await server.loginCount
            precondition(count == 2)
        }

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = WatchDocumentCache(directory: directory)
        try await cache.save(document)
        let saved = await cache.load(.courses)
        precondition(saved?.content == courseICS && saved?.scope == scope)
        let missing = await cache.load(.school)
        precondition(missing == nil)
        let invalid = WatchCalendarDocument(account: "another-account", userID: 2, scope: scope, kind: .courses, content: courseICS, fetchedAt: Date())
        try await cache.save(invalid)
        let rejected = await cache.load(.courses)
        precondition(rejected == nil, "A cache cannot cross accounts")
        try await cache.save(document)
        let failing = WatchFixtureServer(.unavailable)
        let store = WatchScheduleStore(api: WatchAPI(transport: { try await failing.respond($0) }), cache: cache)
        await store.start()
        precondition(store.courses.items.count == 1 && store.courses.errorMessage != nil)
        precondition(store.updatedAt[.courses] != nil && !store.courses.isLoading)
        let list = LoadableListViewModel<Int> { throw CancellationError() }
        list.items = [7]
        await list.load()
        precondition(list.items == [7] && list.errorMessage == nil && !list.isLoading)
        print("PASS: calendar dates, recurrence, month/week overview, exclusive end dates, authentication coalescing/retry, cache and offline recovery")
    }
}
