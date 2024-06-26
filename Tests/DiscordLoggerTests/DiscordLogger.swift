@testable import DiscordLogger
@testable import Logging
import DiscordHTTP
import XCTest

class DiscordLoggerTests: XCTestCase {

    let webhookUrl = "https://discord.com/api/webhooks/1066287437724266536/dSmCyqTEGP1lBnpWJAVU-CgQy4s3GRXpzKIeHs0ApHm62FngQZPn7kgaOyaiZe6E5wl_"
    private var client: FakeDiscordClient!

    override func setUp() {
        client = FakeDiscordClient()
        LoggingSystem.bootstrapInternal(StreamLogHandler.standardOutput(label:))
    }

    /// Tests that:
    /// * Works at all.
    /// * Multiple logs work.
    /// * Metadata works.
    /// * Embed colors work.
    /// * Log-level-roles work.
    /// * Logger only mentions a log's level role once.
    /// * Setting log-level works.
    func testWorks() async throws {
        DiscordGlobalConfiguration.logManager = DiscordLogManager(
            client: self.client,
            configuration: .init(
                frequency: .seconds(5),
                sendFullLogsAsAttachment: .enabled,
                mentions: [
                    .trace: .role("33333333"),
                    .notice: .user("22222222"),
                    .warning: .user("22222222"),
                ]
            )
        )
        let logger = DiscordLogHandler.multiplexLogger(
            label: "test",
            address: try .url(webhookUrl),
            level: .trace,
            makeMainLogHandler: { _, _ in SwiftLogNoOpLogHandler() }
        )
        logger.log(level: .trace, "Testing!")
        /// To make sure logs arrive in order.
        try await Task.sleep(for: .milliseconds(50))
        logger.log(level: .notice, "Testing! 2")
        /// To make sure logs arrive in order.
        try await Task.sleep(for: .milliseconds(50))
        logger.log(level: .notice, "Testing! 3", metadata: ["1": "2"])
        /// To make sure logs arrive in order.
        try await Task.sleep(for: .milliseconds(50))
        logger.log(level: .warning, "Testing! 4")

        let expectation = XCTestExpectation(description: "log")
        await self.client.setExpectation(to: expectation)

        await waitFulfill(for: [expectation], timeout: 6)

        let anyPayload = await self.client.payloads.first
        let payload = try XCTUnwrap(anyPayload as? Payloads.ExecuteWebhook)
        XCTAssertEqual(payload.content, "<@22222222> <@&33333333>")

        let embeds = try XCTUnwrap(payload.embeds)
        if embeds.count != 4 {
            XCTFail("Expected 4 embeds, but found \(embeds.count): \(embeds)")
            return
        }

        do {
            let embed = embeds[0]
            XCTAssertEqual(embed.title, "Testing!")
            let now = Date().timeIntervalSince1970
            let timestamp = embed.timestamp?.date.timeIntervalSince1970 ?? 0
            XCTAssertTrue(((now-10)...(now+10)).contains(timestamp))
            XCTAssertEqual(embed.color, DiscordColor.brown)
            XCTAssertEqual(embed.footer?.text, "test")
            XCTAssertEqual(embed.fields?.count, 0)
        }

        do {
            let embed = embeds[1]
            XCTAssertEqual(embed.title, "Testing! 2")
            let now = Date().timeIntervalSince1970
            let timestamp = embed.timestamp?.date.timeIntervalSince1970 ?? 0
            XCTAssertTrue(((now-10)...(now+10)).contains(timestamp))
            XCTAssertEqual(embed.color, DiscordColor.green)
            XCTAssertEqual(embed.footer?.text, "test")
            XCTAssertEqual(embed.fields?.count, 0)
        }

        do {
            let embed = embeds[2]
            XCTAssertEqual(embed.title, "Testing! 3")
            let now = Date().timeIntervalSince1970
            let timestamp = embed.timestamp?.date.timeIntervalSince1970 ?? 0
            XCTAssertTrue(((now-10)...(now+10)).contains(timestamp))
            XCTAssertEqual(embed.color, DiscordColor.green)
            XCTAssertEqual(embed.footer?.text, "test")
            let fields = try XCTUnwrap(embed.fields)
            XCTAssertEqual(fields.count, 1)

            let field = try XCTUnwrap(fields.first)
            XCTAssertEqual(field.name, "1")
            XCTAssertEqual(field.value, "2")
        }

        do {
            let embed = embeds[3]
            XCTAssertEqual(embed.title, "Testing! 4")
            let now = Date().timeIntervalSince1970
            let timestamp = embed.timestamp?.date.timeIntervalSince1970 ?? 0
            XCTAssertTrue(((now-10)...(now+10)).contains(timestamp))
            XCTAssertEqual(embed.color, DiscordColor.orange)
            XCTAssertEqual(embed.footer?.text, "test")
        }
    }

