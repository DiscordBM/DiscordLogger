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
        <img src="https://img.shields.io/badge/swift-5.8%20/%205.7-brightgreen.svg" alt="Latest/Minimum Swift Version">
    </a>
</p>

<p align="center">
     🌟 Just a reminder that there is a 🌟 button up there if you liked this project 😅 🌟
</p>

## Discord Logger
`DiscordLogger` is a [swift-log](https://github.com/apple/swift-log) implementation for sending your logs over to a Discord channel.   
It uses [DiscordBM](https://github.com/DiscordBM/DiscordBM) to communicate with Discord.

## Showcase
You can see Vapor community's Penny bot as a showcase of using this library in production. Penny uses `DiscordLogger` to send a selected group of important logs to an internal channel, so maintainers can be easily notified of any problems that might occur to her.    
Penny is available [here](https://github.com/vapor/penny-bot) and you can see `DiscordLogger` being used [here](https://github.com/vapor/penny-bot/blob/main/CODE/Sources/PennyBOT/Penny.swift) .

## How To Use
  
> Make sure you have **Xcode 14.1 or above**. Lower Xcode 14 versions have known issues that cause problems for libraries.    

Make sure you've added [swift-log](https://github.com/apple/swift-log) and [AsyncHTTPClient](https://github.com/swift-server/async-http-client) to your dependancies.
```swift
import DiscordLogger
import Logging
import AsyncHTTPClient

/// Make an `HTTPClient`.
/// If you've already made an `HTTPClient` somewhere else, you should use that instead.
let httpClient = HTTPClient(eventLoopGroupProvider: .createNew)

/// Configure the Discord Logging Manager.
DiscordGlobalConfiguration.logManager = await DiscordLogManager(
    httpClient: httpClient
)

/// Bootstrap the `LoggingSystem`. After this, all your `Logger`s will automagically start using `DiscordLogHandler`.
/// Do not use a `Task { }` to avoid possible bugs.
/// Wait before the `LoggingSystem` is bootstrapped.  
await LoggingSystem.bootstrapWithDiscordLogger(
    /// The webhook address to send the logs to. 
    /// You can easily create a webhook using Discord desktop app with a few clicks.
    /// See https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks
    /// There is a 'Making A Webhook' there.
    address: try .url(<#Your Webhook URL#>),
    makeMainLogHandler: StreamLogHandler.standardOutput(label:metadataProvider:)
)

/// Make sure you haven't called `LoggingSystem.bootstrap` anywhere else, because you can only call it once.
/// For example Vapor's templates use `LoggingSystem.bootstrap` on boot, and you need to remove that.
```
`DiscordLogManager` comes with a ton of useful configuration options.   
Here is an example of a decently-configured `DiscordLogManager`:   
Read `DiscordLogManager.Configuration.init` documentation for full info.

```swift
DiscordGlobalConfiguration.logManager = await DiscordLogManager(
    httpClient: httpClient,
    configuration: .init(
        aliveNotice: .init(
            address: try .url(<#Your Webhook URL#>),
            /// If nil, DiscordLogger will only send 1 "I'm alive" notice, on boot.
            /// If not nil, it will send a "I'm alive" notice every this-amount too. 
            interval: nil,
            message: "I'm Alive! :)",
            color: .blue,
            initialNoticeMention: .user("970723029262942248")
        ),
        mentions: [
            .warning: .role("970723134149918800"),
            .error: .role("970723101044244510"),
            .critical: .role("970723029262942248"),
        ],
        extraMetadata: [.warning, .error, .critical],
        disabledLogLevels: [.debug, .trace], 
        disabledInDebug: true
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
`DiscordLogger` will try to follow Semantic Versioning 2.0.0.

## Contribution & Support
Any contribution is more than welcome. You can find me in [Vapor's Discord server](https://discord.gg/vapor) to discuss your ideas.    
