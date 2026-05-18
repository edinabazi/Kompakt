import AppKit
import Combine
import SwiftUI

enum ExternalDropZoneMode: Equatable {
    case drag
    case onboarding
}

@MainActor
final class ExternalDropZoneController {
    private let appModel: AppModel
    private var panel: NSPanel?
    private var presentation: DropZonePresentation?
    private var localKeyDownMonitor: Any?
    private var generation = 0
    private let visualWidth: CGFloat = 470
    private let edgeGutter: CGFloat = 96
    private let enterAnimationDuration: TimeInterval = 0.28
    private let exitAnimationDuration: TimeInterval = 0.15
    private let animationTiming = CAMediaTimingFunction(controlPoints: 0.39, 0.57, 0.22, 0.95)

    init(appModel: AppModel) {
        self.appModel = appModel
    }

    func show(mode: ExternalDropZoneMode = .drag) {
        generation += 1
        if mode == .onboarding {
            NSApp.activate(ignoringOtherApps: true)
        }

        let screen = screenForMouse()
        let frame = visibleFrame(on: screen)

        if let panel {
            presentation?.mode = mode
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
            startKeyDownMonitor()
            if mode == .onboarding {
                panel.makeKeyAndOrderFront(nil)
            }
            animateContent(isVisible: true)
            return
        }

        let presentation = DropZonePresentation(mode: mode)
        let effectLeadingGutter = edgeGutter
        let panel = DropZonePanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        let hostingController = NSHostingController(
            rootView: ExternalDropZonePresentationView(
                presentation: presentation,
                effectLeadingGutter: effectLeadingGutter
            )
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
        panel.makeKeyAndOrderFront(nil)

        self.panel = panel
        self.presentation = presentation
        startKeyDownMonitor()
        animateContent(isVisible: true)
    }

    func endDrag(didDrop: Bool) {
        guard !didDrop else { return }
        guard let panel else { return }

        let closingGeneration = generation
        animateContent(isVisible: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + exitAnimationDuration) { [weak self, weak panel] in
            MainActor.assumeIsolated {
                guard self?.generation == closingGeneration else { return }
                panel?.orderOut(nil)
                if self?.panel === panel {
                    self?.panel = nil
                    self?.presentation = nil
                    self?.stopKeyDownMonitor()
                }
            }
        }
    }

    private func startKeyDownMonitor() {
        guard localKeyDownMonitor == nil else { return }

        localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard event.keyCode == 53 else { return event }

            Task { @MainActor [weak self] in
                self?.appModel.dismissExternalDropZone()
            }
            return nil
        }
    }

    private func stopKeyDownMonitor() {
        if let localKeyDownMonitor {
            NSEvent.removeMonitor(localKeyDownMonitor)
            self.localKeyDownMonitor = nil
        }
    }

    private func screenForMouse() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private func visibleFrame(on screen: NSScreen) -> NSRect {
        let panelWidth = min(visualWidth + edgeGutter, screen.frame.width)
        return NSRect(
            x: screen.frame.maxX - panelWidth,
            y: screen.frame.minY,
            width: panelWidth,
            height: screen.frame.height
        )
    }

    private func animateContent(isVisible: Bool) {
        if isVisible {
            withAnimation(.timingCurve(0.39, 0.57, 0.22, 0.95, duration: enterAnimationDuration)) {
                presentation?.isVisible = true
            }
        } else {
            withAnimation(.timingCurve(0.39, 0.57, 0.22, 0.95, duration: exitAnimationDuration)) {
                presentation?.isVisible = false
            }
        }
    }

    deinit {
        MainActor.assumeIsolated {
            stopKeyDownMonitor()
        }
    }
}

final class DropZonePresentation: ObservableObject {
    @Published var isVisible = false
    @Published var mode: ExternalDropZoneMode

    init(mode: ExternalDropZoneMode) {
        self.mode = mode
    }
}

private struct ExternalDropZonePresentationView: View {
    @ObservedObject var presentation: DropZonePresentation
    let effectLeadingGutter: CGFloat

    var body: some View {
        ExternalDropZoneView(effectLeadingGutter: effectLeadingGutter, mode: presentation.mode)
            .scaleEffect(x: presentation.isVisible ? 1 : 0.001, y: 1, anchor: .trailing)
            .opacity(presentation.isVisible ? 1 : 0)
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
