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
        .executableTarget(
            name: "oneMenu",
            dependencies: ["CodexStatusCore"],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "CodexStatusCoreTests",
            dependencies: ["CodexStatusCore"]
        )
    ]
)
