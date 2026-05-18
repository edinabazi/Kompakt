import Foundation
import ImageIO
import UniformTypeIdentifiers

actor CompressionQueue {
    private let runner = OptimizerCommandRunner()
    private let commandCatalog = OptimizerCommandCatalog()

    func process(
        jobs: [CompressionJob],
        onUpdate: @escaping (CompressionJob) async -> Void
    ) async {
        for job in jobs {
            var workingJob = job
            workingJob.status = .running
            await onUpdate(workingJob)

            do {
                workingJob = try await process(job: workingJob)
            } catch {
                workingJob.status = .failed(error.localizedDescription)
            }

            await onUpdate(workingJob)
        }
    }

    private func process(job: CompressionJob) async throws -> CompressionJob {
        var job = job

        guard let format = FileFormatDetector.detect(job.url) else {
            job.status = .skipped("Unsupported file.")
            return job
        }

        job.format = format

        if format == .webp, FileFormatDetector.isAnimatedWebP(job.url) {
            job.status = .skipped("Animated WebP not supported.")
            return job
        }

        let originalSize = try fileSize(job.url)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Kompakt-\(UUID().uuidString)")
            .appendingPathExtension(format.fileExtension)

        defer { try? FileManager.default.removeItem(at: tempURL) }

        guard let candidate = try await bestCandidate(for: job.url, format: format, mode: job.mode, videoMode: job.videoMode, tempURL: tempURL) else {
            job.status = .skipped("No optimizer available.")
            return job
        }

        let compressedSize = try fileSize(candidate.url)
        guard compressedSize > 0, compressedSize < originalSize else {
            job.status = .skipped("Already compact.")
            return job
        }

        let savedFile = try save(candidate: candidate.url, original: job.url, format: format, outputMode: job.outputMode)
        job.result = CompressionResult(
            outputURL: savedFile.outputURL,
            backupURL: savedFile.backupURL,
            originalSize: originalSize,
            compressedSize: compressedSize,
            toolName: candidate.toolName
        )
        job.status = .finished
        return job
    }

    private func bestCandidate(for input: URL, format: FileFormat, mode: CompressionMode, videoMode: VideoCompressionMode?, tempURL: URL) async throws -> (url: URL, toolName: String)? {
        let commands = commandCatalog.commands(for: format, mode: mode, videoMode: videoMode)

        for command in commands {
            if let output = try await runner.run(command, input: input, output: tempURL, mode: mode) {
                return (output, command.name)
            }
        }

        if mode == .smaller, let output = try recompressWithImageIO(input: input, output: tempURL, format: format) {
            return (output, "ImageIO")
        }

        return nil
    }

    private func recompressWithImageIO(input: URL, output: URL, format: FileFormat) throws -> URL? {
        guard format == .jpeg || format == .png else { return nil }
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }

        let type = format == .jpeg ? UTType.jpeg.identifier : UTType.png.identifier
        guard let destination = CGImageDestinationCreateWithURL(output as CFURL, type as CFString, 1, nil) else {
            return nil
        }

        let properties: [CFString: Any] = format == .jpeg
            ? [kCGImageDestinationLossyCompressionQuality: 0.82]
            : [:]

        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output : nil
    }

    private func save(candidate: URL, original: URL, format: FileFormat, outputMode: OutputMode) throws -> SavedFile {
        switch outputMode {
        case .createCopies:
            let destination = availableCopyURL(for: original, format: format)
            try FileManager.default.copyItem(at: candidate, to: destination)
            return SavedFile(outputURL: destination, backupURL: nil)
        case .replaceOriginals:
            let backupURL = availableBackupURL(for: original)
            try FileManager.default.copyItem(at: original, to: backupURL)

            do {
                _ = try FileManager.default.replaceItemAt(
                    original,
                    withItemAt: candidate,
                    backupItemName: nil,
                    options: [.usingNewMetadataOnly]
                )
            } catch {
                try? FileManager.default.removeItem(at: backupURL)
                throw error
            }

            return SavedFile(outputURL: original, backupURL: backupURL)
        }
    }

    private func availableBackupURL(for original: URL) -> URL {
        let directory = backupDirectory()
        let baseName = original.deletingPathExtension().lastPathComponent
        let ext = original.pathExtension
        let fileName = "\(baseName)-\(UUID().uuidString).kompakt-original"
        return directory.appendingPathComponent(fileName).appendingPathExtension(ext)
    }

    private func backupDirectory() -> URL {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = baseDirectory.appendingPathComponent("Kompakt/Backups", isDirectory: true)

        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        return directory
    }

    private func availableCopyURL(for original: URL, format: FileFormat) -> URL {
        let directory = original.deletingLastPathComponent()
        let baseName = original.deletingPathExtension().lastPathComponent
        let ext = original.pathExtension.isEmpty ? format.fileExtension : original.pathExtension
        var candidate = directory.appendingPathComponent("\(baseName)-kompakt").appendingPathExtension(ext)
        var counter = 2

        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName)-kompakt-\(counter)").appendingPathExtension(ext)
            counter += 1
        }

        return candidate
    }

    private func fileSize(_ url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values.fileSize ?? 0)
    }
}

