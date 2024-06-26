import DiscordHTTP
import DiscordModels
import DiscordUtilities
import AsyncHTTPClient
import NIOCore
import Logging
import Foundation

/// The manager of sending logs to Discord.
public actor DiscordLogManager {
    
    public struct Configuration: Sendable {
        
        public struct AliveNotice: Sendable {
            let address: WebhookAddress
            let interval: Duration?
            let message: String
            let color: DiscordColor
            let initialNoticeMentions: [String]
            
            /// - Parameters:
            ///   - address: The address to send the logs to.
            ///   - interval: The interval after which to send an alive notice. If set to nil, log-manager will only send 1 alive notice on startup.
            ///   - message: The message to accompany the notice.
            ///   - color: The color of the embed of alive notices.
            ///   - initialNoticeMention: The user/role to be mentioned on the first alive notice.
            ///   Useful to be notified of app-boots when you update your app or when it crashes.
            public init(
                address: WebhookAddress,
                interval: Duration?,
                message: String = "Alive Notice!",
                color: DiscordColor = .blue,
                initialNoticeMention: Mention
            ) {
                self.address = address
                self.interval = interval
                self.message = message
                self.color = color
                self.initialNoticeMentions = initialNoticeMention.toMentionStrings()
            }
        }
        
        /// ID of a user or a role to be mentioned.
        public enum Mention {
            case user(UserSnowflake)
            case role(RoleSnowflake)
            case combined([Mention])
            
            public static func combined(_ mentions: Mention...) -> Mention {
                .combined(mentions)
            }
            
            func toMentionStrings() -> [String] {
                switch self {
                case let .user(id):
                    return [DiscordUtils.mention(id: id)]
                case let .role(id):
                    return [DiscordUtils.mention(id: id)]
                case let .combined(mentions):
                    return mentions.flatMap { $0.toMentionStrings() }
                }
            }
        }

        public enum LogAttachmentPolicy: Sendable {
            case disabled
            /// Use ``enabled(formatter:)`` for better type-inference by compiler.
            /// Otherwise you can use this too.
            case enabled(_formatter: any LogFormatter = .json)

            /// Enable the log attachments.
            public static var enabled: Self {
                .enabled(formatter: .json)
            }

            /// Enable the log attachments.
            ///
            /// To enable compiler-helps with `LogFormatter`-extension inferences like `.json`.
            /// Uses `some LogFormatter` instead of `any LogFormatter` for this reason.
            ///
            /// https://github.com/apple/swift/issues/68269
            public static func enabled(formatter: some LogFormatter = .json) -> Self {
                .enabled(_formatter: formatter)
            }

            var formatter: (any LogFormatter)? {
                switch self {
                case .disabled:
                    return nil
                case .enabled(let formatter):
                    return formatter
                }
            }

            var isDisabled: Bool {
                switch self {
                case .disabled:
                    return true
                case .enabled:
                    return false
                }
            }
        }

        let frequency: Duration
        let aliveNotice: AliveNotice?
        let sendFullLogsAsAttachment: LogAttachmentPolicy
        let mentions: [Logger.Level: [String]]
        let colors: [Logger.Level: DiscordColor]
        let excludeMetadata: Set<Logger.Level>
        let extraMetadata: Set<Logger.Level>
        let disabledLogLevels: Set<Logger.Level>
        let disabledInDebug: Bool
        let maxStoredLogsCount: Int
        
        /// - Parameters:
        ///   - frequency: The frequency of the log-sendings. e.g. if its set to 30s, logs will only be sent once-in-30s. Should not be lower than 10s, because of Discord rate-limits.
        ///   - aliveNotice: Configuration for sending "I am alive" messages every once in a while. Note that alive notices are delayed until it's been `interval`-time past last message.
        ///   e.g. `Logger(label: "Fallback", factory: StreamLogHandler.standardOutput(label:))`
        ///   - sendFullLogsAsAttachment: Whether or not to send the full log as an attachment.
        ///   The normal logs might need to truncate some stuff when sending as embeds, due to Discord limits.
        ///   - mentions: ID of users/roles to be mentioned for each log-level.
        ///   - colors: Color of the embeds to be used for each log-level.
        ///   - excludeMetadata: Excludes all metadata for these log-levels.
        ///   - extraMetadata: Will log `source`, `file`, `function` and `line` as well.
        ///   - disabledLogLevels: `Logger.Level`s to never be logged.
        ///   - disabledInDebug: Whether or not to disable logging in DEBUG.
        ///   - maxStoredLogsCount: If there are more logs than this count, the log manager will start removing the oldest un-sent logs to reduce memory consumption.
        public init(
            frequency: Duration = .seconds(10),
            aliveNotice: AliveNotice? = nil,
            sendFullLogsAsAttachment: LogAttachmentPolicy = .disabled,
            mentions: [Logger.Level: Mention] = [:],
            colors: [Logger.Level: DiscordColor] = [
                .critical: .purple,
                .error: .red,
                .warning: .orange,
                .trace: .brown,
                .debug: .yellow,
                .notice: .green,
                .info: .blue,
            ],
            excludeMetadata: Set<Logger.Level> = [],
            extraMetadata: Set<Logger.Level> = [],
            disabledLogLevels: Set<Logger.Level> = [],
            disabledInDebug: Bool = false,
            maxStoredLogsCount: Int = 1_000
        ) {
            self.frequency = frequency
            self.aliveNotice = aliveNotice
            self.sendFullLogsAsAttachment = sendFullLogsAsAttachment
            self.mentions = mentions.mapValues { $0.toMentionStrings() }
            self.colors = colors
            self.excludeMetadata = excludeMetadata
            self.extraMetadata = extraMetadata
            self.disabledLogLevels = disabledLogLevels
            self.disabledInDebug = disabledInDebug
            self.maxStoredLogsCount = maxStoredLogsCount
        }

        /// - Parameters:
        ///   - frequency: The frequency of the log-sendings. e.g. if its set to 30s, logs will only be sent once-in-30s. Should not be lower than 10s, because of Discord rate-limits.
        ///   - aliveNotice: Configuration for sending "I am alive" messages every once in a while. Note that alive notices are delayed until it's been `interval`-time past last message.
        ///   e.g. `Logger(label: "Fallback", factory: StreamLogHandler.standardOutput(label:))`
        ///   - sendFullLogAsAttachment: Whether or not to send the full log as an attachment.
        ///   The normal logs might need to truncate some stuff when sending as embeds, due to Discord limits.
        ///   - mentions: ID of users/roles to be mentioned for each log-level.
        ///   - colors: Color of the embeds to be used for each log-level.
        ///   - excludeMetadata: Excludes all metadata for these log-levels.
        ///   - extraMetadata: Will log `source`, `file`, `function` and `line` as well.
        ///   - disabledLogLevels: `Logger.Level`s to never be logged.
        ///   - disabledInDebug: Whether or not to disable logging in DEBUG.
        ///   - maxStoredLogsCount: If there are more logs than this count, the log manager will start removing the oldest un-sent logs to reduce memory consumption.
        @available(
            *,
             unavailable,
             renamed: "init(frequency:aliveNotice:sendFullLogsAsAttachment:mentions:colors:excludeMetadata:extraMetadata:disabledLogLevels:disabledInDebug:maxStoredLogsCount:)"
        )
        public init(
            frequency: Duration = .seconds(10),
            aliveNotice: AliveNotice? = nil,
            sendFullLogAsAttachment: LogAttachmentPolicy = .disabled,
            mentions: [Logger.Level: Mention] = [:],
            colors: [Logger.Level: DiscordColor] = [
                .critical: .purple,
                .error: .red,
                .warning: .orange,
                .trace: .brown,
                .debug: .yellow,
                .notice: .green,
                .info: .blue,
            ],
            excludeMetadata: Set<Logger.Level> = [],
            extraMetadata: Set<Logger.Level> = [],
            disabledLogLevels: Set<Logger.Level> = [],
            disabledInDebug: Bool = false,
            maxStoredLogsCount: Int = 1_000
        ) {
            fatalError()
        }
    }
    
    struct Log: CustomStringConvertible {
        let embed: Embed
        let attachment: LogInfo?
        let level: Logger.Level?
        let isFirstAliveNotice: Bool
        
        var description: String {
            "DiscordLogManager.Log(" +
            "embed: \(embed), " +
            "level: \(level?.rawValue ?? "nil"), " +
            "isFirstAliveNotice: \(isFirstAliveNotice)" +
            ")"
        }
    }
    
    nonisolated let client: any DiscordClient
    nonisolated let configuration: Configuration
    
    private var logs: [WebhookAddress: [Log]] = [:]
    private var sendLogsTasks: [WebhookAddress: Task<Void, Never>] = [:]
    var fallbackLogger = Logger(label: "DBM.LogManager")
    
    private var aliveNoticeTask: Task<Void, Never>?
    
    public init(
        httpClient: HTTPClient = .shared,
        configuration: Configuration = Configuration()
    ) async {
        /// Will only ever send requests to a webhook endpoint
        /// which doesn't need/use neither `token` nor `appId`.
        self.client = await DefaultDiscordClient(httpClient: httpClient, authentication: .none)
        self.configuration = configuration
        Task { [weak self] in await self?.startAliveNotices() }
    }
    
    public init(
        client: any DiscordClient,
        configuration: Configuration = Configuration()
    ) {
        self.client = client
        self.configuration = configuration
        Task { [weak self] in await self?.startAliveNotices() }
    }
    
    /// To use after logging-system's bootstrap
    /// Or if you want to change it to something else (do it after bootstrap or it'll be overridden)
    public func renewFallbackLogger(to new: Logger? = nil) {
        self.fallbackLogger = new ?? Logger(label: "DBM.LogManager")
    }
    
    func include(
        address: WebhookAddress,
        embed: Embed,
        attachment: LogInfo?,
        level: Logger.Level
    ) {
        self.include(
            address: address,
            embed: embed,
            attachment: attachment,
            level: level,
            isFirstAliveNotice: false
        )
    }
    
    private func include(
        address: WebhookAddress,
        embed: Embed,
        attachment: LogInfo?,
        level: Logger.Level?,
        isFirstAliveNotice: Bool
    ) {
#if DEBUG
        if configuration.disabledInDebug { return }
#endif
        switch self.logs[address]?.isEmpty {
        case .none:
            self.logs[address] = []
            setUpSendLogsTask(address: address)
        case .some(true):
            setUpSendLogsTask(address: address)
        case .some(false): break
        }
        
        self.logs[address]!.append(.init(
            embed: embed,
            attachment: attachment,
            level: level,
            isFirstAliveNotice: isFirstAliveNotice
        ))
        
        if logs[address]!.count > configuration.maxStoredLogsCount {
            logs[address]!.removeFirst()
        }
    }
    
    private func startAliveNotices() {
#if DEBUG
        if configuration.disabledInDebug { return }
#endif
        if let aliveNotice = configuration.aliveNotice {
            self.sendAliveNotice(config: aliveNotice, isFirstNotice: true)
        }
        self.setUpAliveNotices()
    }
    
    private func setUpAliveNotices() {
#if DEBUG
        if configuration.disabledInDebug { return }
#endif
        if let aliveNotice = configuration.aliveNotice,
           let interval = aliveNotice.interval {

            @Sendable func send() async throws {
                try await Task.sleep(for: interval)
                await sendAliveNotice(config: aliveNotice, isFirstNotice: false)
                try await send()
            }
            
            aliveNoticeTask?.cancel()
            aliveNoticeTask = Task { try? await send() }
        }
    }
    
    private func sendAliveNotice(config: Configuration.AliveNotice, isFirstNotice: Bool) {
        self.include(
            address: config.address,
            embed: .init(
                title: config.message,
                timestamp: Date(),
                color: config.color
            ),
            attachment: nil,
            level: nil,
            isFirstAliveNotice: isFirstNotice
        )
    }
    
    private func setUpSendLogsTask(address: WebhookAddress) {
#if DEBUG
        if configuration.disabledInDebug { return }
#endif
        
        @Sendable func send() async throws {
            try await Task.sleep(for: configuration.frequency)
            await performLogSend(address: address)
            try await send()
        }
        
        sendLogsTasks[address]?.cancel()
        sendLogsTasks[address] = Task { try? await send() }
    }
    
    private func performLogSend(address: WebhookAddress) async {
        let logs = getMaxAmountOfLogsAndFlush(address: address)
        if self.logs[address]?.isEmpty != false {
            self.sendLogsTasks[address]?.cancel()
        }
        await sendLogs(logs, address: address)
    }
    
    private func getMaxAmountOfLogsAndFlush(address: WebhookAddress) -> [Log] {
        var goodLogs = [Log]()
        goodLogs.reserveCapacity(min(self.logs.count, 10))
        
        guard var iterator = self.logs[address]?.makeIterator() else { return [] }
        
        func lengthSum() -> Int { goodLogs.map(\.embed.contentLength).reduce(into: 0, +=) }
        
        while goodLogs.count < 10,
              let log = iterator.next(),
              (lengthSum() + log.embed.contentLength) <= 6_000 {
            goodLogs.append(log)
        }
        
        self.logs[address] = Array(self.logs[address]?.dropFirst(goodLogs.count) ?? [])
        
        return goodLogs
    }
    
    private func sendLogs(_ logs: [Log], address: WebhookAddress) async {
        var logLevels = Set(logs.compactMap(\.level))
            .sorted(by: >)
            .compactMap({ configuration.mentions[$0] })
            .flatMap({ $0 })
        let wantsAliveNoticeMention = logs.contains(where: \.isFirstAliveNotice)
        let aliveNoticeMentions = wantsAliveNoticeMention ?
        (self.configuration.aliveNotice?.initialNoticeMentions ?? []) : []
        logLevels.append(contentsOf: aliveNoticeMentions)
        logLevels = Set(logLevels).sorted {
            logLevels.firstIndex(of: $0)! < logLevels.firstIndex(of: $1)!
        }
        let mentions = logLevels.joined(separator: " ")
        
        await sendLogsToWebhook(
            content: mentions,
            logs: logs.map({ ($0.embed, $0.attachment) }),
            address: address
        )
        
        self.setUpAliveNotices()
    }

    private func sendLogsToWebhook(
        content: String,
        logs: [(embed: Embed, attachment: LogInfo?)],
        address: WebhookAddress
    ) async {
        let attachment = makeAttachmentData(attachments: logs.map(\.attachment))

        let payload = Payloads.ExecuteWebhook(
            content: content,
            embeds: logs.map(\.embed),
            files: attachment.map { (name, buffer) in
                [RawFile(data: buffer, filename: name)]
            },
            attachments: attachment.map { (name, _) in 
                [.init(index: 0, filename: name)]
            }
        )
        do {
            try await self.client.executeWebhookWithResponse(
                address: address,
                payload: payload
            ).guardSuccess()
        } catch {
            logWarning("Received error from Discord after sending logs. This might be a library issue. Please report on https://github.com/DiscordBM/DiscordLogger/issues with full context", metadata: [
                "error": .string("\(error)"),
                "payload": .string("\(payload)")
            ])
        }
    }

    private func makeAttachmentData(attachments: [LogInfo?]) -> (name: String, data: ByteBuffer)? {
        if let formatter = self.configuration.sendFullLogsAsAttachment.formatter {
            let attachments: [LogContainer] = attachments
                .enumerated()
                .filter({ $0.element != nil })
                .map({ LogContainer(number: $0.offset + 1, info: $0.element!) })
            if attachments.isEmpty {
                return nil
            } else {
                var buffer = formatter.format(logs: attachments)
                /// Discord has a limit of 25MB of attachments.
                /// 24MB is already too much for 10 logs, so we just truncate the buffer.
                let mb24 = 24_000_000
                if buffer.readableBytes > mb24 {
                    buffer = buffer.getSlice(at: buffer.readerIndex, length: mb24) ?? ByteBuffer(
                        string: "<error-could-not-slice-buffer-please-report-on-github-in-DiscordLogger-repo>"
                    )
                }
                let name = formatter.makeFilename(logs: attachments)
                return (name, buffer)
            }
        } else {
            return nil
        }
    }

    private func logWarning(
        _ message: Logger.Message,
        metadata: Logger.Metadata? = nil,
        function: String = #function,
        line: UInt = #line
    ) {
        self.fallbackLogger.log(
            level: .warning,
            message,
            metadata: metadata,
            source: "DiscordLogger",
            file: #fileID,
            function: function,
            line: line
        )
    }
    
#if DEBUG
    func _tests_getLogs() -> [WebhookAddress: [Log]] {
        self.logs
    }
    
    func _tests_getMaxAmountOfLogsAndFlush(address: WebhookAddress) -> [Log] {
        self.getMaxAmountOfLogsAndFlush(address: address)
    }
#endif
}
