import AppKit
import Foundation
import Testing
@testable import Kompakt

struct KompaktTests {
    @Test func detectsFileFormatsByBytes() throws {
        let directory = try temporaryDirectory()

        let png = try write([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x00], named: "wrong.txt", in: directory)
        let jpeg = try write([0xFF, 0xD8, 0xFF, 0xE0, 0x00], named: "photo.bin", in: directory)
        let gif = try write([0x47, 0x49, 0x46, 0x38, 0x39, 0x61], named: "loop.data", in: directory)
        let svg = try write(Array("<?xml version=\"1.0\"?><svg xmlns=\"http://www.w3.org/2000/svg\"/>".utf8), named: "vector.svg", in: directory)
        let webp = try write(Array("RIFF".utf8) + [0x00, 0x00, 0x00, 0x00] + Array("WEBP".utf8), named: "picture.bin", in: directory)
        let mp4 = try write([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70], named: "clip.mp4", in: directory)
        let bad = try write([0x00, 0x01, 0x02], named: "bad.png", in: directory)

        #expect(FileFormatDetector.detect(png) == .png)
        #expect(FileFormatDetector.detect(jpeg) == .jpeg)
        #expect(FileFormatDetector.detect(gif) == .gif)
        #expect(FileFormatDetector.detect(svg) == .svg)
        #expect(FileFormatDetector.detect(webp) == .webp)
        #expect(FileFormatDetector.detect(mp4) == .mp4)
        #expect(FileFormatDetector.detect(bad) == nil)
    }

    @Test func detectsAnimatedWebP() throws {
        let directory = try temporaryDirectory()
        let still = try write(Array("RIFF".utf8) + [0x00, 0x00, 0x00, 0x00] + Array("WEBPVP8 ".utf8), named: "still.webp", in: directory)
        let animated = try write(
            Array("RIFF".utf8)
                + [0x1E, 0x00, 0x00, 0x00]
                + Array("WEBPVP8X".utf8)
                + [0x0A, 0x00, 0x00, 0x00]
                + [0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],
            named: "animated.webp",
            in: directory
        )

        #expect(FileFormatDetector.isAnimatedWebP(still) == false)
        #expect(FileFormatDetector.isAnimatedWebP(animated) == true)
    }

