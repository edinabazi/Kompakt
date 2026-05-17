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

    static func supportedURLs(from items: [NSPasteboardItem]) -> [URL] {
        guard !items.isEmpty, !items.contains(where: hasPromisedFileType) else {
            return []
        }

        let urls = items.compactMap(fileURL(from:))
        guard !urls.isEmpty else { return [] }

        return FileCollector.collectFiles(from: urls)
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