private struct SavedFile {
    let outputURL: URL
    let backupURL: URL?
}

struct OptimizerCommandCatalog {
    func commands(for format: FileFormat, mode: CompressionMode, videoMode: VideoCompressionMode?) -> [OptimizerCommand] {
        switch format {
        case .png:
            return [
                OptimizerCommand(
                    tool: .oxipng,
                    arguments: { input, output, _ in ["--strip", "safe", "-o", "4", "--out", output.path, "--", input.path] },
                    copiesInputFirst: false
                ),
                OptimizerCommand(
                    tool: .optipng,
                    arguments: { _, output, _ in ["-quiet", "-o2", output.path] },
                    copiesInputFirst: true
                )
            ]
        case .jpeg:
            var commands = [
                OptimizerCommand(
                    tool: .jpegoptim,
                    arguments: { _, output, mode in
                        var args = ["--strip-all", "--all-progressive"]
                        if mode == .smaller {
                            args.append("-m82")
                        }
                        args.append(output.path)
                        return args
                    },
                    copiesInputFirst: true
                ),
                OptimizerCommand(
                    tool: .jpegtran,
                    arguments: { input, output, _ in ["-copy", "none", "-optimize", "-progressive", "-outfile", output.path, input.path] },
                    copiesInputFirst: false
                )
            ]
            if mode == .smaller {
                commands.insert(
                    OptimizerCommand(
                        tool: .mozjpeg,
                        arguments: { input, output, _ in ["-quality", "82", "-optimize", "-progressive", "-outfile", output.path, input.path] },
                        copiesInputFirst: false
                    ),
                    at: 0
                )
            }
            return commands
        case .gif:
            return [
                OptimizerCommand(
                    tool: .gifsicle,
                    arguments: { input, output, mode in
                        var args = ["-O3", "--careful", "--no-comments", "--no-names", "-o", output.path, "--", input.path]
                        if mode == .smaller {
                            args.insert("--lossy=40", at: 0)
                        }
                        return args
                    },
                    copiesInputFirst: false
                )
            ]
        case .webp:
            return [
                OptimizerCommand(
                    tool: .cwebp,
                    arguments: { input, output, mode in
                        if mode == .lossless {
                            return [
                                "-quiet",
                                "-mt",
                                "-z", "9",
                                "-metadata", "none",
                                input.path,
                                "-o", output.path
                            ]
                        }

                        return [
                            "-quiet",
                            "-mt",
                            "-m", "6",
                            "-q", "82",
                            "-alpha_q", "90",
                            "-metadata", "none",
                            input.path,
                            "-o", output.path
                        ]
                    },
                    copiesInputFirst: false
                )
            ]
        case .mp4, .mov, .m4v:
            return [
                OptimizerCommand(
                    tool: .ffmpeg,
                    arguments: { input, output, mode in
                        if mode == .lossless {
                            return [
                                "-y", "-i", input.path,
                                "-map", "0",
                                "-c", "copy",
                                "-map_metadata", "-1",
                                "-movflags", "+faststart",
                                output.path
                            ]
                        }

                        let selectedVideoMode = videoMode ?? .sameResolution
                        var args = [
                            "-y", "-i", input.path,
                            "-map", "0:v:0",
                            "-map", "0:a?",
                            "-c:v", "libx264",
                            "-preset", "medium",
                            "-crf", "25",
                            "-pix_fmt", "yuv420p",
                            "-c:a", "aac",
                            "-b:a", "128k",
                            "-map_metadata", "-1"
                        ]

                        if let maxHeight = selectedVideoMode.maxHeight {
                            args.append(contentsOf: ["-vf", "scale=-2:min(ih\\,\(maxHeight))"])
                        }

                        args.append(contentsOf: [
                            "-movflags", "+faststart",
                            output.path
                        ])

                        return args
                    },
                    copiesInputFirst: false
                )
            ]
        }
    }
}
