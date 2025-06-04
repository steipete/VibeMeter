import ProjectDescription

let project = Project(
    name: "VibeMeter",
    organizationName: "Peter Steinberger",
    options: .options(
        defaultKnownRegions: ["en"],
        developmentRegion: "en"),
    packages: [
        .remote(url: "https://github.com/apple/swift-log.git", requirement: .upToNextMajor(from: "1.6.1")),
        .remote(
            url: "https://github.com/kishikawakatsumi/KeychainAccess.git",
            requirement: .upToNextMajor(from: "4.0.0")),
        .remote(url: "https://github.com/sparkle-project/Sparkle.git", requirement: .upToNextMajor(from: "2.0.0")),
    ],
    settings: .settings(
        base: [
            "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
            "COMBINE_HIDPI_IMAGES": true,
            "CURRENT_PROJECT_VERSION": "1",
            "CODE_SIGN_STYLE": "Automatic",
            "DEVELOPMENT_TEAM": "Y5PE65HELJ",
            "ENABLE_HARDENED_RUNTIME": true,
            "ENABLE_USER_SCRIPT_SANDBOXING": true,
            "GENERATE_INFOPLIST_FILE": true,
            "INFOPLIST_KEY_CFBundleDisplayName": "Vibe Meter",
            "INFOPLIST_KEY_LSApplicationCategoryType": "public.app-category.productivity",
            "INFOPLIST_KEY_LSUIElement": true,
            "INFOPLIST_KEY_NSHumanReadableCopyright": "Copyright © 2025 Peter Steinberger",
            "IPHONEOS_DEPLOYMENT_TARGET": "17.0",
            "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/../Frameworks",
            "MACOSX_DEPLOYMENT_TARGET": "15.0",
            "MARKETING_VERSION": "0.9.0",
            "PRODUCT_BUNDLE_IDENTIFIER": "com.steipete.vibemeter",
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "SUPPORTED_PLATFORMS": "macosx",
            "SWIFT_EMIT_LOC_STRINGS": true,
            "SWIFT_VERSION": "6.0",
            "SWIFT_STRICT_CONCURRENCY": "complete",
        ],
        configurations: [
            .debug(
                name: "Debug",
                settings: [
                    "CODE_SIGN_IDENTITY": "Sign to Run Locally",
                    "CODE_SIGN_STYLE": "Automatic",
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": ["DEBUG"],
                    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
                ],
                xcconfig: nil),
            .release(
                name: "Release",
                settings: [
                    "CODE_SIGN_IDENTITY": "Apple Development",
                    "CODE_SIGN_STYLE": "Automatic",
                    "DEVELOPMENT_TEAM": "Y5PE65HELJ",
                    "SWIFT_OPTIMIZATION_LEVEL": "-O",
                ],
                xcconfig: nil),
        ]),
    targets: [
        .target(
            name: "VibeMeter",
            destinations: .macOS,
            product: .app,
            bundleId: "com.steipete.vibemeter",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleShortVersionString": "1.0.0",
                "CFBundleVersion": "1",
                "LSApplicationCategoryType": "public.app-category.productivity",
                "LSUIElement": true,
                "NSSupportsAutomaticTermination": false,
                "NSAppTransportSecurity": [
                    "NSAllowsArbitraryLoads": true,
                ],
                // Sparkle configuration
                "SUFeedURL": "https://raw.githubusercontent.com/steipete/VibeMeter/main/appcast.xml",
                "SUPublicEDKey": "rLg3Mlihl14FWJJpZDg97VRt+CWAbQt7P8DleufK1cY=",
                "SUEnableAutomaticChecks": true,
                "SUAutomaticallyUpdate": false,
                "SUCheckAtStartup": true,
            ]),
            sources: [
                "VibeMeter/App/**/*.swift",
                "VibeMeter/Core/**/*.swift",
                "VibeMeter/Presentation/**/*.swift",
            ],
            resources: [
                .glob(pattern: "VibeMeter/Assets.xcassets", excluding: []),
            ],
            entitlements: .file(path: "VibeMeter/VibeMeter.entitlements"),
            dependencies: [
                .package(product: "Logging"),
                .package(product: "KeychainAccess"),
                .package(product: "Sparkle"),
            ],
            settings: .settings(
                base: [
                    "OTHER_SWIFT_FLAGS": [
                        "-strict-concurrency=complete",
                        "-enable-actor-data-race-checks",
                    ],
                ])),
        .target(
            name: "VibeMeterTests",
            destinations: .macOS,
            product: .unitTests,
            bundleId: "com.steipete.vibemeter.tests",
            deploymentTargets: .macOS("15.0"),
            infoPlist: .default,
            sources: ["VibeMeterTests/**"],
            dependencies: [
                .target(name: "VibeMeter"),
            ],
            settings: .settings(
                base: [
                    "OTHER_SWIFT_FLAGS": [
                        "-strict-concurrency=complete",
                    ],
                ])),
    ])
