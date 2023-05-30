// swift-tools-version: 5.7

import PackageDescription

let package = Package(
    name: "DiscordLogger",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
    ],
    products: [
        .library(
            name: "DiscordLogger",
            targets: ["DiscordLogger"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.49.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.5.2"),
        .package(url: "https://github.com/DiscordBM/DiscordBM.git", from: "1.0.0-beta.62"),
    ],
    targets: [
        .target(
            name: "DiscordLogger",
            dependencies: [
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "DiscordHTTP", package: "DiscordBM"),
                .product(name: "DiscordUtilities", package: "DiscordBM"),
            ]
        ),
        .testTarget(
            name: "DiscordLoggerTests",
            dependencies: ["DiscordLogger"]
        ),
    ]
)
