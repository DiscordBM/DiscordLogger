<p align="center">
    <img src="https://user-images.githubusercontent.com/54685446/201329617-9fd91ab0-35c2-42c2-8963-47b68c6a490a.png" alt="DiscordLogger">
    <br>
    <a href="https://github.com/DiscordBM/DiscordLogger/actions/workflows/tests.yml">
        <img src="https://github.com/DiscordBM/DiscordLogger/actions/workflows/tests.yml/badge.svg" alt="Tests Badge">
    </a>
    <a href="https://codecov.io/gh/DiscordBM/DiscordLogger">
        <img src="https://codecov.io/gh/DiscordBM/DiscordLogger/branch/main/graph/badge.svg?token=P4DYX2FWYT" alt="Codecov">
    </a>
    <a href="https://swift.org">
        <img src="https://img.shields.io/badge/swift-5.9%20/%205.10-brightgreen.svg" alt="Latest/Minimum Swift Version">
    </a>
</p>

<p align="center">
     🌟 Just a reminder that there is a 🌟 button up there if you liked this project 😅 🌟
</p>

## Discord Logger
`DiscordLogger` is a [swift-log](https://github.com/apple/swift-log) implementation for sending your logs over to a Discord channel.   
It uses [DiscordBM](https://github.com/DiscordBM/DiscordBM) to communicate with Discord.

## Showcase
Vapor community's [Penny bot](https://github.com/vapor/penny-bot) serves as a good example of [utilizing this library](https://github.com/vapor/penny-bot/blob/acdf26167099858e691c403f8a8660348031d0e0/Sources/Penny/MainService/PennyService.swift#L2).   
Penny uses `DiscordLogger` to send a select group of important logs to an internal channel, making it easy for maintainers to receive notifications about any potential issues.

## How To Use

```swift
import DiscordLogger
import Logging

/// Bootstrap the `LoggingSystem`. After this, all your `Logger`s will automagically start using `DiscordLogHandler`.
/// Do not use a `Task { }` to avoid possible bugs. Wait before the `LoggingSystem` is bootstrapped.  
await LoggingSystem.bootstrapWithDiscordLogger(
    /// The webhook address to send the logs to. 
    /// You can easily create a webhook using Discord desktop app with a few clicks.
    /// See https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks
    /// There is a 'Making A Webhook' section there.
    address: try .url(<#Your Webhook URL#>),
    makeMainLogHandler: StreamLogHandler.standardOutput(label:metadataProvider:)
)

/// Make sure you haven't called `LoggingSystem.bootstrap` anywhere else, because you can only call it once.
/// For example Vapor's templates use `LoggingSystem.bootstrap` on boot, and you need to remove that.
```
`DiscordLogManager` comes with a ton of useful configuration options.   
Here is an example of a decently-configured `DiscordLogManager`:   
> Read `DiscordLogManager.Configuration.init` documentation for full info.

```swift
let mySpecialHTTPClient: HTTPClient = ...

DiscordGlobalConfiguration.logManager = await DiscordLogManager(
    httpClient: mySpecialHTTPClient,
    configuration: .init(
        aliveNotice: .init(
            address: try .url(<#Your Webhook URL#>),
            /// If nil, `DiscordLogManager` will only send 1 "I'm alive" notice, on boot.
            /// If not nil, it will send a "I'm alive" notice every this-amount too, if there is no logging activity. 
            interval: nil,
            message: "I'm Alive! :)",
            color: .blue,
            initialNoticeMention: .user("970723029262942248")
        ),
        sendFullLogsAsAttachment: .enabled,
        mentions: [
            .warning: .role("970723134149918800"),
            .error: .role("970723101044244510"),
            .critical: .role("970723029262942248"),
        ],
        extraMetadata: [.warning, .error, .critical],
        disabledLogLevels: [.debug, .trace], 
        disabledInDebug: false
    )
)
```

#### Example

```swift
/// After bootstrapping the `LoggingSystem`, and with the configuration above, but `extraMetadata` set to `[.critical]`
let logger = Logger(label: "LoggerLabel")
logger.warning("Warning you about something!")
logger.error("We're having an error!", metadata: [
    "number": .stringConvertible(1),
    "statusCode": "401 Unauthorized"
])
logger.critical("CRITICAL PROBLEM. ABOUT TO EXPLODE 💥")
```

<img width="370" alt="DiscordLogger Showcase Output" src="https://user-images.githubusercontent.com/54685446/217464224-1cb6ed75-8683-4977-8bd3-03752d7d7597.png">

> **Note**   
> * `DiscordLogger` is not meant to replace your on-disk logging, as it can be much less consistent due to nature of logging _over the network_ and also _sending messages to Discord_.
> * The library is meant to provide a convenience way of keeping track of your important logs, while still using the usual on-disk logs for full investigations if needed.
> * With Penny, we log everything at `debug`/`trace` level to stdout for AWS to pick up, while setting the `DiscordLogManager` to send the `warning`/`error` and a few `info`/`notice` logs to Discord.
> * This way we are immediately notified of important `error`/`wraning`s, while using the AWS logs for full investigations if needed.

## How To Add DiscordLogger To Your Project

To use the `DiscordLogger` library in a SwiftPM project, 
add the following line to the dependencies in your `Package.swift` file:

```swift
.package(url: "https://github.com/DiscordBM/DiscordLogger", from: "1.0.0-beta.1"),
```

Include `DiscordLogger` as a dependency for your targets:

```swift
.target(name: "<target>", dependencies: [
    .product(name: "DiscordLogger", package: "DiscordLogger"),
]),
```

Finally, add `import DiscordLogger` to your source code.

## Versioning
`DiscordLogger` follows Semantic Versioning 2.0.0.

## Contribution & Support
Any contribution is more than welcome. You can find me in [Vapor's Discord server](https://discord.gg/vapor) to discuss your ideas.    
