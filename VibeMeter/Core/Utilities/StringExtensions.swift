import Foundation

/// String extension providing utility methods for text manipulation and formatting.
///
/// This extension adds convenience methods for string operations commonly used throughout
/// the application, including trimming whitespace and checking for empty content.
extension String {
    func truncate(length: Int, trailing: String = "...") -> String {
        // Handle zero or negative length
        if length <= 0 {
            return ""
        }

        // If string is already short enough, return as-is
        if count <= length {
            return self
        }

        // If trailing is longer than or equal to the allowed length, return just trailing (or truncated trailing)
        if trailing.count >= length {
            return String(trailing.prefix(length))
        }

        // Normal case: truncate string and add trailing
        let truncateLength = length - trailing.count

        // Handle edge case where truncateLength is 0 or negative
        if truncateLength <= 0 {
            return trailing
        }

        // Use unicodeScalars for more predictable behavior with special characters
        let truncated = String(prefix(truncateLength))
        return truncated + trailing
    }

    /// Returns a truncated string with the specified maximum length, including the trailing string.
    /// Unlike `truncate(length:trailing:)`, this method ensures the total length (including trailing) doesn't exceed
    /// the specified length.
    func truncated(to maxLength: Int, trailing: String = "...") -> String {
        // Handle zero or negative length
        if maxLength <= 0 {
            return ""
        }

        // If string is already short enough, return as-is
        if count <= maxLength {
            return self
        }

        // If maxLength is too small to fit any content + trailing, return just trailing truncated to maxLength
        if maxLength <= trailing.count {
            return String(trailing.prefix(maxLength))
        }

        // Calculate how much of the original string we can keep
        let prefixLength = maxLength - trailing.count

        // Return the truncated string with trailing
        return String(prefix(prefixLength)) + trailing
    }
}
