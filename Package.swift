// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ClaudeUsageBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeUsageBar",
            path: "Sources/ClaudeUsageBar",
            swiftSettings: [
                // Swift 5 language mode keeps AppKit/SwiftUI callback code
                // free of strict-concurrency noise.
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
