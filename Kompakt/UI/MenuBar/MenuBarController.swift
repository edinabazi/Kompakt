import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let appModel: AppModel
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var cancellables: Set<AnyCancellable> = []

    init(appModel: AppModel) {
        self.appModel = appModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        super.init()

        configureStatusItem()
        bindState()
    }

    func updateStatusIcon(isProcessing: Bool) {
        guard let button = statusItem.button else { return }

        let image = NSImage(named: "MenuBarIcon")
        image?.isTemplate = true
        image?.size = NSSize(width: 18, height: 18)
        button.image = image
        button.contentTintColor = isProcessing ? NSColor.systemMint : nil
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuildMenu()
    }

    private func configureStatusItem() {
        statusItem.menu = menu
        menu.delegate = self
        rebuildMenu()

        guard let button = statusItem.button else { return }
        button.toolTip = "Kompakt"
        updateStatusIcon(isProcessing: appModel.isProcessing)
    }

    private func bindState() {
        appModel.$isProcessing
            .removeDuplicates()
            .sink { [weak self] isProcessing in
                self?.updateStatusIcon(isProcessing: isProcessing)
            }
            .store(in: &cancellables)
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        menu.addItem(disabledTitle: appModel.lastMessage)
        menu.addItem(.separator())

        if let summary = appModel.pendingAskSummary {
            menu.addItem(disabledTitle: "Compress \(summary.count) \(summary.noun)")

            if summary.kind == .video {
                addAction("Same Size", action: #selector(chooseSameResolution))
                addAction("1080p", action: #selector(choose1080p))
                addAction("720p", action: #selector(choose720p))
            } else {
                addAction("Lossless", action: #selector(chooseLossless))
                addAction("Smaller", action: #selector(chooseSmaller))
            }

            addAction("Cancel", action: #selector(cancelPendingAsk))
            menu.addItem(.separator())
        }

        addAction("Open Files...", action: #selector(openFiles))
        addAction("Open Folder...", action: #selector(openFolder))
        menu.addItem(.separator())

        menu.addItem(settingsSubmenu(
            title: "Compression",
            cases: CompressionMode.allCases,
            selected: appModel.compressionMode,
            action: #selector(setCompressionMode(_:))
        ))

        menu.addItem(settingsSubmenu(
            title: "Video Size",
            cases: VideoCompressionMode.allCases,
            selected: appModel.defaultVideoMode,
            action: #selector(setVideoMode(_:))
        ))

        menu.addItem(settingsSubmenu(
            title: "Output",
            cases: OutputMode.allCases,
            selected: appModel.outputMode,
            action: #selector(setOutputMode(_:))
        ))
        menu.addItem(.separator())

        let revealItem = addAction("Show Last Output in Finder", action: #selector(showLastOutput))
        revealItem.isEnabled = appModel.jobs.contains { $0.result != nil }

        let revertItem = addAction("Revert Last Compression", action: #selector(revertLastCompression))
        revertItem.isEnabled = appModel.canRevertLastCompression

        let clearItem = addAction("Clear Finished Items", action: #selector(clearFinishedItems))
        clearItem.isEnabled = !appModel.completedJobs.isEmpty
        menu.addItem(.separator())

        addAction("About Kompakt", action: #selector(showAbout))
        menu.addItem(.separator())
        addAction("Quit Kompakt", action: #selector(quit))
    }

    @discardableResult
    private func addAction(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    private func settingsSubmenu<T: RawRepresentable>(
        title menuTitle: String,
        cases: [T],
        selected: T,
        action: Selector
    ) -> NSMenuItem where T.RawValue == String {
        let item = NSMenuItem(title: menuTitle, action: nil, keyEquivalent: "")
        let submenu = NSMenu()

        for value in cases {
            let child = NSMenuItem(title: title(for: value), action: action, keyEquivalent: "")
            child.target = self
            child.representedObject = value.rawValue
            child.state = value.rawValue == selected.rawValue ? NSControl.StateValue.on : NSControl.StateValue.off
            submenu.addItem(child)
        }

        item.submenu = submenu
        return item
    }

    private func title<T: RawRepresentable>(for value: T) -> String where T.RawValue == String {
        switch value {
        case let mode as CompressionMode:
            mode.title
        case let mode as VideoCompressionMode:
            mode.title
        case let mode as OutputMode:
            mode.title
        default:
            value.rawValue
        }
    }

    @objc private func openFiles() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.level = .floating
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            Task { @MainActor in
                self?.appModel.handleDropped(urls: panel.urls)
            }
        }
    }

    @objc private func openFolder() {
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.level = .floating
        panel.begin { [weak self] response in
            guard response == .OK else { return }
            Task { @MainActor in
                self?.appModel.handleDropped(urls: panel.urls)
            }
        }
    }

    @objc private func chooseLossless() {
        appModel.choosePendingAskMode(.lossless)
    }

    @objc private func chooseSmaller() {
        appModel.choosePendingAskMode(.smaller)
    }

    @objc private func chooseSameResolution() {
        appModel.choosePendingVideoMode(.sameResolution)
    }

    @objc private func choose1080p() {
        appModel.choosePendingVideoMode(.downscale1080)
    }

    @objc private func choose720p() {
        appModel.choosePendingVideoMode(.downscale720)
    }

    @objc private func cancelPendingAsk() {
        appModel.cancelPendingAsk()
    }

    @objc private func setCompressionMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = CompressionMode(rawValue: rawValue) else {
            return
        }

        appModel.compressionMode = mode
    }

    @objc private func setVideoMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = VideoCompressionMode(rawValue: rawValue) else {
            return
        }

        appModel.defaultVideoMode = mode
    }

    @objc private func setOutputMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = OutputMode(rawValue: rawValue) else {
            return
        }

        appModel.outputMode = mode
    }

    @objc private func showLastOutput() {
        appModel.revealLatestOutput()
    }

    @objc private func revertLastCompression() {
        appModel.revertLastCompression()
    }

    @objc private func clearFinishedItems() {
        appModel.clearCompleted()
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

private extension NSMenu {
    func addItem(disabledTitle title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        addItem(item)
    }
}
