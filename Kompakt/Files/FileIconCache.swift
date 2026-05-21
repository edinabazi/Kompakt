import AppKit
import UniformTypeIdentifiers

@MainActor
final class FileIconCache {
    static let shared = FileIconCache()

    private var iconsByExtension: [String: NSImage] = [:]

    private init() {}

    func icon(for url: URL) -> NSImage {
        let fileExtension = url.pathExtension.lowercased()
        let key = fileExtension.isEmpty ? "__file__" : fileExtension

        if let icon = iconsByExtension[key] {
            return icon
        }

        let icon = if let contentType = UTType(filenameExtension: fileExtension) {
            NSWorkspace.shared.icon(for: contentType)
        } else {
            NSWorkspace.shared.icon(for: .data)
        }
        iconsByExtension[key] = icon
        return icon
    }
}
