// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "audiotap-spike",
    platforms: [.macOS(.v15)],
    targets: [
        .executableTarget(
            name: "audiotap-spike",
            linkerSettings: [
                // A command-line tool has no bundle, so TCC cannot find a usage
                // description. Embedding Info.plist directly in the __TEXT segment
                // is how you give an unbundled binary one.
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Info.plist",
                ])
            ]
        )
    ]
)
