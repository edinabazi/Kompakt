import AppKit

@MainActor
final class ExternalDragMonitor {
    private weak var appModel: AppModel?
    private weak var dropZoneController: ExternalDropZoneController?
    private var globalMouseDownMonitor: Any?
    private var localMouseDownMonitor: Any?
    private var dragMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var localMouseUpMonitor: Any?
    private var lastDragChangeCount = NSPasteboard(name: .drag).changeCount
    private var mouseDownDragChangeCount = NSPasteboard(name: .drag).changeCount
    private var dragSession = 0

    init(appModel: AppModel, dropZoneController: ExternalDropZoneController) {
        self.appModel = appModel
        self.dropZoneController = dropZoneController
    }

    func start() {
        guard dragMonitor == nil else { return }

        globalMouseDownMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleMouseDown()
            }
        }

        localMouseDownMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleMouseDown()
            }
            return event
        }

        dragMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleDragEvent()
            }
        }

        globalMouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            DispatchQueue.main.async {
                self?.handleMouseUp()
            }
        }

        localMouseUpMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            DispatchQueue.main.async {
                self?.handleMouseUp()
            }
            return event
        }
    }

    func stop() {
        if let globalMouseDownMonitor {
            NSEvent.removeMonitor(globalMouseDownMonitor)
            self.globalMouseDownMonitor = nil
        }

        if let localMouseDownMonitor {
            NSEvent.removeMonitor(localMouseDownMonitor)
            self.localMouseDownMonitor = nil
        }

        if let dragMonitor {
            NSEvent.removeMonitor(dragMonitor)
            self.dragMonitor = nil
        }

        if let globalMouseUpMonitor {
            NSEvent.removeMonitor(globalMouseUpMonitor)
            self.globalMouseUpMonitor = nil
        }

        if let localMouseUpMonitor {
            NSEvent.removeMonitor(localMouseUpMonitor)
            self.localMouseUpMonitor = nil
        }
    }

    private func handleDragEvent() {
        guard NSEvent.pressedMouseButtons > 0 else { return }

        let pasteboard = NSPasteboard(name: .drag)
        guard pasteboard.changeCount != mouseDownDragChangeCount else { return }
        guard pasteboard.changeCount != lastDragChangeCount else { return }

        let hintURLs = ExternalDragClassifier.supportedFileHintURLs(pasteboard)
        guard !hintURLs.isEmpty else { return }

        lastDragChangeCount = pasteboard.changeCount
        dragSession += 1
        appModel?.beginExternalDrag(urls: hintURLs)
        dropZoneController?.show()
    }

    private func handleMouseDown() {
        mouseDownDragChangeCount = NSPasteboard(name: .drag).changeCount
    }

    private func handleMouseUp() {
        let endingSession = dragSession
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            guard self?.dragSession == endingSession else { return }
            self?.appModel?.endExternalDrag(didDrop: false)
        }
    }

    deinit {
        if let globalMouseDownMonitor {
            NSEvent.removeMonitor(globalMouseDownMonitor)
        }
        if let localMouseDownMonitor {
            NSEvent.removeMonitor(localMouseDownMonitor)
        }
        if let dragMonitor {
            NSEvent.removeMonitor(dragMonitor)
        }
        if let globalMouseUpMonitor {
            NSEvent.removeMonitor(globalMouseUpMonitor)
        }
        if let localMouseUpMonitor {
            NSEvent.removeMonitor(localMouseUpMonitor)
        }
    }
}
