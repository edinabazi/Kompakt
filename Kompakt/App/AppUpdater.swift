import AppKit
import Sparkle

@MainActor
final class AppUpdater {
    static let shared = AppUpdater()

    private let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    private init() {}

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
