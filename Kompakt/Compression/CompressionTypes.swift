import Foundation

enum CompressionMode: String, CaseIterable, Identifiable {
    case ask
    case lossless
    case smaller

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ask: "Ask"
        case .lossless: "Lossless"
        case .smaller: "Smaller"
        }
    }
}

enum OutputMode: String, CaseIterable, Identifiable {
    case replaceOriginals
    case createCopies

    var id: String { rawValue }

    var title: String {
        switch self {
        case .replaceOriginals: "Replace originals"
        case .createCopies: "Create copies"
        }
    }
}

enum VideoCompressionMode: String, CaseIterable, Identifiable {
    case sameResolution
    case downscale1080
    case downscale720

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sameResolution: "Same size"
        case .downscale1080: "1080p"
        case .downscale720: "720p"
        }
    }

    var subtitle: String {
        switch self {
        case .sameResolution: "Lower bitrate, keep resolution"
        case .downscale1080: "Cap height at 1080p"
        case .downscale720: "Smallest practical file"
        }
    }

    var maxHeight: Int? {
        switch self {
        case .sameResolution: nil
        case .downscale1080: 1080
        case .downscale720: 720
        }
    }
}

enum FileFormat: String {
    case png
    case jpeg
    case gif
    case svg
    case webp
    case mp4
    case mov
    case m4v

    var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        default: rawValue
        }
    }

    var isVideo: Bool {
        switch self {
        case .mp4, .mov, .m4v:
            true
        case .png, .jpeg, .gif, .svg, .webp:
            false
        }
    }

    var optimizableKind: OptimizableFileKind {
        switch self {
        case .png, .jpeg, .gif, .svg, .webp:
            .image
        case .mp4, .mov, .m4v:
            .video
        }
    }

    var displayName: String {
        switch self {
        case .jpeg:
            "JPG"
        default:
            rawValue.uppercased()
        }
    }
}

enum ProcessingOperation: Equatable {
    case compress
    case convert(FileFormat)

    var isConversion: Bool {
        if case .convert = self { return true }
        return false
    }

    var targetFormat: FileFormat? {
        if case .convert(let format) = self { return format }
        return nil
    }
}

enum ConversionCatalog {
    static func targetFormats(from source: FileFormat) -> [FileFormat] {
        switch source {
        case .png:
            [.jpeg, .webp]
        case .jpeg:
            [.png, .webp]
        case .webp:
            [.png, .jpeg]
        case .mov, .m4v:
            [.mp4]
        case .gif, .svg, .mp4:
            []
        }
    }

    static func targetFormats(fromSources sources: [FileFormat]) -> [FileFormat] {
        guard let first = sources.first else { return [] }
        let remainingTargets = sources.dropFirst().map { Set(targetFormats(from: $0)) }

        return targetFormats(from: first).filter { target in
            remainingTargets.allSatisfy { $0.contains(target) }
        }
    }

    static func targetFormats(fromFileHintExtensions urls: [URL]) -> [FileFormat] {
        guard !urls.isEmpty else { return [] }

        for url in urls {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return []
            }
        }

        let detectedFormats = urls.compactMap { FileFormat.fromFileExtension($0.pathExtension) }
        guard detectedFormats.count == urls.count else { return [] }
        return targetFormats(fromSources: detectedFormats)
    }

    static func targetFormats(fromCollectedFiles urls: [URL]) -> [FileFormat] {
        guard !urls.isEmpty else { return [] }
        let detectedFormats = urls.compactMap(FileFormatDetector.detect)
        guard detectedFormats.count == urls.count else { return [] }
        return targetFormats(fromSources: detectedFormats)
    }

    static func sourceFormat(fromFileHintExtensions urls: [URL]) -> FileFormat? {
        guard !urls.isEmpty else { return nil }

        for url in urls {
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return nil
            }
        }

        let detectedFormats = urls.compactMap { FileFormat.fromFileExtension($0.pathExtension) }
        guard detectedFormats.count == urls.count else { return nil }
        let formats = Set(detectedFormats)
        guard formats.count == 1, let format = formats.first else { return nil }
        return targetFormats(from: format).isEmpty ? nil : format
    }

    static func sourceFormat(fromCollectedFiles urls: [URL]) -> FileFormat? {
        guard !urls.isEmpty else { return nil }
        let detectedFormats = urls.compactMap(FileFormatDetector.detect)
        guard detectedFormats.count == urls.count else { return nil }
        let formats = Set(detectedFormats)
        guard formats.count == 1, let format = formats.first else { return nil }
        return targetFormats(from: format).isEmpty ? nil : format
    }
}

enum OptimizableFileKind: Equatable {
    case image
    case video
    case file

    func noun(isPlural: Bool) -> String {
        switch self {
        case .image:
            isPlural ? "images" : "image"
        case .video:
            isPlural ? "videos" : "video"
        case .file:
            isPlural ? "files" : "file"
        }
    }
}

struct OptimizableFileSummary: Equatable {
    let count: Int
    let kind: OptimizableFileKind

    var noun: String {
        kind.noun(isPlural: count != 1)
    }

    static let fallback = OptimizableFileSummary(count: 1, kind: .file)

    static func from(_ urls: [URL]) -> OptimizableFileSummary {
        let fileURLs = FileCollector.collectFiles(from: urls)
        return fromCollectedFiles(fileURLs)
    }

    static func fromCollectedFiles(_ urls: [URL]) -> OptimizableFileSummary {
        guard !urls.isEmpty else { return fallback }

        let kinds = Set(urls.map { FileFormatDetector.detect($0)?.optimizableKind ?? .file })
        let kind = kinds.count == 1 ? (kinds.first ?? .file) : .file
        return OptimizableFileSummary(count: urls.count, kind: kind)
    }

