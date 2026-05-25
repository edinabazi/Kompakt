import Foundation

enum FileFormatDetector {
    static func detect(_ url: URL) -> FileFormat? {
        let pathExtension = url.pathExtension.lowercased()

        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { try? handle.close() }

        let data = (try? handle.read(upToCount: 4096)) ?? Data()
        let bytes = [UInt8](data)

        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]) {
            return .png
        }

        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
            return .jpeg
        }

        if bytes.starts(with: [0x47, 0x49, 0x46, 0x38]) {
            return .gif
        }

        if isWebPHeader(bytes) {
            return .webp
        }

        if pathExtension == "svg", isSVG(data) {
            return .svg
        }

        if bytes.count >= 8,
           bytes[4] == 0x66,
           bytes[5] == 0x74,
           bytes[6] == 0x79,
           bytes[7] == 0x70 {
            switch pathExtension {
            case "mp4": return .mp4
            case "mov": return .mov
            case "m4v": return .m4v
            default: break
            }
        }

        switch pathExtension {
        case "mp4": return .mp4
        case "mov": return .mov
        case "m4v": return .m4v
        default: break
        }

        return nil
    }

    static func isAnimatedWebP(_ url: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return false
        }
        defer { try? handle.close() }

        let data = (try? handle.read(upToCount: 1_048_576)) ?? Data()
        let bytes = [UInt8](data)
        guard isWebPHeader(bytes) else { return false }

        var offset = 12
        while offset + 8 <= bytes.count {
            let chunk = bytes[offset..<(offset + 4)]
            let size = UInt32(bytes[offset + 4])
                | UInt32(bytes[offset + 5]) << 8
                | UInt32(bytes[offset + 6]) << 16
                | UInt32(bytes[offset + 7]) << 24
            let payloadOffset = offset + 8

            if chunk.elementsEqual([0x41, 0x4E, 0x49, 0x4D]) || chunk.elementsEqual([0x41, 0x4E, 0x4D, 0x46]) {
                return true
            }

            if chunk.elementsEqual([0x56, 0x50, 0x38, 0x58]),
               payloadOffset < bytes.count,
               bytes[payloadOffset] & 0x02 != 0 {
                return true
            }

            let paddedSize = Int(size) + (Int(size) % 2)
            offset = payloadOffset + paddedSize
        }

        return false
    }

    private static func isWebPHeader(_ bytes: [UInt8]) -> Bool {
        bytes.count >= 12
            && bytes[0] == 0x52
            && bytes[1] == 0x49
            && bytes[2] == 0x46
            && bytes[3] == 0x46
            && bytes[8] == 0x57
            && bytes[9] == 0x45
            && bytes[10] == 0x42
            && bytes[11] == 0x50
    }

    private static func isSVG(_ data: Data) -> Bool {
        guard let text = String(data: data, encoding: .utf8) else {
            return false
        }

        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("\u{FEFF}") {
            trimmed.removeFirst()
            trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if trimmed.lowercased().hasPrefix("<svg") {
            return true
        }

        guard trimmed.lowercased().hasPrefix("<?xml") else {
            return false
        }

        guard let declarationEnd = trimmed.range(of: "?>")?.upperBound else {
            return false
        }

        let afterDeclaration = trimmed[declarationEnd...].trimmingCharacters(in: .whitespacesAndNewlines)
        return afterDeclaration.lowercased().hasPrefix("<svg")
    }
}
