import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let appModel: AppModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private let popoverState = MenuBarPopoverState()
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
        button.contentTintColor = nil
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.toolTip = "Kompakt"
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateStatusIcon(isProcessing: appModel.isProcessing)

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = MenuBarPopoverMetrics.size
        let popover = popover
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView { size in
                popover.contentSize = size
            }
                .environmentObject(appModel)
                .environmentObject(popoverState)
        )
    }

    private func bindState() {
        appModel.$isProcessing
            .removeDuplicates()
            .sink { [weak self] isProcessing in
                self?.updateStatusIcon(isProcessing: isProcessing)
            }
            .store(in: &cancellables)
    }

    @objc private func togglePopover() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
            return
        }

        popoverState.screen = .history
        setPopoverShown(showSettings: false)
    }

    private func setPopoverShown(showSettings: Bool) {
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            if showSettings {
                popoverState.screen = .settings
            }
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.isOpaque = false
            popover.contentViewController?.view.window?.backgroundColor = .clear
        }
    }

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ""
        ))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(
            title: "Quit Kompakt",
            action: #selector(quit),
            keyEquivalent: ""
        ))

        for item in menu.items {
            item.target = self
        }

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettings() {
        if popover.isShown {
            popover.performClose(nil)
        }
        setPopoverShown(showSettings: true)
    }

    @objc private func quit() {
        AppCommands.quit()
    }
}
