import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let appModel: AppModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
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
        updateStatusIcon(isProcessing: appModel.isProcessing)

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 320, height: 382)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView()
                .environmentObject(appModel)
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
        guard let button = statusItem.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.isOpaque = false
            popover.contentViewController?.view.window?.backgroundColor = .clear
        }
    }
}
