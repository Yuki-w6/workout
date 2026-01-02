import XCTest

final class ExerciseUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testExerciseGetListShowsSeedExercises() throws {
        let app = launchApp()

        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Bench Press"].exists)
        XCTAssertTrue(app.staticTexts["Deadlift"].exists)
        XCTAssertTrue(app.staticTexts["Squat"].exists)
    }

    @MainActor
    func testExerciseGetShowsDetail() throws {
        let app = launchApp()

        app.staticTexts["Bench Press"].tap()
        XCTAssertTrue(app.navigationBars["Exercise"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["ExerciseName"].label, "Bench Press")
    }

    @MainActor
    func testExerciseAddCreatesNewExercise() throws {
        let app = launchApp()

        app.navigationBars["Home"].buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["New Exercise"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testExerciseEditUpdatesName() throws {
        let app = launchApp()

        app.staticTexts["Bench Press"].tap()
        app.navigationBars["Exercise"].buttons["Edit"].tap()

        let nameField = app.textFields["Exercise Name"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        nameField.clearAndEnterText("Bench Press Updated")
        app.navigationBars["Edit Exercise"].buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Bench Press Updated"].waitForExistence(timeout: 2))
        app.navigationBars["Exercise"].buttons["Home"].tap()
        XCTAssertTrue(app.staticTexts["Bench Press Updated"].exists)
    }

    @MainActor
    func testExerciseDeleteRemovesExercise() throws {
        let app = launchApp()

        let target = app.staticTexts["Deadlift"]
        XCTAssertTrue(target.waitForExistence(timeout: 2))
        target.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        XCTAssertFalse(app.staticTexts["Deadlift"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
            measure(metrics: [XCTApplicationLaunchMetric()]) {
                XCUIApplication().launch()
            }
        }
    }

    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launch()
        return app
    }
}

private extension XCUIElement {
    func clearAndEnterText(_ text: String) {
        tap()
        let currentValue = value as? String ?? ""
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
        typeText(deleteString)
        typeText(text)
    }
}
