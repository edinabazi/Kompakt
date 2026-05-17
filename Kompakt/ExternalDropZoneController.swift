import AppKit
import SwiftUI

@MainActor
final class ExternalDropZoneController {
    private let appModel: AppModel
    private var panel: NSPanel?
    private let visualWidth: CGFloat = 470
    private let edgeGutter: CGFloat = 96

    init(appModel: AppModel) {
        self.appModel = appModel
    }

    func show() {
        let screen = screenForMouse()
        let panelWidth = min(visualWidth + edgeGutter, screen.frame.width)
        let frame = NSRect(
            x: screen.frame.maxX - panelWidth,
            y: screen.frame.minY,
            width: panelWidth,
            height: screen.frame.height
        )

        if let panel {
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
            return
        }

        let panel = DropZonePanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        let hostingController = NSHostingController(
            rootView: ExternalDropZoneView(effectLeadingGutter: edgeGutter)
                .environmentObject(appModel)
        )
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor

        panel.contentViewController = hostingController
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .stationary]
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        panel.makeKey()

        self.panel = panel
    }

    func endDrag(didDrop: Bool) {
        guard !didDrop else { return }
        panel?.orderOut(nil)
        panel = nil
    }

    private func screenForMouse() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
    }
}

private final class DropZonePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func cancelOperation(_ sender: Any?) {
        AppModel.shared.dismissExternalDropZone()
    }

    override func keyDown(with event: NSEvent) {
        guard event.keyCode != 53 else {
            AppModel.shared.dismissExternalDropZone()
            return
        }

        super.keyDown(with: event)
    }
}
