import struct NIOCore.ByteBuffer
import Foundation

public protocol LogFormatter: Sendable {
    func format(logs: [LogContainer]) -> ByteBuffer
    func makeFilename(logs: [LogContainer]) -> String
}

extension LogFormatter where Self == JSONLogFormatter {
    /// Formats the log attachment as a json file.
    /// The filename won't have a `.json` extension and it contains a time in `gregorian` calendar in `UTC`.
    /// Use ``LogFormatter.json(withJSONExtension:calendar:timezone:)`` to customize the behavior.
    public static var json: JSONLogFormatter {
        .json()
    }

    /// Formats the log attachment as a json file.
    /// - Parameters:
    ///   - withJSONExtension: Whether or not to include the `.json` extension in the filename.
    ///   Setting this to true might make the file look bad on Desktop in Discord. Defaults to `false`.
    ///   - timezone: What timezone to use for the date in filenames. Defaults to `UTC`.
    public static func json(
        withJSONExtension: Bool = false,
        calendar: Calendar = .init(identifier: .gregorian),
        timezone: TimeZone = .init(identifier: "UTC")!
    ) -> JSONLogFormatter {
        JSONLogFormatter(
            withJSONExtension: withJSONExtension,
            calendar: calendar,
            timezone: timezone
        )
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
                    fatalError("Unexpected number in 'LogsEncodingContainer'.")
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
    let calendar: Calendar
    let timezone: TimeZone

    public func format(logs: [LogContainer]) -> ByteBuffer {
        let encodingContainer = LogsEncodingContainer(logs)
        let data = try? DiscordGlobalConfiguration.encoder.encode(encodingContainer)
        return ByteBuffer(data: data ?? Data())
    }

    public func makeFilename(logs: [LogContainer]) -> String {
        let date = makeDateString()
        let prefix = "Logs_\(date)"

        if withJSONExtension {
            return "\(prefix).json"
        } else {
            return prefix
        }
    }

    func makeDateString() -> String {
        let comps = calendar.dateComponents(in: timezone, from: Date())

        func doubleDigit(_ int: Int) -> String {
            let description = "\(int)"
            if description.count == 1 {
                return "0\(description)"
            } else {
                return description
            }
        }
        let year = comps.year ?? 0
        let month = doubleDigit(comps.month  ?? 0)
        let day = doubleDigit(comps.day ?? 0)
        let hour = doubleDigit(comps.hour ?? 0)
        let minute = doubleDigit(comps.minute ?? 0)
        let second = doubleDigit(comps.second ?? 0)

        let string = "\(year)-\(month)-\(day)_\(hour)-\(minute)-\(second)"

        return string
    }
}
