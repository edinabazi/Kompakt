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
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launchEnvironment["KOMPAKT_DISABLE_EXTERNAL_DRAG_MONITOR"] = "1"
        app.launch()
        terminateKompaktAfterTest()

        XCTAssertTrue(app.isRunning)
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
