import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject {
    private let appModel: AppModel
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var cancellables: Set<AnyCancellable> = []

    init(appModel: AppModel) {
        self.appModel = appModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()

        super.init()

        configureStatusItem()
        configurePopover()
        bindState()
    }

    func showPopover() {
        guard let button = statusItem.button else { return }

        if !popover.isShown {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    func updateStatusIcon(isProcessing: Bool) {
        guard let button = statusItem.button else { return }

        let imageName = isProcessing ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.down.circle.fill"
        let image = NSImage(systemSymbolName: imageName, accessibilityDescription: "Kompakt")
        image?.isTemplate = true
        button.image = image
        button.contentTintColor = isProcessing ? NSColor.systemMint : nil
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(statusItemClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "Kompakt"
        updateStatusIcon(isProcessing: appModel.isProcessing)
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 360, height: 480)
        popover.contentViewController = NSHostingController(
            rootView: MainView()
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

    @objc private func statusItemClicked() {
        togglePopover()
    }
}