    func testLoggingAttachments() async throws {
        DiscordGlobalConfiguration.logManager = DiscordLogManager(
            client: self.client,
            configuration: .init(
                frequency: .milliseconds(100),
                sendFullLogsAsAttachment: .enabled(
                    formatter: .json(
                        withJSONExtension: true,
                        calendar: .init(identifier: .persian),
                        timezone: .init(identifier: "Asia/Tehran")!
                    )
                )
            )
        )
        let logger = DiscordLogHandler.multiplexLogger(
            label: "test",
            address: try .url(webhookUrl),
            makeMainLogHandler: { _, _ in SwiftLogNoOpLogHandler() }
        )

        logger.notice("Log with attachment!", metadata: [
            "metadata1": "value1",
            "metadata2": "value2",
        ])
        logger.info("Another Log With Attachment!")

        let expectation = XCTestExpectation(description: "log")
        await self.client.setExpectation(to: expectation)

        await waitFulfill(for: [expectation], timeout: 6)

        let anyPayload = await self.client.payloads.first
        let payload = try XCTUnwrap(anyPayload as? Payloads.ExecuteWebhook)

        let attachment = try XCTUnwrap(payload.attachments?.first)

        let file = try XCTUnwrap(payload.files?.first)
        XCTAssertGreaterThan(file.data.readableBytes, 10)
        XCTAssertEqual(attachment.filename, file.filename)

        let embeds = try XCTUnwrap(payload.embeds)
        if embeds.count != 2 {
            XCTFail("Expected 2 embeds, but found \(embeds.count): \(embeds)")
            return
        }

        do {
            let embed = embeds[0]
            XCTAssertEqual(embed.title, "Log with attachment!")
            let now = Date().timeIntervalSince1970
            let timestamp = embed.timestamp?.date.timeIntervalSince1970 ?? 0
            XCTAssertTrue(((now-10)...(now+10)).contains(timestamp))
            XCTAssertEqual(embed.color, DiscordColor.green)
            XCTAssertEqual(embed.footer?.text, "test")

            let fields = try XCTUnwrap(embed.fields)
            if fields.count != 2 {
                XCTFail("Expected 2 fields, but found \(fields.count): \(fields)")
                return
            }

            let field1 = fields[0]
            XCTAssertEqual(field1.name, "metadata2")
            XCTAssertEqual(field1.value, "value2")

            let field2 = fields[1]
            XCTAssertEqual(field2.name, "metadata1")
            XCTAssertEqual(field2.value, "value1")
        }

        do {
            let embed = embeds[1]
            XCTAssertEqual(embed.title, "Another Log With Attachment!")
            let now = Date().timeIntervalSince1970
            let timestamp = embed.timestamp?.date.timeIntervalSince1970 ?? 0
            XCTAssertTrue(((now-10)...(now+10)).contains(timestamp))
            XCTAssertEqual(embed.color, DiscordColor.blue)
            XCTAssertEqual(embed.footer?.text, "test")
            XCTAssertEqual(embed.fields?.count, 0)
        }
    }

