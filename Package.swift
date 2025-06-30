// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VibeMeter",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(
            name: "VibeMeter",
            targets: ["VibeMeter"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.1"),
        .package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.0.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        .package(url: "https://github.com/nalexn/ViewInspector.git", from: "0.9.0")
    ],
    targets: [
        .target(
            name: "VibeMeter",
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "KeychainAccess", package: "KeychainAccess"),
                .product(name: "Sparkle", package: "Sparkle")
            ],
            path: "VibeMeter",
            exclude: [
                "Info.plist",
                "VibeMeter.entitlements",
                "Assets.xcassets",
                "Shared.xcconfig",
                "Debug.xcconfig", 
                "Release.xcconfig",
                "version.xcconfig",
                "sparkle-public-ed-key.txt"
            ],
            resources: [
                .process("Core/Utilities/Tiktoken")
            ]
        ),
        .testTarget(
            name: "VibeMeterTests",
            dependencies: [
                "VibeMeter",
                .product(name: "ViewInspector", package: "ViewInspector")
            ],
            path: "VibeMeterTests"
        )
    ]
)