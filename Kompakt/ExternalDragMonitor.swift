import AppKit

@MainActor
final class ExternalDragMonitor {
    private weak var appModel: AppModel?
    private weak var dropZoneController: ExternalDropZoneController?
    private var dragMonitor: Any?
    private var globalMouseUpMonitor: Any?
    private var localMouseUpMonitor: Any?
    private var lastDragChangeCount = NSPasteboard(name: .drag).changeCount

    init(appModel: AppModel, dropZoneController: ExternalDropZoneController) {
        self.appModel = appModel
        self.dropZoneController = dropZoneController
    }

    func start() {
        guard dragMonitor == nil else { return }

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
        guard pasteboard.changeCount != lastDragChangeCount else { return }
        lastDragChangeCount = pasteboard.changeCount

        let supportedURLs = ExternalDragClassifier.supportedURLs(from: pasteboard)
        guard !supportedURLs.isEmpty else { return }

        appModel?.beginExternalDrag(urls: supportedURLs)
        dropZoneController?.show()
    }

    private func handleMouseUp() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.appModel?.endExternalDrag(didDrop: false)
        }
    }

    deinit {
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