    func testLoggingAttachmentLimits() async throws {
        DiscordGlobalConfiguration.logManager = DiscordLogManager(
            client: self.client,
            configuration: .init(
                frequency: .milliseconds(100),
                sendFullLogsAsAttachment: .enabled(
                    formatter: .json(
                        withJSONExtension: true,
                        calendar: .init(identifier: .persian),
                        timezone: .init(identifier: "Asia/Tehran")!
                    )
                )
            )
        )
        let logger = DiscordLogHandler.multiplexLogger(
            label: "test",
            address: try .url(webhookUrl),
            makeMainLogHandler: { _, _ in SwiftLogNoOpLogHandler() }
        )

        let mb30 = String(repeating: "a", count: 30_000_000)
        logger.info("\(mb30)")

        let expectation = XCTestExpectation(description: "log")
        await self.client.setExpectation(to: expectation)

        await waitFulfill(for: [expectation], timeout: 6)

        let anyPayload = await self.client.payloads.first
        let payload = try XCTUnwrap(anyPayload as? Payloads.ExecuteWebhook)

        let attachment = try XCTUnwrap(payload.attachments?.first)

        let file = try XCTUnwrap(payload.files?.first)
        XCTAssertEqual(file.data.readableBytes, 24_000_000)
        XCTAssertEqual(attachment.filename, file.filename)
    }

    func testExcludeMetadata() async throws {
        DiscordGlobalConfiguration.logManager = DiscordLogManager(
            client: self.client,
            configuration: .init(
                frequency: .milliseconds(100),
                excludeMetadata: [.trace]
            )
        )
        let logger = DiscordLogHandler.multiplexLogger(
            label: "test",
            address: try .url(webhookUrl),
            level: .trace,
            makeMainLogHandler: { _, _ in SwiftLogNoOpLogHandler() }
        )
        logger.log(level: .trace, "Testing!", metadata: ["a": "b"])

        let expectation = XCTestExpectation(description: "log")
        await self.client.setExpectation(to: expectation)
        await waitFulfill(for: [expectation], timeout: 2)

        let anyPayload = await self.client.payloads.first
        let payload = try XCTUnwrap(anyPayload as? Payloads.ExecuteWebhook)

        let embeds = try XCTUnwrap(payload.embeds)
        XCTAssertEqual(embeds.count, 1)

        let embed = try XCTUnwrap(embeds.first)
        XCTAssertEqual(embed.fields?.count ?? 0, 0)
    }

    func testDisabledLogLevels() async throws {
        DiscordGlobalConfiguration.logManager = DiscordLogManager(
            client: self.client,
            configuration: .init(
                frequency: .milliseconds(100),
                disabledLogLevels: [.debug]
            )
        )
        let logger = DiscordLogHandler.multiplexLogger(
            label: "test",
            address: try .url(webhookUrl),
            level: .debug,
            makeMainLogHandler: { _, _ in SwiftLogNoOpLogHandler() }
        )
        logger.log(level: .debug, "Testing!")
        logger.log(level: .info, "Testing! 2")

        let expectation = XCTestExpectation(description: "log")
        await self.client.setExpectation(to: expectation)
        await waitFulfill(for: [expectation], timeout: 2)

        let anyPayload = await self.client.payloads.first
        let payload = try XCTUnwrap(anyPayload as? Payloads.ExecuteWebhook)

        let embeds = try XCTUnwrap(payload.embeds)
        XCTAssertEqual(embeds.count, 1)

        let embed = try XCTUnwrap(embeds.first)
        XCTAssertEqual(embed.title, "Testing! 2")
    }

    func testMaxStoredLogsCount() async throws {
        DiscordGlobalConfiguration.logManager = DiscordLogManager(
            client: self.client,
            configuration: .init(
                frequency: .seconds(10),
                maxStoredLogsCount: 100
            )
        )
        let address = try WebhookAddress.url(webhookUrl)
        let logger = DiscordLogHandler.multiplexLogger(
            label: "test",
            address: address,
            level: .error,
            makeMainLogHandler: { _, _ in SwiftLogNoOpLogHandler() }
        )
        for idx in (0..<150) {
            /// To keep the order.
            try await Task.sleep(for: .milliseconds(50))
            logger.log(level: .error, "Testing! \(idx)")
        }

        let logs = await DiscordGlobalConfiguration.logManager._tests_getLogs()
        let all = try XCTUnwrap(logs[address])

        XCTAssertEqual(all.count, 100)
        for (idx, one) in all.enumerated() {
            let title = try XCTUnwrap(one.embed.title)
            let number = Int(title.split(separator: " ").last!)!
            XCTAssertGreaterThan(number, idx + 35)
        }
    }