    @Test func collectorFindsSupportedFilesInFolders() throws {
        let directory = try temporaryDirectory()
        let nested = directory.appendingPathComponent("Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        let png = try write([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A], named: "a.png", in: directory)
        let jpeg = try write([0xFF, 0xD8, 0xFF], named: "b.jpg", in: nested)
        let movie = try write([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70], named: "d.mov", in: nested)
        let webp = try write(Array("RIFF".utf8) + [0x00, 0x00, 0x00, 0x00] + Array("WEBP".utf8), named: "e.webp", in: nested)
        let svg = try write(Array("<svg xmlns=\"http://www.w3.org/2000/svg\"/>".utf8), named: "f.svg", in: nested)
        _ = try write([0x00], named: "c.bin", in: nested)
        _ = try write([0x00], named: "notes.txt", in: nested)

        let files = Set(FileCollector.collectFiles(from: [directory]))

        #expect(files.contains(png.standardizedFileURL))
        #expect(files.contains(jpeg.standardizedFileURL))
        #expect(files.contains(movie.standardizedFileURL))
        #expect(files.contains(webp.standardizedFileURL))
        #expect(files.contains(svg.standardizedFileURL))
        #expect(files.count == 5)
    }

    @Test func asyncCollectorMatchesSynchronousCollector() async throws {
        let directory = try temporaryDirectory()
        let nested = directory.appendingPathComponent("Nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)

        _ = try write([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A], named: "a.png", in: directory)
        _ = try write([0xFF, 0xD8, 0xFF], named: "b.jpg", in: nested)
        _ = try write([0x00], named: "notes.txt", in: nested)

        let syncFiles = Set(FileCollector.collectFiles(from: [directory]))
        let asyncFiles = await Set(FileCollector.collectFilesAsync(from: [directory]))

        #expect(asyncFiles == syncFiles)
    }

    @Test func videoSummaryAndModesAreExplicit() throws {
        let directory = try temporaryDirectory()
        let movie = try write([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70], named: "clip.mp4", in: directory)
        let summary = OptimizableFileSummary.fromCollectedFiles([movie])

        #expect(summary.kind == .video)
        #expect(summary.noun == "video")
        #expect(VideoCompressionMode.sameResolution.maxHeight == nil)
        #expect(VideoCompressionMode.downscale1080.maxHeight == 1080)
        #expect(VideoCompressionMode.downscale720.maxHeight == 720)
    }

    @Test func fileHintExtensionSummaryClassifiesWithoutReadingBytes() throws {
        let directory = try temporaryDirectory()
        let image = try write([0x00], named: "image.png", in: directory)
        let svg = try write([0x00], named: "vector.svg", in: directory)
        let video = try write([0x00], named: "video.mov", in: directory)
        let unsupported = try write([0x00], named: "notes.txt", in: directory)

        #expect(OptimizableFileSummary.fromFileHintExtensions([image]).kind == .image)
        #expect(OptimizableFileSummary.fromFileHintExtensions([svg]).kind == .image)
        #expect(OptimizableFileSummary.fromFileHintExtensions([video]).kind == .video)
        #expect(OptimizableFileSummary.fromFileHintExtensions([unsupported]).kind == .file)
        #expect(OptimizableFileSummary.fromFileHintExtensions([image, video]).kind == .file)
        #expect(OptimizableFileSummary.fromFileHintExtensions([]) == .fallback)
    }

    @Test func collectedFileSummaryStillUsesByteDetection() throws {
        let directory = try temporaryDirectory()
        let pngWithWrongExtension = try write([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A], named: "image.bin", in: directory)
        let invalidPNG = try write([0x00], named: "invalid.png", in: directory)

        #expect(OptimizableFileSummary.fromCollectedFiles([pngWithWrongExtension]).kind == .image)
        #expect(OptimizableFileSummary.fromCollectedFiles([invalidPNG]).kind == .file)
    }

    @Test func commandCatalogUsesBundledToolsForEachFormat() throws {
        let catalog = OptimizerCommandCatalog()

        #expect(catalog.commands(for: .png, mode: .lossless, videoMode: nil).map(\.tool) == [.oxipng, .optipng])
        #expect(catalog.commands(for: .jpeg, mode: .lossless, videoMode: nil).map(\.tool) == [.jpegoptim, .jpegtran])
        #expect(catalog.commands(for: .jpeg, mode: .smaller, videoMode: nil).map(\.tool).first == .mozjpeg)
        #expect(catalog.commands(for: .gif, mode: .lossless, videoMode: nil).map(\.tool) == [.gifsicle])
        #expect(catalog.commands(for: .svg, mode: .lossless, videoMode: nil).map(\.tool) == [.svgo])
        #expect(catalog.commands(for: .webp, mode: .lossless, videoMode: nil).map(\.tool) == [.cwebp])
        #expect(catalog.commands(for: .mp4, mode: .smaller, videoMode: .downscale720).map(\.tool) == [.ffmpeg])
    }

    @Test func conversionCatalogDefinesV1Matrix() {
        #expect(ConversionCatalog.targetFormats(from: .png) == [.jpeg, .webp])
        #expect(ConversionCatalog.targetFormats(from: .jpeg) == [.png, .webp])
        #expect(ConversionCatalog.targetFormats(from: .webp) == [.png, .jpeg])
        #expect(ConversionCatalog.targetFormats(from: .mov) == [.mp4])
        #expect(ConversionCatalog.targetFormats(from: .m4v) == [.mp4])
        #expect(ConversionCatalog.targetFormats(from: .gif).isEmpty)
        #expect(ConversionCatalog.targetFormats(from: .svg).isEmpty)
        #expect(ConversionCatalog.targetFormats(from: .mp4).isEmpty)
    }

    @Test func conversionCatalogFindsCommonTargetsForCompatibleBatches() throws {
        let directory = try temporaryDirectory()
        let png = try write([0x00], named: "image.png", in: directory)
        let jpeg = try write([0x00], named: "photo.jpg", in: directory)
        let webp = try write([0x00], named: "picture.webp", in: directory)
        let gif = try write([0x00], named: "loop.gif", in: directory)
        let folder = directory.appendingPathComponent("Folder", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        #expect(ConversionCatalog.targetFormats(fromFileHintExtensions: [png]) == [.jpeg, .webp])
        #expect(ConversionCatalog.targetFormats(fromFileHintExtensions: [png, jpeg]) == [.webp])
        #expect(ConversionCatalog.targetFormats(fromFileHintExtensions: [webp, jpeg]) == [.png])
        #expect(ConversionCatalog.targetFormats(fromFileHintExtensions: [png, webp]) == [.jpeg])
        #expect(ConversionCatalog.targetFormats(fromFileHintExtensions: [png, jpeg, webp]).isEmpty)
        #expect(ConversionCatalog.targetFormats(fromFileHintExtensions: [gif]).isEmpty)
        #expect(ConversionCatalog.targetFormats(fromFileHintExtensions: [folder]).isEmpty)
        #expect(ConversionCatalog.targetFormats(fromFileHintExtensions: [png, folder]).isEmpty)
    }

    @Test func conversionCatalogFindsCommonTargetsFromDetectedFiles() throws {
        let directory = try temporaryDirectory()
        let webp = try write(Array("RIFF".utf8) + [0x00, 0x00, 0x00, 0x00] + Array("WEBP".utf8), named: "picture.bin", in: directory)
        let jpeg = try write([0xFF, 0xD8, 0xFF, 0xE0, 0x00], named: "photo.bin", in: directory)
        let png = try write([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A], named: "image.bin", in: directory)

        #expect(ConversionCatalog.targetFormats(fromCollectedFiles: [webp, jpeg]) == [.png])
        #expect(ConversionCatalog.targetFormats(fromCollectedFiles: [png, jpeg]) == [.webp])
        #expect(ConversionCatalog.targetFormats(fromCollectedFiles: [png, jpeg, webp]).isEmpty)
    }

    @Test func conversionCommandCatalogUsesCurrentTools() throws {
        let catalog = ConversionCommandCatalog()

        #expect(catalog.command(from: .png, to: .webp)?.tool == .cwebp)
        #expect(catalog.command(from: .jpeg, to: .webp)?.tool == .cwebp)
        #expect(catalog.command(from: .mov, to: .mp4)?.tool == .ffmpeg)
        #expect(catalog.command(from: .webp, to: .jpeg) == nil)
    }

    @Test func conversionJobsForceCreateCopies() throws {
        let directory = try temporaryDirectory()
        let png = try write([0x00], named: "image.png", in: directory)
        let job = CompressionJob(
            batchID: UUID(),
            url: png,
            mode: .smaller,
            videoMode: nil,
            outputMode: .replaceOriginals,
            operation: .convert(.jpeg)
        )

        #expect(job.outputMode == .createCopies)
        #expect(job.operation == .convert(.jpeg))
    }

    @Test func conversionBatchSummaryDoesNotReportSavings() throws {
        let directory = try temporaryDirectory()
        let source = try write([0x01], named: "source.png", in: directory)
        let output = try write([0x01, 0x02], named: "source-kompakt.jpg", in: directory)
        var job = CompressionJob(
            batchID: UUID(),
            url: source,
            mode: .smaller,
            videoMode: nil,
            outputMode: .createCopies,
            operation: .convert(.jpeg)
        )
        job.status = .finished
        job.result = CompressionResult(outputURL: output, backupURL: nil, originalSize: 1, compressedSize: 2, toolName: "ImageIO")

        let summary = try #require(CompressionBatchSummary.from([job]))

        #expect(summary.isConversion)
        #expect(summary.targetFormat == .jpeg)
        #expect(summary.percentSmallerText == "Konverted to JPG")
        #expect(summary.sizeChangeText == "1 byte -> 2 bytes")
        #expect(summary.bytesSaved == 0)
    }

    @Test func dropZoneActionUsesBottomHalfForConversion() {
        #expect(DropZoneDropAction.action(forNormalizedY: nil, allowsConversion: true) == .compress)
        #expect(DropZoneDropAction.action(forNormalizedY: -0.01, allowsConversion: true) == .compress)
        #expect(DropZoneDropAction.action(forNormalizedY: 0, allowsConversion: true) == .convert)
        #expect(DropZoneDropAction.action(forNormalizedY: 0.8, allowsConversion: false) == .compress)
    }

    @Test func imageIOConversionUsesTargetExtensionWithoutSuffixWhenAvailable() async throws {
        let directory = try temporaryDirectory()
        let source = directory.appendingPathComponent("sample.png")
        try makePNG(at: source)

        let queue = CompressionQueue()
        let job = CompressionJob(
            batchID: UUID(),
            url: source,
            mode: .smaller,
            videoMode: nil,
            outputMode: .replaceOriginals,
            operation: .convert(.jpeg)
        )
        var updates: [CompressionJob] = []

        await queue.process(jobs: [job]) { updatedJob in
            updates.append(updatedJob)
        }

        let finished = try #require(updates.last)
        let outputURL = try #require(finished.result?.outputURL)

        #expect(finished.status == .finished)
        #expect(outputURL.lastPathComponent == "sample.jpg")
        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(FileManager.default.fileExists(atPath: outputURL.path))
        #expect(finished.outputMode == .createCopies)
    }

    @Test func imageIOConversionAddsKompaktSuffixOnlyWhenTargetExists() async throws {
        let directory = try temporaryDirectory()
        let source = directory.appendingPathComponent("sample.png")
        try makePNG(at: source)
        _ = try write([0x01], named: "sample.jpg", in: directory)
        _ = try write([0x01], named: "sample-kompakt.jpg", in: directory)

        let queue = CompressionQueue()
        let job = CompressionJob(
            batchID: UUID(),
            url: source,
            mode: .smaller,
            videoMode: nil,
            outputMode: .replaceOriginals,
            operation: .convert(.jpeg)
        )
        var updates: [CompressionJob] = []

        await queue.process(jobs: [job]) { updatedJob in
            updates.append(updatedJob)
        }

        let finished = try #require(updates.last)
        let outputURL = try #require(finished.result?.outputURL)

        #expect(finished.status == .finished)
        #expect(outputURL.lastPathComponent == "sample-kompakt-2.jpg")
        #expect(FileManager.default.fileExists(atPath: source.path))
        #expect(FileManager.default.fileExists(atPath: outputURL.path))
    }

    @Test func toolExecutableNamesMatchBundledHelperNames() {
        #expect(OptimizerTool.mozjpeg.executableNames == ["cjpeg"])
        #expect(OptimizerTool.svgo.executableNames == ["svgo"])
        #expect(OptimizerTool.ffmpeg.executableNames == ["ffmpeg"])
        #expect(OptimizerTool.imageIO.executableNames.isEmpty)
    }

    @Test func externalDragClassifierAcceptsSupportedFileURLs() throws {
        let directory = try temporaryDirectory()
        let webp = try write(Array("RIFF".utf8) + [0x00, 0x00, 0x00, 0x00] + Array("WEBP".utf8), named: "drag.webp", in: directory)
        let item = pasteboardItem(fileURL: webp)

        let urls = ExternalDragClassifier.supportedURLs(from: [item])

        #expect(urls == [webp.standardizedFileURL])
    }

    @Test func externalDragClassifierAcceptsFoldersWithSupportedFiles() throws {
        let directory = try temporaryDirectory()
        let png = try write([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A], named: "drag.png", in: directory)
        _ = try write([0x00], named: "notes.txt", in: directory)
        let item = pasteboardItem(fileURL: directory)

        let urls = ExternalDragClassifier.supportedURLs(from: [item])

        #expect(urls == [png.standardizedFileURL])
    }

    @Test func externalDragClassifierIgnoresFoldersWithoutSupportedFiles() throws {
        let directory = try temporaryDirectory()
        _ = try write([0x00], named: "notes.txt", in: directory)
        let item = pasteboardItem(fileURL: directory)

        let urls = ExternalDragClassifier.supportedURLs(from: [item])

        #expect(urls.isEmpty)
    }

    @Test func externalDragClassifierIgnoresUnsupportedFiles() throws {
        let directory = try temporaryDirectory()
        let text = try write([0x00], named: "notes.txt", in: directory)
        let item = pasteboardItem(fileURL: text)

        let urls = ExternalDragClassifier.supportedURLs(from: [item])

        #expect(urls.isEmpty)
    }

    @Test func externalDragClassifierIgnoresPromisedFiles() throws {
        let directory = try temporaryDirectory()
        let png = try write([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A], named: "drag.png", in: directory)
        let item = pasteboardItem(fileURL: png)
        item.setString("drag.png", forType: .init("com.apple.pasteboard.promised-file-name"))

        let urls = ExternalDragClassifier.supportedURLs(from: [item])

        #expect(urls.isEmpty)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ bytes: [UInt8], named name: String, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(bytes).write(to: url)
        return url
    }

    private func pasteboardItem(fileURL: URL) -> NSPasteboardItem {
        let item = NSPasteboardItem()
        item.setString(fileURL.absoluteString, forType: .fileURL)
        return item
    }

    private func makePNG(at url: URL) throws {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.systemBlue.setFill()
        NSRect(x: 0, y: 0, width: 2, height: 2).fill()
        image.unlockFocus()

        let data = try #require(image.tiffRepresentation)
        let bitmap = try #require(NSBitmapImageRep(data: data))
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: url)
    }
}

@Suite(.serialized)
@MainActor
struct AppModelRollbackTests {
    @Test func cachedJobSummaryUpdatesWhenJobsAreReplaced() throws {
        let directory = try temporaryDirectory()
        let first = try write([0x01], named: "first.png", in: directory)
        let second = try write([0x02], named: "second.png", in: directory)
        var finished = completedJob(url: first, outputURL: first, backupURL: nil, outputMode: .createCopies)
        var failed = CompressionJob(batchID: UUID(), url: second, mode: .smaller, videoMode: nil, outputMode: .createCopies)
        failed.status = .failed("Failed")

        let appModel = AppModel.shared
        appModel.replaceJobsForTesting([failed, finished])
        finished = try #require(appModel.jobs.last)

        #expect(appModel.latestJob?.id == failed.id)
        #expect(appModel.completedJobs.map(\.id) == [failed.id, finished.id])
        #expect(appModel.recentCompletedJobs.map(\.id) == [finished.id])
        #expect(appModel.totalBytesSaved == 1)
        #expect(appModel.progress == 1)
    }

    @Test func cachedJobSummaryUpdatesWhenCompletedJobsAreCleared() throws {
        let directory = try temporaryDirectory()
        let finishedURL = try write([0x01], named: "finished.png", in: directory)
        let queuedURL = try write([0x02], named: "queued.png", in: directory)
        let finished = completedJob(url: finishedURL, outputURL: finishedURL, backupURL: nil, outputMode: .createCopies)
        let queued = CompressionJob(batchID: UUID(), url: queuedURL, mode: .smaller, videoMode: nil, outputMode: .createCopies)

        let appModel = AppModel.shared
        appModel.replaceJobsForTesting([queued, finished])
        appModel.clearCompleted()

        #expect(appModel.jobs.map(\.id) == [queued.id])
        #expect(appModel.completedJobs.isEmpty)
        #expect(appModel.recentCompletedJobs.isEmpty)
        #expect(appModel.totalBytesSaved == 0)
        #expect(appModel.progress == 0)
    }

    @Test func createCopiesRollbackDeletesOnlyOutputCopy() throws {
        let directory = try temporaryDirectory()
        let original = try write([0x01], named: "original.png", in: directory)
        let output = try write([0x02], named: "original-kompakt.png", in: directory)
        var job = completedJob(url: original, outputURL: output, backupURL: nil, outputMode: .createCopies)

        let appModel = AppModel.shared
        appModel.replaceJobsForTesting([job])
        job = try #require(appModel.jobs.first)

        appModel.revert(job: job)

        #expect(FileManager.default.fileExists(atPath: original.path))
        #expect(!FileManager.default.fileExists(atPath: output.path))
        #expect(appModel.jobs.first?.status == .reverted)
        #expect(appModel.jobs.first?.result == nil)
    }

    @Test func replaceOriginalsRollbackRestoresBackup() throws {
        let directory = try temporaryDirectory()
        let original = try write(Array("kompakted".utf8), named: "photo.png", in: directory)
        let backup = try write(Array("original".utf8), named: "photo.png.kompakt-backup", in: directory)
        var job = completedJob(url: original, outputURL: original, backupURL: backup, outputMode: .replaceOriginals)

        let appModel = AppModel.shared
        appModel.replaceJobsForTesting([job])
        job = try #require(appModel.jobs.first)

        appModel.revert(job: job)

        let restored = try String(contentsOf: original, encoding: .utf8)
        #expect(restored == "original")
        #expect(appModel.jobs.first?.status == .reverted)
        #expect(appModel.jobs.first?.result == nil)
    }

    @Test func missingBackupRollbackLeavesJobResultIntact() throws {
        let directory = try temporaryDirectory()
        let original = try write(Array("kompakted".utf8), named: "photo.png", in: directory)
        let missingBackup = directory.appendingPathComponent("missing-backup")
        var job = completedJob(url: original, outputURL: original, backupURL: missingBackup, outputMode: .replaceOriginals)

        let appModel = AppModel.shared
        appModel.replaceJobsForTesting([job])
        job = try #require(appModel.jobs.first)

        appModel.revert(job: job)

        #expect(appModel.jobs.first?.status == .finished)
        #expect(appModel.jobs.first?.result != nil)
        #expect(appModel.lastMessage == "Revert failed: Original backup not found.")
    }

    private func completedJob(
        url: URL,
        outputURL: URL,
        backupURL: URL?,
        outputMode: OutputMode
    ) -> CompressionJob {
        var job = CompressionJob(
            batchID: UUID(),
            url: url,
            mode: .smaller,
            videoMode: nil,
            outputMode: outputMode
        )
        job.status = .finished
        job.result = CompressionResult(
            outputURL: outputURL,
            backupURL: backupURL,
            originalSize: 2,
            compressedSize: 1,
            toolName: "test"
        )
        return job
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func write(_ bytes: [UInt8], named name: String, in directory: URL) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try Data(bytes).write(to: url)
        return url
    }
}
