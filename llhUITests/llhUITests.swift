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

        XCTAssertTrue(app.staticTexts["Language Learning Helper"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testSettingsSheetOpensAndCloses() throws {
        let app = XCUIApplication()
        app.launch()

        let settingsButton = app.buttons["Настройки"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.click()

        let closeButton = app.buttons["Закрыть"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Общие"].exists)

        closeButton.click()
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
    }
}