    func testDisabledInDebug() async throws {
        DiscordGlobalConfiguration.logManager = DiscordLogManager(
            client: self.client,
            configuration: .init(
                frequency: .milliseconds(100),
                disabledInDebug: true
            )
        )
        let address = try WebhookAddress.url(webhookUrl)
        let logger = DiscordLogHandler.multiplexLogger(
            label: "test",
            address: address,
            level: .info,
            makeMainLogHandler: { _, _ in SwiftLogNoOpLogHandler() }
        )
        logger.log(level: .info, "Testing!")

        try await Task.sleep(for: .seconds(2))

        let payloads = await self.client.payloads
        XCTAssertEqual(payloads.count, 0)
    }

    func testExtraMetadata_noticeLevel() async throws {
        DiscordGlobalConfiguration.logManager = DiscordLogManager(
            client: self.client,
            configuration: .init(
                frequency: .milliseconds(100),
                extraMetadata: [.info]
            )
        )
        let logger = DiscordLogHandler.multiplexLogger(
            label: "test",
            address: try .url(webhookUrl),
            level: .info,
            makeMainLogHandler: { _, _ in SwiftLogNoOpLogHandler() }
        )
        logger.log(level: .info, "Testing!")

        let expectation = XCTestExpectation(description: "log")
        await self.client.setExpectation(to: expectation)
        await waitFulfill(for: [expectation], timeout: 2)

        let anyPayload = await self.client.payloads.first
        let payload = try XCTUnwrap(anyPayload as? Payloads.ExecuteWebhook)

        let embeds = try XCTUnwrap(payload.embeds)
        XCTAssertEqual(embeds.count, 1)

        let embed = try XCTUnwrap(embeds.first)
        XCTAssertEqual(embed.title, "Testing!")
        let fields = try XCTUnwrap(embed.fields)
        XCTAssertEqual(fields.count, 4)
        XCTAssertEqual(fields[0].name, #"\_source"#)
        XCTAssertEqual(fields[0].value, "DiscordLoggerTests")
        XCTAssertEqual(fields[1].name, #"\_line"#)
        XCTAssertGreaterThan(Int(fields[1].value) ?? 0, 200)
        XCTAssertEqual(fields[2].name, #"\_function"#)
        XCTAssertEqual(fields[2].value, #"testExtraMetadata\_noticeLevel()"#)
        XCTAssertEqual(fields[3].name, #"\_file"#)
        XCTAssertEqual(fields[3].value, "DiscordLoggerTests/DiscordLogger.swift")
    }

    func testExtraMetadata_warningLevel() async throws {
        DiscordGlobalConfiguration.logManager = DiscordLogManager(
            client: self.client,
            configuration: .init(
                frequency: .milliseconds(100),
                extraMetadata: [.warning]
            )
        )
        let logger = DiscordLogHandler.multiplexLogger(
            label: "test",
            address: try .url(webhookUrl),
            level: .notice,
            makeMainLogHandler: { _, _ in SwiftLogNoOpLogHandler() }
        )
        logger.log(level: .warning, "Testing!")

        let expectation = XCTestExpectation(description: "log")
        await self.client.setExpectation(to: expectation)
        await waitFulfill(for: [expectation], timeout: 2)

        let anyPayload = await self.client.payloads.first
        let payload = try XCTUnwrap(anyPayload as? Payloads.ExecuteWebhook)

        let embeds = try XCTUnwrap(payload.embeds)
        XCTAssertEqual(embeds.count, 1)

        let embed = try XCTUnwrap(embeds.first)
        XCTAssertEqual(embed.title, "Testing!")
        let fields = try XCTUnwrap(embed.fields)
        if fields.count != 4 {
            XCTFail("Expected 4 fields but found \(fields.count): \(fields)")
            return
        }
        XCTAssertEqual(fields[0].name, #"\_source"#)
        XCTAssertEqual(fields[0].value, "DiscordLoggerTests")
        XCTAssertEqual(fields[1].name, #"\_line"#)
        XCTAssertGreaterThan(Int(fields[1].value) ?? 0, 200)
        XCTAssertEqual(fields[2].name, #"\_function"#)
        XCTAssertEqual(fields[2].value, #"testExtraMetadata\_warningLevel()"#)
        XCTAssertEqual(fields[3].name, #"\_file"#)
        XCTAssertEqual(fields[3].value, "DiscordLoggerTests/DiscordLogger.swift")
    }

    func testAliveNotices() async throws {
        DiscordGlobalConfiguration.logManager = DiscordLogManager(
            client: self.client,
            configuration: .init(
                frequency: .seconds(1),
                aliveNotice: .init(
                    address: try .url(webhookUrl),
                    interval: .seconds(6),
                    message: "Alive!",
                    color: .red,
                    initialNoticeMention: .role("99999999")
                ),
                mentions: [.critical: .role("99999999")]
            )
        )

        let start = Date().timeIntervalSince1970

        let logger = DiscordLogHandler.multiplexLogger(
            label: "test",
            address: try .url(webhookUrl),
            level: .debug,
            makeMainLogHandler: { _, _ in SwiftLogNoOpLogHandler() }
        )

        /// To make sure the "Alive Notice" goes first
        try await Task.sleep(for: .milliseconds(800))

        logger.log(level: .critical, "Testing! 1")

        try await Task.sleep(for: .seconds(2))

        logger.log(level: .debug, "Testing! 2")

        try await Task.sleep(for: .seconds(2))

        let expectation = XCTestExpectation(description: "log")
        await self.client.setExpectation(to: expectation)
        await waitFulfill(for: [expectation], timeout: 10)

        let _payloads = await self.client.payloads
        let payloads = try XCTUnwrap(_payloads as? [Payloads.ExecuteWebhook])
        if payloads.count != 3 {
            XCTFail("Expected 3 payloads, but found \(payloads.count): \(payloads)")
            return
        }

        let tolerance = 1.25

        do {
            let payload = payloads[0]
            XCTAssertEqual(payload.content, "<@&99999999>")

            let embeds = try XCTUnwrap(payload.embeds)
            XCTAssertEqual(embeds.count, 2)

            do {
                let embed = try XCTUnwrap(embeds.first)
                XCTAssertEqual(embed.title, "Alive!")
                let timestamp = try XCTUnwrap(embed.timestamp?.date.timeIntervalSince1970)
                let range = (start-tolerance)...(start+tolerance)
                XCTAssertTrue(range.contains(timestamp), "\(range) did not contain \(timestamp)")
            }

            do {
                let embed = try XCTUnwrap(embeds.last)
                XCTAssertEqual(embed.title, "Testing! 1")
                let timestamp = try XCTUnwrap(embed.timestamp?.date.timeIntervalSince1970)
                let range = (start-tolerance)...(start+tolerance)
                XCTAssertTrue(range.contains(timestamp), "\(range) did not contain \(timestamp)")
            }
        }

        do {
            let payload = payloads[1]
            XCTAssertEqual(payload.content, "")

            let embeds = try XCTUnwrap(payload.embeds)
            XCTAssertEqual(embeds.count, 1)

            let embed = try XCTUnwrap(embeds.first)
            XCTAssertEqual(embed.title, "Testing! 2")
            let timestamp = try XCTUnwrap(embed.timestamp?.date.timeIntervalSince1970)
            let estimate = start + 4
            let range = (estimate-tolerance)...(estimate+tolerance)
            XCTAssertTrue(range.contains(timestamp), "\(range) did not contain \(timestamp)")
        }

        do {
            let payload = payloads[2]
            XCTAssertEqual(payload.content, "")

            let embeds = try XCTUnwrap(payload.embeds)
            XCTAssertEqual(embeds.count, 1)

            let embed = try XCTUnwrap(embeds.first)
            XCTAssertEqual(embed.title, "Alive!")
            let timestamp = try XCTUnwrap(embed.timestamp?.date.timeIntervalSince1970)
            let estimate = start + 10
            let range = (estimate-tolerance)...(estimate+tolerance)
            XCTAssertTrue(range.contains(timestamp), "\(range) did not contain \(timestamp)")
        }
    }

    func testFrequency() async throws {
        DiscordGlobalConfiguration.logManager = DiscordLogManager(
            client: self.client,
            configuration: .init(frequency: .seconds(5))
        )

        let logger = DiscordLogHandler.multiplexLogger(
            label: "test",
            address: try .url(webhookUrl),
            level: .debug,
            makeMainLogHandler: { _, _ in SwiftLogNoOpLogHandler() }
        )

        do {
            logger.log(level: .critical, "Testing! 0")

            try await Task.sleep(for: .milliseconds(1_150))

            logger.log(level: .critical, "Testing! 1")

            try await Task.sleep(for: .milliseconds(1_150))

            logger.log(level: .critical, "Testing! 2")

            try await Task.sleep(for: .milliseconds(1_150))

            logger.log(level: .critical, "Testing! 3")

            let expectation = XCTestExpectation(description: "log-1")
            await self.client.setExpectation(to: expectation)

            await waitFulfill(for: [expectation], timeout: 3)

            let payloads = await self.client.payloads
            /// Due to the `frequency`, we only should have 1 payload, which contains 4 embeds.
            XCTAssertEqual(payloads.count, 1)
            let anyPayload = payloads[0]
            let payload = try XCTUnwrap(anyPayload as? Payloads.ExecuteWebhook)

            let embeds = try XCTUnwrap(payload.embeds)
            XCTAssertEqual(embeds.count, 4)

            for idx in 0..<4 {
                let title = try XCTUnwrap(embeds[idx].title)
                XCTAssertTrue(title.hasSuffix("\(idx)"), "\(title) did not have suffix \(idx)")
            }

            await self.client.discardPayloads()
        }

        do {
            logger.log(level: .debug, "Testing! 4")

            try await Task.sleep(for: .milliseconds(1_150))

            logger.log(level: .debug, "Testing! 5")

            try await Task.sleep(for: .milliseconds(1_150))

            logger.log(level: .debug, "Testing! 6")

            try await Task.sleep(for: .milliseconds(1_150))

            logger.log(level: .debug, "Testing! 7")

            let expectation = XCTestExpectation(description: "log-2")
            await self.client.setExpectation(to: expectation)

            await waitFulfill(for: [expectation], timeout: 3)

            let payloads = await self.client.payloads
            /// Due to the `frequency`, we only should have 1 payload, which contains 4 embeds.
            XCTAssertEqual(payloads.count, 1)
            let anyPayload = try XCTUnwrap(payloads.first)
            let payload = try XCTUnwrap(anyPayload as? Payloads.ExecuteWebhook)

            let embeds = try XCTUnwrap(payload.embeds)
            XCTAssertEqual(embeds.count, 4)

            for idx in 0..<4 {
                let title = try XCTUnwrap(embeds[idx].title)
                let num = idx + 4
                XCTAssertTrue(title.hasSuffix("\(num)"), "\(title) did not have suffix \(num)")
            }
        }
    }

    /// This tests worst-case scenario of having too much text in the logs.
    func testDoesNotExceedDiscordLengthLimits() async throws {
        DiscordGlobalConfiguration.logManager = DiscordLogManager(
            client: self.client,
            configuration: .init(frequency: .seconds(3600))
        )

        let chars = #"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789\_*"#.map { $0 }
        func longString() -> String {
            String((0..<6_500).map { _ in chars[chars.indices.randomElement()!] })
        }

        let address = try WebhookAddress.url(webhookUrl)
        let logger = DiscordLogHandler.multiplexLogger(
            label: longString(),
            address: address,
            level: .trace,
            makeMainLogHandler: { _, _ in SwiftLogNoOpLogHandler() }
        )

        func randomLevel() -> Logger.Level { Logger.Level.allCases.randomElement()! }
        func longMessage() -> Logger.Message {
            .init(stringLiteral: longString())
        }
        func longMetadata() -> Logger.Metadata {
            .init(uniqueKeysWithValues: (0..<50).map { _ in
                (longString(), Logger.MetadataValue.string(longString()))
            })
        }

        /// Wait for the log-manager to start basically.
        try await Task.sleep(for: .seconds(2))

        for _ in 0..<30 {
            logger.log(level: randomLevel(), longMessage(), metadata: longMetadata())
        }

        /// To make sure the logs make it to the log-manager's storage.
        try await Task.sleep(for: .seconds(2))

        let all = await DiscordGlobalConfiguration.logManager._tests_getLogs()[address]!
        XCTAssertEqual(all.count, 30)
        for embed in all.map(\.embed) {
            XCTAssertNoThrow(try embed.validate().throw(model: embed))
        }

        let logs = await DiscordGlobalConfiguration.logManager
            ._tests_getMaxAmountOfLogsAndFlush(address: address)
        XCTAssertEqual(logs.count, 1)
        let lengthSum = logs.map(\.embed.contentLength).reduce(into: 0, +=)
        XCTAssertEqual(lengthSum, 5_980)
    }

    func testBootstrap() async throws {
        DiscordGlobalConfiguration.logManager = DiscordLogManager(
            client: self.client,
            configuration: .init(frequency: .milliseconds(100))
        )
        await LoggingSystem.bootstrapWithDiscordLogger(
            address: try .url(webhookUrl),
            level: .error,
            makeMainLogHandler: { _, _ in SwiftLogNoOpLogHandler() }
        )

        let logger = Logger(label: "test2")

        logger.log(level: .error, "Testing!")

        let expectation = XCTestExpectation(description: "log")
        await self.client.setExpectation(to: expectation)
        await waitFulfill(for: [expectation], timeout: 2)

        let anyPayload = await self.client.payloads.first
        let payload = try XCTUnwrap(anyPayload as? Payloads.ExecuteWebhook)

        let embeds = try XCTUnwrap(payload.embeds)
        XCTAssertEqual(embeds.count, 1)

        let embed = try XCTUnwrap(embeds.first)
        XCTAssertEqual(embed.title, "Testing!")
    }

    func testMetadataProviders() async throws {
        DiscordGlobalConfiguration.logManager = DiscordLogManager(
            client: self.client,
            configuration: .init(frequency: .milliseconds(100))
        )

        let simpleTraceIDMetadataProvider = Logger.MetadataProvider {
            guard let traceID = TraceNamespace.simpleTraceID else {
                return [:]
            }
            return ["simple-trace-id": .string(traceID)]
        }

        await LoggingSystem.bootstrapWithDiscordLogger(
            address: try .url(self.webhookUrl),
            metadataProvider: simpleTraceIDMetadataProvider,
            makeMainLogHandler: { _, _ in SwiftLogNoOpLogHandler() }
        )

        let logger = Logger(label: "test")

        TraceNamespace.$simpleTraceID.withValue("1234-5678") {
            logger.log(level: .info, "Testing!")
        }

        let expectation = XCTestExpectation(description: "log")
        await self.client.setExpectation(to: expectation)
        await waitFulfill(for: [expectation], timeout: 2)

        let anyPayload = await self.client.payloads.first
        let payload = try XCTUnwrap(anyPayload as? Payloads.ExecuteWebhook)

        let embeds = try XCTUnwrap(payload.embeds)
        XCTAssertEqual(embeds.count, 1)

        let embed = embeds[0]
        XCTAssertEqual(embed.title, "Testing!")

        let fields = try XCTUnwrap(embed.fields)
        XCTAssertEqual(fields.count, 1)

        let field = try XCTUnwrap(fields.first)
        XCTAssertEqual(field.name, "simple-trace-id")
        XCTAssertEqual(field.value, "1234-5678")
    }
}

private actor FakeDiscordClient: DiscordClient, @unchecked Sendable {

    nonisolated let appId: ApplicationSnowflake? = "11111111"

    var expectation: XCTestExpectation?
    var payloads: [Any] = []

    func setExpectation(to expectation: XCTestExpectation) {
        self.expectation = expectation
    }

    func discardPayloads() {
        self.payloads.removeAll()
    }

    func send(request: DiscordHTTPRequest) async throws -> DiscordHTTPResponse {
        fatalError()
    }

    func send<E: ValidatablePayload & Encodable>(
        request: DiscordHTTPRequest,
        payload: E
    ) async throws -> DiscordHTTPResponse {
        fatalError()
    }

    func sendMultipart<E: ValidatablePayload & MultipartEncodable>(
        request: DiscordHTTPRequest,
        payload: E
    ) async throws -> DiscordHTTPResponse {
        payloads.append(payload)
        expectation?.fulfill()
        expectation = nil
        return DiscordHTTPResponse(host: "discord.com", status: .ok, version: .http1_1)
    }
}

private enum TraceNamespace {
    @TaskLocal static var simpleTraceID: String?
}
