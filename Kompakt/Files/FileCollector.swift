import Foundation

enum FileCollector {
    private static let supportedExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "webp",
        "mp4", "mov", "m4v"
    ]

    static func canAcceptDropHint(_ url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return false
        }

        if isDirectory.boolValue {
            return (try? url.resourceValues(forKeys: [.isPackageKey]).isPackage) != true
        }

        return isSupported(url)
    }

    static func collectFiles(from urls: [URL]) -> [URL] {
        urls.flatMap(collectFiles(from:))
    }

    static func collectFilesAsync(from urls: [URL]) async -> [URL] {
        await Task.detached(priority: .userInitiated) {
            collectFiles(from: urls)
        }.value
    }

    private static func collectFiles(from url: URL) -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return []
        }

        if !isDirectory.boolValue {
            return isSupported(url) ? [url.standardizedFileURL] : []
        }

        if (try? url.resourceValues(forKeys: [.isPackageKey]).isPackage) == true {
            return []
        }

        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        return enumerator.compactMap { item -> URL? in
            guard let fileURL = item as? URL else { return nil }
            return isSupported(fileURL) ? fileURL.standardizedFileURL : nil
        }
    }

    private static func isSupported(_ url: URL) -> Bool {
        supportedExtensions.contains(url.pathExtension.lowercased())
    }
}
