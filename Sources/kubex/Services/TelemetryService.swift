import Foundation

public typealias TelemetryAttributes = [String: TelemetryValue]

public struct TelemetryEvent: Codable, Sendable {
    public var name: String
    public var timestamp: Date
    public var attributes: TelemetryAttributes

    public init(name: String, timestamp: Date = Date(), attributes: TelemetryAttributes = [:]) {
        self.name = name
        self.timestamp = timestamp
        self.attributes = attributes
    }
}

public enum TelemetryValue: Codable, Sendable {
    case string(String)
    case double(Double)
    case int(Int)
    case bool(Bool)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported telemetry value")
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        }
    }
}

public protocol TelemetryService: Sendable {
    func record(_ event: TelemetryEvent) async
}

public struct NoopTelemetryService: TelemetryService {
    public init() {}
    public func record(_ event: TelemetryEvent) async {}
}

public actor TelemetryLogService: TelemetryService {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let logsDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Kubex", isDirectory: true)
        try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true)
        self.fileURL = logsDirectory.appendingPathComponent("telemetry.jsonl", isDirectory: false)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
    }

    public func record(_ event: TelemetryEvent) async {
        do {
            let data = try encoder.encode(event)
            var line = data
            line.append(0x0A)
            if fileManager.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: line)
                try handle.close()
            } else {
                try line.write(to: fileURL)
            }
        } catch {
            #if DEBUG
            print("Telemetry write failed: \(error)")
            #endif
        }
    }
}
