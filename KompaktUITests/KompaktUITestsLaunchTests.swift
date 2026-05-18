//
//  KompaktUITestsLaunchTests.swift
//  KompaktUITests
//
//  Created by edin on 16/05/2026.
//

import XCTest

final class KompaktUITestsLaunchTests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchEnvironment["KOMPAKT_DISABLE_EXTERNAL_DRAG_MONITOR"] = "1"
        app.launchEnvironment["KOMPAKT_DISABLE_FIRST_LAUNCH_ONBOARDING"] = "1"
        app.launch()

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
