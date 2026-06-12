// swift-tools-version: 6.0

import Foundation
import PackageDescription

// Set MCP_FULL_VERSION=1 in the environment to build the direct-distribution
// "Full" flavor (see Versions/Full/build.sh). Without it, the App Store flavor
// is built (see Versions/AppStore/build.sh).
let isFullVersion = ProcessInfo.processInfo.environment["MCP_FULL_VERSION"] == "1"

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
            ],
            swiftSettings: isFullVersion ? [.define("FULL_VERSION")] : []
        ),
    ]
)