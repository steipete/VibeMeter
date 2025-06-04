import Foundation

/// Represents the available update channels for the application.
///
/// This enum defines the different update channels that users can choose from,
/// allowing them to receive either stable releases only or include pre-release versions.
public enum UpdateChannel: String, CaseIterable, Codable, Sendable {
    case stable = "stable"
    case prerelease = "prerelease"
    
    /// Human-readable display name for the update channel
    public var displayName: String {
        switch self {
        case .stable:
            return "Stable Only"
        case .prerelease:
            return "Include Pre-releases"
        }
    }
    
    /// Detailed description of what each channel includes
    public var description: String {
        switch self {
        case .stable:
            return "Receive only stable, production-ready releases"
        case .prerelease:
            return "Receive both stable releases and beta/pre-release versions"
        }
    }
    
    /// The Sparkle appcast URL for this update channel
    public var appcastURL: String {
        switch self {
        case .stable:
            return "https://raw.githubusercontent.com/steipete/VibeMeter/main/appcast.xml"
        case .prerelease:
            return "https://raw.githubusercontent.com/steipete/VibeMeter/main/appcast-prerelease.xml"
        }
    }
    
    /// Whether this channel includes pre-release versions
    public var includesPreReleases: Bool {
        switch self {
        case .stable:
            return false
        case .prerelease:
            return true
        }
    }
    
    /// Determines if the current app version suggests this channel should be default
    public static func defaultChannel(for appVersion: String) -> UpdateChannel {
        // If the current version contains beta, alpha, or rc, default to prerelease
        let prereleaseKeywords = ["beta", "alpha", "rc", "pre", "dev"]
        let lowercaseVersion = appVersion.lowercased()

        for keyword in prereleaseKeywords {
            if lowercaseVersion.contains(keyword) {
                return .prerelease
            }
        }

        return .stable
    }
}

// MARK: - Identifiable Conformance

extension UpdateChannel: Identifiable {
    public var id: String { rawValue }
}
