import XCTest

final class WatchCalendarUITests: XCTestCase {
    @MainActor func testRootNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let courses = app.buttons["calendar.open.courses"].firstMatch
        XCTAssertTrue(courses.waitForExistence(timeout: 10))
        snapshot("首页")
        courses.tap()
        XCTAssertTrue(app.buttons["calendar.options"].firstMatch.waitForExistence(timeout: 10))
        app.terminate()
    }

    @MainActor func testCoursesAndSchoolCalendarNavigation() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--watch-calendar", "courses", "--watch-view", "week"]
        app.launch()
        let options = app.buttons["calendar.options"].firstMatch
        XCTAssertTrue(options.waitForExistence(timeout: 25))
        snapshot("课程周总览")
        options.tap()
        selectMode("month", in: app)
        snapshot("课表月视图")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = app.buttons["calendar.date.\(formatter.string(from: Date()))"].firstMatch
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        today.tap()
        snapshot("逐日课表")
        options.tap()
        selectMode("list", in: app)
        let entry = try visibleEvent(in: app)
        entry.tap()
        snapshot("课程详情")
        app.terminate()

        app.launchArguments = ["--watch-calendar", "school", "--watch-view", "month"]
        app.launch()
        XCTAssertTrue(options.waitForExistence(timeout: 25))
        XCTAssertTrue(today.waitForExistence(timeout: 25))
        snapshot("校历月视图")
        today.tap()
        snapshot("校历日视图")
        options.tap()
        selectMode("list", in: app)
        let schoolEntry = try visibleEvent(in: app)
        schoolEntry.tap()
        snapshot("校历事项详情")
        app.terminate()
    }

    @MainActor private func selectMode(_ mode: String, in app: XCUIApplication) {
        let button = app.buttons["calendar.mode.\(mode)"].firstMatch
        for _ in 0..<5 {
            if button.exists && button.isHittable { break }
            app.collectionViews.element(boundBy: app.collectionViews.count - 1).swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }

    @MainActor private func visibleEvent(in app: XCUIApplication) throws -> XCUIElement {
        let query = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "calendar.event."))
        XCTAssertTrue(query.firstMatch.waitForExistence(timeout: 25))
        return try XCTUnwrap(query.allElementsBoundByIndex.first(where: \.isHittable))
    }

    @MainActor private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
