import AppKit
import CoreFoundation
import Testing
@testable import Kompakt

@MainActor
struct ExternalDropZoneTests {
    @Test(arguments: [
        NSPoint(x: 0, y: 0),
        NSPoint(x: -1920, y: 240),
        NSPoint(x: 1920, y: -1080)
    ])
    func imageDragKeepsURLsAndActionThroughRelease(windowOrigin: NSPoint) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let image = directory.appendingPathComponent("image.png")
        try Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]).write(to: image)

        let window = NSWindow(
            contentRect: NSRect(origin: windowOrigin, size: NSSize(width: 566, height: 900)),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        let receiver = DropReceiverNSView(frame: NSRect(x: 0, y: 0, width: 566, height: 900))
        window.contentView = receiver
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        let reference = try #require(CFURLCreateFileReferenceURL(nil, image as CFURL, nil)?.takeRetainedValue())
        let referenceString = CFURLGetString(reference)! as String

        for action in [DropZoneDropAction.compress, .convert] {
            pasteboard.clearContents()
            let item = NSPasteboardItem()
            item.setString(referenceString, forType: .fileURL)
            pasteboard.writeObjects([item])
            let drag = TestDraggingInfo(pasteboard: pasteboard, window: window)
            drag.draggingLocation = NSPoint(x: 300, y: action == .compress ? 700 : 200)

            var previewURLs: [URL] = []
            var droppedURLs: [URL] = []
            var droppedAction: DropZoneDropAction?
            receiver.allowsConversion = true
            receiver.onDragEntered = { previewURLs = $0 }
            receiver.onDrop = { droppedURLs = $0; droppedAction = $1 }

            #expect(receiver.draggingEntered(drag) == .copy)
            #expect(OptimizableFileSummary.fromFileHintExtensions(previewURLs).kind == .image)
            #expect(ConversionCatalog.targetFormats(fromFileHintExtensions: previewURLs) == [.jpeg, .webp])
            #expect(droppedURLs.isEmpty)

            // The accepted session must survive a pasteboard handoff until release.
            pasteboard.clearContents()
            #expect(receiver.draggingUpdated(drag) == .copy)
            #expect(receiver.prepareForDragOperation(drag))
            #expect(receiver.performDragOperation(drag))
            #expect(droppedURLs.map(\.standardizedFileURL) == [image.standardizedFileURL])
            #expect(FileCollector.collectFiles(from: droppedURLs) == [image.standardizedFileURL])
            #expect(droppedAction == action)
            receiver.concludeDragOperation(drag)
            #expect(!receiver.prepareForDragOperation(drag))
        }

        // A later empty drag cannot reuse the preceding image's snapshot.
        let emptyDrag = TestDraggingInfo(pasteboard: pasteboard, window: window)
        #expect(receiver.draggingEntered(emptyDrag).isEmpty)
        #expect(!receiver.performDragOperation(emptyDrag))
    }

    @Test func exitingDragClearsAcceptedURLs() {
        let receiver = DropReceiverNSView(frame: NSRect(x: 0, y: 0, width: 566, height: 900))
        let pasteboard = NSPasteboard.withUniqueName()
        defer { pasteboard.releaseGlobally() }
        pasteboard.writeObjects([NSURL(fileURLWithPath: "/tmp/image.png")])
        let drag = TestDraggingInfo(pasteboard: pasteboard, window: nil)
        #expect(receiver.draggingEntered(drag) == .copy)
        receiver.draggingExited(drag)
        #expect(!receiver.prepareForDragOperation(drag))
        #expect(!receiver.performDragOperation(drag))
    }
}

@MainActor
private final class TestDraggingInfo: NSObject, NSDraggingInfo {
    let draggingPasteboard: NSPasteboard
    let draggingDestinationWindow: NSWindow?
    var draggingLocation = NSPoint.zero
    var draggingSourceOperationMask: NSDragOperation { .copy }
    var draggedImageLocation: NSPoint { draggingLocation }
    var draggedImage: NSImage? { nil }
    var draggingSource: Any? { nil }
    var draggingSequenceNumber: Int { 1 }
    var draggingFormation: NSDraggingFormation = .none
    var animatesToDestination = false
    var numberOfValidItemsForDrop = 1
    var springLoadingHighlight: NSSpringLoadingHighlight { .none }

    init(pasteboard: NSPasteboard, window: NSWindow?) {
        draggingPasteboard = pasteboard
        draggingDestinationWindow = window
    }

    func slideDraggedImage(to screenPoint: NSPoint) {}
    override func namesOfPromisedFilesDropped(atDestination dropDestination: URL) -> [String]? { nil }
    func resetSpringLoading() {}
    func enumerateDraggingItems(
        options enumOpts: NSDraggingItemEnumerationOptions,
        for view: NSView?,
        classes classArray: [AnyClass],
        searchOptions: [NSPasteboard.ReadingOptionKey: Any],
        using block: (NSDraggingItem, Int, UnsafeMutablePointer<ObjCBool>) -> Void
    ) {}
}
