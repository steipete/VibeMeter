import Foundation

/// Represents the different update channels available for VibeMeter.
///
/// Update channels determine which types of releases the user will receive:
/// - `stable`: Only stable releases (recommended for most users)
/// - `prerelease`: Beta versions and pre-releases in addition to stable releases
public enum UpdateChannel: String, CaseIterable, Identifiable, Sendable {
    case stable = "stable"
    case prerelease = "prerelease"
    
    public var id: String { rawValue }
    
    /// Human-readable display name for the update channel
    public var displayName: String {
        switch self {
        case .stable:
            return "Stable"
        case .prerelease:
            return "Pre-release"
        }
    }
    
    /// Description of what the update channel provides
    public var description: String {
        switch self {
        case .stable:
            return "Only receive stable releases (recommended)"
        case .prerelease:
            return "Receive beta versions and pre-releases for early access to new features"
        }
    }
    
    /// The appcast URL for this update channel
    public var appcastURL: String {
        let baseURL = "https://raw.githubusercontent.com/steipete/VibeMeter/main"
        switch self {
        case .stable:
            return "\(baseURL)/appcast.xml"
        case .prerelease:
            return "\(baseURL)/appcast-prerelease.xml"
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