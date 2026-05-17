//
//  KompaktUITests.swift
//  KompaktUITests
//
//  Created by edin on 16/05/2026.
//

import AppKit
import XCTest

final class KompaktUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDocklessAppLaunches() throws {
        let app = XCUIApplication()
        app.launchEnvironment["KOMPAKT_DISABLE_EXTERNAL_DRAG_MONITOR"] = "1"
        app.launch()
        terminateKompaktAfterTest()

        XCTAssertTrue(app.isRunning)
    }

    private func terminateKompaktAfterTest() {
        addTeardownBlock {
            NSRunningApplication
                .runningApplications(withBundleIdentifier: "com.edinabazi.Kompakt")
                .forEach { $0.forceTerminate() }
        }
    }
}

private extension XCUIApplication {
    var isRunning: Bool {
        state == .runningForeground || state == .runningBackground
    }
}
