import CryptoKit
import Foundation
import SwiftUI

/// Lightweight observable data for Gravatar avatar URLs.
///
/// Provides:
/// - Email to Gravatar URL conversion with SHA256 hashing
/// - Configurable image size with retina support
/// - Mystery person fallback for missing avatars
@Observable
@MainActor
public final class GravatarService {
    public static let shared = GravatarService()

    public private(set) var currentAvatarURL: URL?

    private init() {}

    /// Generates a Gravatar URL for the given email address.
    /// - Parameters:
    ///   - email: The email address to generate a Gravatar URL for
    ///   - size: The desired image size in points (will be doubled for retina)
    /// - Returns: A URL for the Gravatar image, or nil if the email is invalid
    public func gravatarURL(for email: String, size: Int = 40) -> URL? {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let inputData = Data(trimmedEmail.utf8)
        let hashed = SHA256.hash(data: inputData)
        let hashString = hashed.map { String(format: "%02x", $0) }.joined()

        // Double the size for retina displays, with overflow protection
        let clampedSize = max(0, min(size, Int.max / 2))
        let retinaSize = clampedSize * 2
        let urlString = "https://www.gravatar.com/avatar/\(hashString)?s=\(retinaSize)&d=mp"

        return URL(string: urlString)
    }

    /// Updates the current avatar URL for the given email.
    public func updateAvatar(for email: String?) {
        if let email {
            currentAvatarURL = gravatarURL(for: email)
        } else {
            currentAvatarURL = nil
        }
    }

    /// Clears the current avatar URL.
    public func clearAvatar() {
        currentAvatarURL = nil
    }
}
