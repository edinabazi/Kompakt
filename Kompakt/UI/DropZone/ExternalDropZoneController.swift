import AppKit
import Combine
import Carbon.HIToolbox
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
    private var hostingController: NSViewController?
    private weak var revealContainerView: NSView?
    private weak var dropZoneView: NSView?
    private var localKeyDownMonitor: Any?
    private var escapeHotKey: EventHotKeyRef?
    private var escapeHotKeyHandler: EventHandlerRef?
    private var generation = 0
    private let visualWidth: CGFloat = 470
    private let edgeGutter: CGFloat = 96
    private let enterAnimationDuration: TimeInterval = 0.28
    private let exitAnimationDuration: TimeInterval = 0.15

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
            presentation?.contentSize = frame.size
            panel.setFrame(frame, display: true)
            if let revealContainerView, let dropZoneView {
                configureRevealViews(container: revealContainerView, content: dropZoneView, size: frame.size, isVisible: false)
            }
            panel.orderFrontRegardless()
            startKeyDownMonitor()
            if mode == .onboarding {
                panel.makeKeyAndOrderFront(nil)
            }
            animateContent(isVisible: true)
            return
        }

        let presentation = DropZonePresentation(mode: mode, contentSize: frame.size)
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

        let revealContainerView = DropZoneRevealContainerView(frame: NSRect(origin: .zero, size: frame.size))
        revealContainerView.autoresizingMask = [.width, .height]
        revealContainerView.addSubview(hostingController.view)
        configureRevealViews(
            container: revealContainerView,
            content: hostingController.view,
            size: frame.size,
            isVisible: false
        )

        panel.contentView = revealContainerView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.animationBehavior = .none
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .stationary]
        panel.ignoresMouseEvents = false
        panel.acceptsMouseMovedEvents = true
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        panel.makeKeyAndOrderFront(nil)

        self.panel = panel
        self.presentation = presentation
        self.hostingController = hostingController
        self.revealContainerView = revealContainerView
        self.dropZoneView = hostingController.view
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
                    self?.hostingController = nil
                    self?.revealContainerView = nil
                    self?.dropZoneView = nil
                    self?.stopKeyDownMonitor()
                }
            }
        }
    }

    private func startKeyDownMonitor() {
        if localKeyDownMonitor == nil {
            localKeyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard event.keyCode == 53 else { return event }

                Task { @MainActor [weak self] in
                    self?.appModel.dismissExternalDropZone()
                }
                return nil
            }
        }

        registerEscapeHotKey()
    }

    fileprivate func dismissFromEscapeHotKey() {
        appModel.dismissExternalDropZone()
    }

    private func stopKeyDownMonitor() {
        if let localKeyDownMonitor {
            NSEvent.removeMonitor(localKeyDownMonitor)
            self.localKeyDownMonitor = nil
        }

        unregisterEscapeHotKey()
    }

    private func registerEscapeHotKey() {
        guard escapeHotKey == nil, escapeHotKeyHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            externalDropZoneEscapeHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &escapeHotKeyHandler
        )
        guard handlerStatus == noErr else {
            escapeHotKeyHandler = nil
            return
        }

        let hotKeyID = EventHotKeyID(signature: ExternalDropZoneEscapeHotKey.signature, id: ExternalDropZoneEscapeHotKey.id)
        let hotKeyStatus = RegisterEventHotKey(
            UInt32(kVK_Escape),
            0,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &escapeHotKey
        )
        guard hotKeyStatus == noErr else {
            unregisterEscapeHotKey()
            return
        }
    }

    private func unregisterEscapeHotKey() {
        if let escapeHotKey {
            UnregisterEventHotKey(escapeHotKey)
            self.escapeHotKey = nil
        }

        if let escapeHotKeyHandler {
            RemoveEventHandler(escapeHotKeyHandler)
            self.escapeHotKeyHandler = nil
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
        let duration = isVisible ? enterAnimationDuration : exitAnimationDuration
        presentation?.isVisible = isVisible

        guard let dropZoneView else { return }
        let size = presentation?.contentSize ?? dropZoneView.bounds.size
        if let revealContainerView {
            configureRevealViews(container: revealContainerView, content: dropZoneView, size: size, isVisible: !isVisible)
        }

        animateRevealView(dropZoneView, size: size, isVisible: isVisible, duration: duration)
    }

    private func configureRevealViews(container: NSView, content: NSView, size: CGSize, isVisible: Bool) {
        container.frame = NSRect(origin: .zero, size: size)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.clear.cgColor
        container.layer?.masksToBounds = true

        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.clear.cgColor
        content.autoresizingMask = []
        content.frame = revealFrame(size: size, isVisible: isVisible)
    }

    private func revealFrame(size: CGSize, isVisible: Bool) -> NSRect {
        NSRect(
            x: isVisible ? 0 : size.width,
            y: 0,
            width: size.width,
            height: size.height
        )
    }

    private func animateRevealView(_ view: NSView, size: CGSize, isVisible: Bool, duration: TimeInterval) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.39, 0.57, 0.22, 0.95)
            view.animator().frame = revealFrame(size: size, isVisible: isVisible)
        }
    }

    deinit {
        MainActor.assumeIsolated {
            stopKeyDownMonitor()
        }
    }
}

final class DropZonePresentation: ObservableObject {
    var isVisible = false
    @Published var mode: ExternalDropZoneMode
    @Published var contentSize: CGSize

    init(mode: ExternalDropZoneMode, contentSize: CGSize) {
        self.mode = mode
        self.contentSize = contentSize
    }
}

private struct ExternalDropZonePresentationView: View {
    @ObservedObject var presentation: DropZonePresentation
    let effectLeadingGutter: CGFloat

    var body: some View {
        ExternalDropZoneView(effectLeadingGutter: effectLeadingGutter, mode: presentation.mode)
            .frame(width: presentation.contentSize.width, height: presentation.contentSize.height)
    }
}

private final class DropZoneRevealContainerView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.masksToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        layer?.masksToBounds = true
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

private enum ExternalDropZoneEscapeHotKey {
    static let signature = OSType(0x4B4D4553)
    static let id = UInt32(1)
}

private let externalDropZoneEscapeHotKeyHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else { return noErr }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    guard status == noErr,
          hotKeyID.signature == ExternalDropZoneEscapeHotKey.signature,
          hotKeyID.id == ExternalDropZoneEscapeHotKey.id else {
        return noErr
    }

    let controller = Unmanaged<ExternalDropZoneController>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        controller.dismissFromEscapeHotKey()
    }
    return noErr
}
