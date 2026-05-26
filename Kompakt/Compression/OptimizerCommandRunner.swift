import Foundation

enum OptimizerTool: String, CaseIterable {
    case oxipng
    case optipng
    case jpegtran
    case jpegoptim
    case mozjpeg
    case cwebp
    case gifsicle
    case svgo
    case ffmpeg
    case imageIO

    var displayName: String {
        switch self {
        case .oxipng: "oxipng"
        case .optipng: "optipng"
        case .jpegtran: "jpegtran"
        case .jpegoptim: "jpegoptim"
        case .mozjpeg: "mozjpeg"
        case .cwebp: "cwebp"
        case .gifsicle: "gifsicle"
        case .svgo: "svgo"
        case .ffmpeg: "ffmpeg"
        case .imageIO: "ImageIO"
        }
    }

    var executableNames: [String] {
        switch self {
        case .mozjpeg: ["cjpeg"]
        case .imageIO: []
        default: [rawValue]
        }
    }
}

struct OptimizerCommand {
    let tool: OptimizerTool
    let arguments: (_ input: URL, _ output: URL, _ mode: CompressionMode) -> [String]
    let copiesInputFirst: Bool

    var name: String {
        tool.displayName
    }
}

struct ConversionCommand {
    let tool: OptimizerTool
    let arguments: (_ input: URL, _ output: URL, _ mode: CompressionMode, _ videoMode: VideoCompressionMode?) -> [String]

    var name: String {
        tool.displayName
    }
}

struct OptimizerToolLocator {
    func executable(for tool: OptimizerTool) -> URL? {
        findExecutable(named: tool.executableNames)
    }

    private func findExecutable(named names: [String]) -> URL? {
        let helpersURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Helpers")

        for name in names {
            let helper = helpersURL.appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: helper.path) {
                return helper
            }

            if let bundled = Bundle.main.url(forAuxiliaryExecutable: name),
               FileManager.default.isExecutableFile(atPath: bundled.path) {
                return bundled
            }
        }

        return nil
    }
}

struct OptimizerCommandRunner {
    private let locator = OptimizerToolLocator()

    func run(_ command: OptimizerCommand, input: URL, output: URL, mode: CompressionMode) async throws -> URL? {
        guard let executable = locator.executable(for: command.tool) else {
            return nil
        }

        if command.copiesInputFirst {
            try? FileManager.default.removeItem(at: output)
            try FileManager.default.copyItem(at: input, to: output)
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = command.arguments(input, output, mode)

        let pipe = Pipe()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        process.standardOutput = pipe
        process.standardError = pipe
        defer {
            pipe.fileHandleForReading.readabilityHandler = nil
        }

        try await runAndWaitForProcessTermination(process)

        guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: output.path) else {
            return nil
        }

        return output
    }

    func run(_ command: ConversionCommand, input: URL, output: URL, mode: CompressionMode, videoMode: VideoCompressionMode?) async throws -> URL? {
        guard let executable = locator.executable(for: command.tool) else {
            return nil
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = command.arguments(input, output, mode, videoMode)

        let pipe = Pipe()
        pipe.fileHandleForReading.readabilityHandler = { handle in
            _ = handle.availableData
        }
        process.standardOutput = pipe
        process.standardError = pipe
        defer {
            pipe.fileHandleForReading.readabilityHandler = nil
        }

        try await runAndWaitForProcessTermination(process)

        guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: output.path) else {
            return nil
        }

        return output
    }

    private func runAndWaitForProcessTermination(_ process: Process) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { process in
                    process.terminationHandler = nil
                    continuation.resume()
                }
                do {
                    try process.run()
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            process.terminate()
        }
    }
}
