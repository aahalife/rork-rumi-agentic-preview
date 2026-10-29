import XCTest

final class RumiInsightsUITests: XCTestCase {
    @MainActor
    func reveal(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 14) {
        for _ in 0..<maxSwipes {
            if element.exists && element.isHittable { return }
            app.swipeUp()
        }
    }
    @MainActor
    func testPrimaryWalkthroughShowsCalculatedChartWithoutNetwork() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        let entry = app.buttons["Explore a demo"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10)); entry.tap()
        XCTAssertTrue(app.buttons["demo.member.primary"].waitForExistence(timeout: 10))
        let start = app.buttons["demo.start"]; reveal(start, in: app)
        XCTAssertTrue(start.isHittable); start.tap()
        let walkthrough = app.buttons["demo.insights.walkthrough"]
        XCTAssertTrue(walkthrough.waitForExistence(timeout: 10)); reveal(walkthrough, in: app); walkthrough.tap()
        let a1c = app.descendants(matching: .any).matching(identifier: "demo.insight.focused").firstMatch
        reveal(a1c, in: app)
        XCTAssertTrue(a1c.exists, "Calculated focus value missing. UI: \(app.debugDescription.suffix(16000))")
        XCTAssertTrue(a1c.label.replacingOccurrences(of: ",", with: ".").contains("8.8"), "Primary latest value must be 8.8 in the device locale, got \(a1c.label)")
        let values = app.descendants(matching: .any).matching(identifier: "demo.insight.values").firstMatch
        reveal(values, in: app); XCTAssertTrue(values.isHittable, "Accessible values disclosure missing. UI: \(app.debugDescription.suffix(16000))"); values.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "9 %")).firstMatch.exists, "Expanded dates/values must include earlier A1c 9%. UI: \(app.debugDescription.suffix(16000))")
    }
    @MainActor
    func testCareRehearsalRequiresExactReviewAndCancelDoesNotSave() throws {
        continueAfterFailure = false
        let app = XCUIApplication(); app.launch()
        app.buttons["Explore a demo"].tap()
        let start = app.buttons["demo.start"]; XCTAssertTrue(start.waitForExistence(timeout: 10)); reveal(start, in: app); start.tap()
        let walkthrough = app.buttons["demo.insights.walkthrough"]; XCTAssertTrue(walkthrough.waitForExistence(timeout: 10)); reveal(walkthrough, in: app); walkthrough.tap()
        let followups = app.buttons["demo.care.followups"]; reveal(followups, in: app); XCTAssertTrue(followups.isHittable); followups.tap()
        let prepare = app.buttons["Prepare a question"]; XCTAssertTrue(prepare.waitForExistence(timeout: 10)); prepare.tap()
        XCTAssertTrue(app.staticTexts["Would you like to prepare a refill question for your prescriber?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Confirm local rehearsal · Not sent"].exists)
        app.buttons["Cancel"].tap()
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Care rehearsal · Refill reminder")).firstMatch.exists)
    }
}
