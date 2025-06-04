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
}

// MARK: - Identifiable Conformance

extension UpdateChannel: Identifiable {
    public var id: String { rawValue }
}