// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AgentWatchCore",
    platforms: [
        .macOS(.v14),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "AgentWatchCore", targets: ["AgentWatchCore"]),
    ],
    targets: [
        .target(
            name: "AgentWatchCore",
            path: "Sources/AgentWatchCore"
        ),
        .testTarget(
            name: "AgentWatchCoreTests",
            dependencies: ["AgentWatchCore"],
            path: "Tests/AgentWatchCoreTests"
        ),
    ]
)
