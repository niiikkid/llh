//
//  llhUITests.swift
//  llhUITests
//

import XCTest

final class llhUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchShowsMainChrome() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Помощник по изучению языков"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsRouteOpensAndReturns() throws {
        let app = XCUIApplication()
        app.launch()

        let settingsButton = app.buttons["Настройки"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        XCTAssertTrue(app.staticTexts["Настройки"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Общие"].exists)

        let backButton = app.buttons["Назад"]
        XCTAssertTrue(backButton.waitForExistence(timeout: 5))
        backButton.click()

        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
    }
}
