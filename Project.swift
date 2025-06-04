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
            "CURRENT_PROJECT_VERSION": "201",
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
            "MARKETING_VERSION": "1.0.0-beta.2",
            "PRODUCT_BUNDLE_IDENTIFIER": "com.steipete.vibemeter",
            "PRODUCT_NAME": "$(TARGET_NAME)",
            "SUPPORTED_PLATFORMS": "macosx",
            "SWIFT_EMIT_LOC_STRINGS": true,
            "SWIFT_VERSION": "6.0",
            "SWIFT_STRICT_CONCURRENCY": "complete",
            // Enhanced code quality and strictness settings
            "CLANG_ANALYZER_LOCALIZABILITY_NONLOCALIZED": true,
            "CLANG_WARN_DOCUMENTATION_COMMENTS": true,
            "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": true,
            "CLANG_WARN_UNGUARDED_AVAILABILITY": "YES_AGGRESSIVE",
            "GCC_TREAT_WARNINGS_AS_ERRORS": true,
            "SWIFT_TREAT_WARNINGS_AS_ERRORS": true,
            "WARNING_CFLAGS": ["-Wall", "-Wextra"],
            "CLANG_WARN_SUSPICIOUS_IMPLICIT_CONVERSION": true,
            "CLANG_WARN_EMPTY_BODY": true,
            "CLANG_WARN_CONDITIONAL_UNINITIALIZED": true,
            "GCC_WARN_UNUSED_FUNCTION": true,
            "GCC_WARN_UNUSED_VARIABLE": true,
            "CLANG_WARN_UNREACHABLE_CODE": true,
            "ENABLE_STRICT_OBJC_MSGSEND": true,
        ],
        configurations: [
            .debug(
                name: "Debug",
                settings: [
                    "CODE_SIGN_IDENTITY": "Sign to Run Locally",
                    "CODE_SIGN_STYLE": "Automatic",
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": ["DEBUG"],
                    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
                    // Less strict for development
                    "GCC_TREAT_WARNINGS_AS_ERRORS": false,
                    "SWIFT_TREAT_WARNINGS_AS_ERRORS": false,
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
                "CFBundleShortVersionString": "1.0-beta.2",
                "CFBundleVersion": "2",
                "LSApplicationCategoryType": "public.app-category.productivity",
                "LSUIElement": true,
                "NSSupportsAutomaticTermination": false,
                "NSAppTransportSecurity": [
                    "NSAllowsArbitraryLoads": true,
                ],
                // Sparkle configuration
                "SUFeedURL": "https://raw.githubusercontent.com/steipete/VibeMeter/main/appcast-prerelease.xml",
                "SUPublicEDKey": "oIgha2beQWnyCXgOIlB8+oaUzFNtWgkqq6jKXNNDhv4=",
                "SUEnableAutomaticChecks": true,
                "SUAutomaticallyUpdate": false,
                "SUCheckAtStartup": true,
                "SUEnableInstallerLauncherService": true,
                "SUEnableDownloaderService": true,
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
                        "-warn-concurrency",
                        "-enable-bare-slash-regex",
                        "-warn-implicit-overrides",
                        "-Xfrontend", "-warn-long-function-bodies=500",
                        "-Xfrontend", "-warn-long-expression-type-checking=500",
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
                        "-warn-concurrency",
                        "-enable-bare-slash-regex",
                        "-warn-implicit-overrides",
                    ],
                ])),
    ])
