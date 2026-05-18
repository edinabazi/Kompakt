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
        let webp = try write(Array("RIFF".utf8) + [0x00, 0x00, 0x00, 0x00] + Array("WEBP".utf8), named: "picture.bin", in: directory)
        let mp4 = try write([0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70], named: "clip.mp4", in: directory)
        let bad = try write([0x00, 0x01, 0x02], named: "bad.png", in: directory)

        #expect(FileFormatDetector.detect(png) == .png)
        #expect(FileFormatDetector.detect(jpeg) == .jpeg)
        #expect(FileFormatDetector.detect(gif) == .gif)
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
        _ = try write([0x00], named: "c.bin", in: nested)
        _ = try write([0x00], named: "notes.txt", in: nested)

        let files = Set(FileCollector.collectFiles(from: [directory]))

        #expect(files.contains(png.standardizedFileURL))
        #expect(files.contains(jpeg.standardizedFileURL))
        #expect(files.contains(movie.standardizedFileURL))
        #expect(files.contains(webp.standardizedFileURL))
        #expect(files.count == 4)
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

    @Test func commandCatalogUsesBundledToolsForEachFormat() throws {
        let catalog = OptimizerCommandCatalog()

        #expect(catalog.commands(for: .png, mode: .lossless, videoMode: nil).map(\.tool) == [.oxipng, .optipng])
        #expect(catalog.commands(for: .jpeg, mode: .lossless, videoMode: nil).map(\.tool) == [.jpegoptim, .jpegtran])
        #expect(catalog.commands(for: .jpeg, mode: .smaller, videoMode: nil).map(\.tool).first == .mozjpeg)
        #expect(catalog.commands(for: .gif, mode: .lossless, videoMode: nil).map(\.tool) == [.gifsicle])
        #expect(catalog.commands(for: .webp, mode: .lossless, videoMode: nil).map(\.tool) == [.cwebp])
        #expect(catalog.commands(for: .mp4, mode: .smaller, videoMode: .downscale720).map(\.tool) == [.ffmpeg])
    }

    @Test func toolExecutableNamesMatchBundledHelperNames() {
        #expect(OptimizerTool.mozjpeg.executableNames == ["cjpeg"])
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
}

@Suite(.serialized)
@MainActor
struct AppModelRollbackTests {
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
