import Foundation

struct OptimizerCommand {
    let name: String
    let executableNames: [String]
    let arguments: (_ input: URL, _ output: URL, _ mode: CompressionMode) -> [String]
    let copiesInputFirst: Bool
}

struct OptimizerCommandRunner {
    func run(_ command: OptimizerCommand, input: URL, output: URL, mode: CompressionMode) async throws -> URL? {
        guard let executable = findExecutable(named: command.executableNames) else {
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
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0, FileManager.default.fileExists(atPath: output.path) else {
            return nil
        }

        return output
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

            if let bundled = Bundle.main.url(forAuxiliaryExecutable: name), FileManager.default.isExecutableFile(atPath: bundled.path) {
                return bundled
            }
        }

        return nil
    }
}