    static func fromCollectedFilesAsync(_ urls: [URL]) async -> OptimizableFileSummary {
        await Task.detached(priority: .userInitiated) {
            fromCollectedFiles(urls)
        }.value
    }

    static func fromFileHints(_ urls: [URL]) -> OptimizableFileSummary {
        guard !urls.isEmpty else { return fallback }

        let kinds = Set(urls.map { url in
            FileFormatDetector.detect(url)?.optimizableKind ?? .file
        })
        let kind = kinds.count == 1 ? (kinds.first ?? .file) : .file
        return OptimizableFileSummary(count: urls.count, kind: kind)
    }

    static func fromFileHintExtensions(_ urls: [URL]) -> OptimizableFileSummary {
        guard !urls.isEmpty else { return fallback }

        let kinds = Set(urls.map { url in
            FileFormat.fromFileExtension(url.pathExtension)?.optimizableKind ?? .file
        })
        let kind = kinds.count == 1 ? (kinds.first ?? .file) : .file
        return OptimizableFileSummary(count: urls.count, kind: kind)
    }
}

extension FileFormat {
    static func fromFileExtension(_ fileExtension: String) -> FileFormat? {
        switch fileExtension.lowercased() {
        case "png":
            .png
        case "jpg", "jpeg":
            .jpeg
        case "gif":
            .gif
        case "svg":
            .svg
        case "webp":
            .webp
        case "mp4":
            .mp4
        case "mov":
            .mov
        case "m4v":
            .m4v
        default:
            nil
        }
    }
}

enum CompressionStatus: Equatable {
    case queued
    case running
    case skipped(String)
    case finished
    case reverted
    case failed(String)

    var isFinished: Bool {
        switch self {
        case .skipped, .finished, .reverted, .failed:
            true
        case .queued, .running:
            false
        }
    }

    func message(for operation: ProcessingOperation) -> String {
        switch self {
        case .queued: "Waiting."
        case .running: operation.isConversion ? "Konverting..." : "Kompakting..."
        case .skipped(let reason): reason
        case .finished:
            if case .convert(let format) = operation {
                "Konverted to \(format.displayName)."
            } else {
                "Kompakted."
            }
        case .reverted: "Reverted."
        case .failed(let reason): reason
        }
    }

    var message: String {
        message(for: .compress)
    }
}

struct CompressionResult: Equatable {
    let outputURL: URL
    let backupURL: URL?
    let originalSize: Int64
    let compressedSize: Int64
    let toolName: String

    var bytesSaved: Int64 {
        max(0, originalSize - compressedSize)
    }

    var savingsRatio: Double {
        guard originalSize > 0 else { return 0 }
        return Double(bytesSaved) / Double(originalSize)
    }
}

struct CompressionBatchSummary: Equatable {
    let originalSize: Int64
    let compressedSize: Int64
    let optimizedCount: Int
    let totalCount: Int
    let percentSmallerText: String
    let sizeChangeText: String
    let isConversion: Bool
    let targetFormat: FileFormat?

    var bytesSaved: Int64 {
        max(0, originalSize - compressedSize)
    }

    var savingsRatio: Double {
        guard originalSize > 0 else { return 0 }
        return Double(bytesSaved) / Double(originalSize)
    }

    static func from(_ jobs: [CompressionJob]) -> CompressionBatchSummary? {
        let results = jobs.compactMap(\.result)
        guard !results.isEmpty else { return nil }
        let originalSize = results.reduce(0) { $0 + $1.originalSize }
        let compressedSize = results.reduce(0) { $0 + $1.compressedSize }
        let bytesSaved = max(0, originalSize - compressedSize)
        let savingsRatio = originalSize > 0 ? Double(bytesSaved) / Double(originalSize) : 0
        let original = ByteCountFormatter.string(fromByteCount: originalSize, countStyle: .file)
        let compressed = ByteCountFormatter.string(fromByteCount: compressedSize, countStyle: .file)
        let conversionTargets = Set(jobs.compactMap(\.operation.targetFormat))
        let conversionTarget = conversionTargets.count == 1 ? conversionTargets.first : nil
        let isConversion = conversionTarget != nil

        return CompressionBatchSummary(
            originalSize: originalSize,
            compressedSize: compressedSize,
            optimizedCount: results.count,
            totalCount: jobs.count,
            percentSmallerText: isConversion
                ? "Konverted to \(conversionTarget?.displayName ?? "file")"
                : "\(Int((savingsRatio * 100).rounded()))% smaller",
            sizeChangeText: "\(original) -> \(compressed)",
            isConversion: isConversion,
            targetFormat: conversionTarget
        )
    }
}

struct CompressionJob: Identifiable, Equatable {
    let id = UUID()
    let batchID: UUID
    let url: URL
    let mode: CompressionMode
    let videoMode: VideoCompressionMode?
    let outputMode: OutputMode
    let operation: ProcessingOperation
    var format: FileFormat?
    var status: CompressionStatus = .queued
    var result: CompressionResult?

    var displayName: String {
        url.lastPathComponent
    }

    init(
        batchID: UUID,
        url: URL,
        mode: CompressionMode,
        videoMode: VideoCompressionMode?,
        outputMode: OutputMode,
        operation: ProcessingOperation = .compress
    ) {
        self.batchID = batchID
        self.url = url
        self.mode = mode
        self.videoMode = videoMode
        self.outputMode = operation.isConversion ? .createCopies : outputMode
        self.operation = operation
    }
}
