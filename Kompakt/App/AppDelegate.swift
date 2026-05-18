import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var externalDropZoneController: ExternalDropZoneController?
    private var externalDragMonitor: ExternalDragMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let controller = MenuBarController(appModel: AppModel.shared)
        menuBarController = controller
        AppModel.shared.attachMenuBarController(controller)

        let dropZoneController = ExternalDropZoneController(appModel: AppModel.shared)
        externalDropZoneController = dropZoneController
        AppModel.shared.attachExternalDropZoneController(dropZoneController)

        if ProcessInfo.processInfo.environment["KOMPAKT_DISABLE_EXTERNAL_DRAG_MONITOR"] != "1" {
            let dragMonitor = ExternalDragMonitor(appModel: AppModel.shared, dropZoneController: dropZoneController)
            externalDragMonitor = dragMonitor
            dragMonitor.start()
        }

    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        false
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        Task { @MainActor in
            AppModel.shared.handleDropped(paths: filenames)
            sender.reply(toOpenOrPrint: .success)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            AppModel.shared.handleDropped(urls: urls)
        }
    }
}
