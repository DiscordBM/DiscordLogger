import Logging

public struct LogInfo: Sendable, Codable {
    public let level: Logger.Level
    public let message: String
    public let metadata: [String: String]?

    public init(level: Logger.Level, message: String, metadata: [String: String]) {
        self.level = level
        self.message = message
        self.metadata = metadata.isEmpty ? nil : metadata
    }
}

public struct LogContainer: Sendable, Codable {
    public let number: Int
    public let info: LogInfo

    public init(number: Int, info: LogInfo) {
        self.number = number
        self.info = info
    }
}
