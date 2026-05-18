import AppKit
import SwiftUI

@MainActor
enum AppCommands {
    static func kompaktFiles(appModel: AppModel) {
        openPanel(canChooseFiles: true, canChooseDirectories: false, appModel: appModel)
    }

    static func kompaktFolder(appModel: AppModel) {
        openPanel(canChooseFiles: false, canChooseDirectories: true, appModel: appModel)
    }

    static func checkForUpdates() {
        AppUpdater.shared.checkForUpdates()
    }

    static func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    static func quit() {
        NSApp.terminate(nil)
    }

    private static func openPanel(canChooseFiles: Bool, canChooseDirectories: Bool, appModel: AppModel) {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = canChooseFiles
        panel.canChooseDirectories = canChooseDirectories
        panel.level = .floating
        panel.begin { response in
            guard response == .OK else { return }
            Task { @MainActor in
                appModel.handleDropped(urls: panel.urls)
            }
        }
    }
}
