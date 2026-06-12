// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MacCleanerPro",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(
            name: "MacCleanerPro",
            targets: ["MacCleanerPro"]
        ),
    ],
    targets: [
        .executableTarget(
            name: "MacCleanerPro",
            path: "Sources",
            resources: [
                .copy("Resources/Logo"),
            ]
        ),
    ]
)