import XCTest

final class HistoryUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testHistoryTabShowsRecords() throws {
        let app = XCUIApplication()
        app.launch()

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Today"].exists)
        XCTAssertTrue(app.staticTexts["Yesterday"].exists)
        XCTAssertTrue(app.staticTexts["Last Week"].exists)
    }
}
