import struct NIOCore.ByteBuffer
import Foundation

public protocol LogFormatter: Sendable {
    func format(logs: [LogContainer]) -> ByteBuffer
    func makeFilename(logs: [LogContainer]) -> String
}

extension LogFormatter where Self == JSONLogFormatter {
    public static var json: any LogFormatter {
        JSONLogFormatter(withJSONExtension: false)
    }

    public static func json(withJSONExtension: Bool = false) -> any LogFormatter {
        JSONLogFormatter(withJSONExtension: withJSONExtension)
    }
}

public struct JSONLogFormatter: LogFormatter {

    private struct LogsEncodingContainer: Encodable {
        let logs: [LogContainer]

        init(_ logs: [LogContainer]) {
            self.logs = logs
        }

        private enum CodingKeys: String, CodingKey {
            case _1 = "1"
            case _2 = "2"
            case _3 = "3"
            case _4 = "4"
            case _5 = "5"
            case _6 = "6"
            case _7 = "7"
            case _8 = "8"
            case _9 = "9"
            case _10 = "10"

            init(int: Int) {
                switch int {
                case 1: self = ._1
                case 2: self = ._2
                case 3: self = ._3
                case 4: self = ._4
                case 5: self = ._5
                case 6: self = ._6
                case 7: self = ._7
                case 8: self = ._8
                case 9: self = ._9
                case 10: self = ._10
                default:
                    fatalError("Unexpected number")
                }
            }
        }

        func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            for log in logs {
                let key = CodingKeys(int: log.number)
                try container.encode(log.info, forKey: key)
            }
        }
    }

    let withJSONExtension: Bool

    public func format(logs: [LogContainer]) -> ByteBuffer {
        let encodingContainer = LogsEncodingContainer(logs)
        let data = try? DiscordGlobalConfiguration.encoder.encode(encodingContainer)
        return ByteBuffer(data: data ?? Data())
    }

    public func makeFilename(logs: [LogContainer]) -> String {
        let date = ISO8601DateFormatter.loggingDefault.string(from: Date())
        let prefix = "Logs-\(date)"
        if withJSONExtension {
            return "\(prefix).json"
        } else {
            return prefix
        }
    }
}

extension ISO8601DateFormatter {
    static let loggingDefault: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = .init(identifier: "UTC")
        return formatter
    }()
}
