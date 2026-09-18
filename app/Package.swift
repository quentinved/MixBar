// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MixBar",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "MixBar",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "MixBarTests",
            dependencies: ["MixBar"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
