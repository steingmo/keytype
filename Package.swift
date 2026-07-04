// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KeyType",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "KeyType",
            path: "Sources/KeyType"
        )
    ]
)
