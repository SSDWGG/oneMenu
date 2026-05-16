// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "oneMenu",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "oneMenu", targets: ["oneMenu"])
    ],
    targets: [
        .target(name: "CodexStatusCore"),
        .target(
            name: "SafeNotificationCenter",
            path: "Sources/SafeNotificationCenter"
        ),
        .executableTarget(
            name: "oneMenu",
            dependencies: ["CodexStatusCore", "SafeNotificationCenter"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CodexStatusCoreTests",
            dependencies: ["CodexStatusCore"]
        )
    ]
)
