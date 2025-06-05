import Foundation

/// Represents the available update channels for the application.
///
/// This enum defines the different update channels that users can choose from,
/// allowing them to receive either stable releases only or include pre-release versions.
public enum UpdateChannel: String, CaseIterable, Codable, Sendable {
    case stable
    case prerelease

    /// Human-readable display name for the update channel
    public var displayName: String {
        switch self {
        case .stable:
            "Stable Only"
        case .prerelease:
            "Include Pre-releases"
        }
    }

    /// Detailed description of what each channel includes
    public var description: String {
        switch self {
        case .stable:
            "Receive only stable, production-ready releases"
        case .prerelease:
            "Receive both stable releases and beta/pre-release versions"
        }
    }

    /// The Sparkle appcast URL for this update channel
    public var appcastURL: String {
        switch self {
        case .stable:
            "https://raw.githubusercontent.com/steipete/VibeMeter/main/appcast.xml"
        case .prerelease:
            "https://raw.githubusercontent.com/steipete/VibeMeter/main/appcast-prerelease.xml"
        }
    }

    /// Whether this channel includes pre-release versions
    public var includesPreReleases: Bool {
        switch self {
        case .stable:
            false
        case .prerelease:
            true
        }
    }

    /// Determines if the current app version suggests this channel should be default
    public static func defaultChannel(for appVersion: String) -> UpdateChannel {
        // First check if this build was marked as a pre-release during build time
        if let isPrereleaseValue = Bundle.main.object(forInfoDictionaryKey: "IS_PRERELEASE_BUILD"),
           let isPrerelease = isPrereleaseValue as? Bool,
           isPrerelease {
            return .prerelease
        }
        
        // Otherwise, check if the version string contains pre-release keywords
        let prereleaseKeywords = ["beta", "alpha", "rc", "pre", "dev"]
        let lowercaseVersion = appVersion.lowercased()

        for keyword in prereleaseKeywords where lowercaseVersion.contains(keyword) {
            return .prerelease
        }

        return .stable
    }
}

// MARK: - Identifiable Conformance

extension UpdateChannel: Identifiable {
    public var id: String { rawValue }
}
