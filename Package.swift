// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Herdry",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "Herdry",
            resources: [.copy("Resources")]
        )
    ]
)
