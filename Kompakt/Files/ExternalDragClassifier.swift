import AppKit
import Foundation

enum ExternalDragClassifier {
    private static let promisedTypes: Set<NSPasteboard.PasteboardType> = [
        .init("com.apple.pasteboard.promised-file-url"),
        .init("com.apple.pasteboard.promised-file-content-type"),
        .init("com.apple.pasteboard.promised-file-name"),
        .init("com.apple.pasteboard.promised-file-suggested-name"),
        .init("com.apple.NSFilePromiseItemMetaData")
    ]

    static func supportedURLs(from pasteboard: NSPasteboard) -> [URL] {
        supportedURLs(from: pasteboard.pasteboardItems ?? [])
    }

    static func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
        fileURLs(from: pasteboard.pasteboardItems ?? [])
    }

    static func hasFileURLs(_ pasteboard: NSPasteboard) -> Bool {
        hasFileURLs(pasteboard.pasteboardItems ?? [])
    }

    static func hasSupportedFileURLs(_ pasteboard: NSPasteboard) -> Bool {
        !supportedURLs(from: pasteboard).isEmpty
    }

    static func hasSupportedFileHints(_ pasteboard: NSPasteboard) -> Bool {
        hasSupportedFileHints(pasteboard.pasteboardItems ?? [])
    }

    static func supportedFileHintURLs(_ pasteboard: NSPasteboard) -> [URL] {
        supportedFileHintURLs(pasteboard.pasteboardItems ?? [])
    }

    static func hasFileURLs(_ items: [NSPasteboardItem]) -> Bool {
        !items.isEmpty
            && !items.contains(where: hasPromisedFileType)
            && items.contains { item in
                item.types.contains(.fileURL)
                    || item.types.contains(.URL)
                    || item.types.contains(.string)
            }
    }

    static func supportedURLs(from items: [NSPasteboardItem]) -> [URL] {
        guard !items.isEmpty, !items.contains(where: hasPromisedFileType) else {
            return []
        }

        let urls = items.compactMap(fileURL(from:))
        guard !urls.isEmpty else { return [] }

        return FileCollector.collectFiles(from: urls)
    }

    static func fileURLs(from items: [NSPasteboardItem]) -> [URL] {
        guard !items.isEmpty, !items.contains(where: hasPromisedFileType) else {
            return []
        }

        return items.compactMap(fileURL(from:))
    }

    private static func hasSupportedFileHints(_ items: [NSPasteboardItem]) -> Bool {
        !supportedFileHintURLs(items).isEmpty
    }

    private static func supportedFileHintURLs(_ items: [NSPasteboardItem]) -> [URL] {
        guard hasFileURLs(items) else { return [] }
        return items.compactMap(fileURL(from:)).filter { FileCollector.canAcceptDropHint($0) }
    }

    private static func hasPromisedFileType(_ item: NSPasteboardItem) -> Bool {
        !promisedTypes.isDisjoint(with: Set(item.types))
    }

    private static func fileURL(from item: NSPasteboardItem) -> URL? {
        if let string = item.string(forType: .fileURL), let url = URL(string: string) {
            return url
        }

        if let string = item.string(forType: .URL), let url = URL(string: string), url.isFileURL {
            return url
        }

        if let string = item.string(forType: .string) {
            if let url = URL(string: string), url.isFileURL {
                return url
            }

            let url = URL(fileURLWithPath: string)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        return nil
    }
}
