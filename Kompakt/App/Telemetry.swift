import Foundation

struct TelemetryEventPayload: Encodable {
    let apiKey: String
    let event: String
    let distinctId: String
    let timestamp: String
    let properties: [String: TelemetryValue]

    enum CodingKeys: String, CodingKey {
        case apiKey = "api_key"
        case event
        case distinctId = "distinct_id"
        case timestamp
        case properties
    }
}

enum TelemetryValue: Encodable {
    case string(String)
    case number(Double)
    case bool(Bool)

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        }
    }
}

struct TelemetryState: Codable {
    var anonymousId: String
    var installedTracked: Bool
}

final class Telemetry {
    static let shared = Telemetry()

    private let apiKey = "phc_BgMn7cE3xxJoTS5GE5PVe6N4MbaKiDPZ8sKSz7Aorv8q"
    private let host = URL(string: "https://s.playheadapp.com")!
    private let stateURL: URL
    private let eventNamePattern = /^[a-z][a-z0-9_]{1,63}$/
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()
    private let isoFormatter = ISO8601DateFormatter()

    private init() {
        let supportDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let appDirectory = supportDirectory.appendingPathComponent("Kompakt", isDirectory: true)
        stateURL = appDirectory.appendingPathComponent("telemetry.json")

        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func trackAppLaunch() async {
        var state = readState()
        writeState(state)

        if !state.installedTracked {
            let tracked = await track("app_installed", properties: [
                "first_version": .string(appVersion),
            ], state: state)
            if tracked {
                state.installedTracked = true
                writeState(state)
            }
        }

        _ = await track("app_opened", state: state)
    }

    @discardableResult
    func track(
        _ event: String,
        properties: [String: TelemetryValue] = [:],
        state providedState: TelemetryState? = nil
    ) async -> Bool {
        guard event.wholeMatch(of: eventNamePattern) != nil else { return false }

        let state = providedState ?? readState()
        var payloadProperties = sanitize(properties)
        payloadProperties["app_version"] = .string(appVersion)
        payloadProperties["platform"] = .string("macOS")

        let payload = TelemetryEventPayload(
            apiKey: apiKey,
            event: event,
            distinctId: state.anonymousId,
            timestamp: isoFormatter.string(from: Date()),
            properties: payloadProperties
        )

        var request = URLRequest(url: host.appendingPathComponent("capture/"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try encoder.encode(payload)
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode else { return false }
            return (200..<300).contains(statusCode)
        } catch {
            return false
        }
    }

    private func sanitize(_ properties: [String: TelemetryValue]) -> [String: TelemetryValue] {
        Dictionary(uniqueKeysWithValues: properties.map { key, value in
            let cleanKey = String(key.prefix(64))
            let cleanValue: TelemetryValue
            switch value {
            case .string(let string):
                cleanValue = .string(String(string.prefix(120)))
            case .number, .bool:
                cleanValue = value
            }
            return (cleanKey, cleanValue)
        })
    }

    private func readState() -> TelemetryState {
        do {
            let data = try Data(contentsOf: stateURL)
            return try decoder.decode(TelemetryState.self, from: data)
        } catch {
            return TelemetryState(anonymousId: UUID().uuidString, installedTracked: false)
        }
    }

    private func writeState(_ state: TelemetryState) {
        do {
            try FileManager.default.createDirectory(
                at: stateURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(state)
            try data.write(to: stateURL, options: [.atomic])
        } catch {
            return
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
    }
}
