import Foundation

// MARK: - String Extensions for Menu Bar Components

/// Extensions providing utility methods for string manipulation in menu bar components.
extension String {
    /// Truncates the string to a specified length, adding ellipsis if needed.
    ///
    /// This method is particularly useful for displaying user emails and other
    /// text in constrained menu bar spaces where length needs to be limited.
    ///
    /// - Parameter length: Maximum length of the returned string
    /// - Returns: Truncated string with ellipsis if needed, or original string if shorter
    func truncated(to length: Int) -> String {
        if count > length {
            return String(prefix(length - 3)) + "..."
        }
        return self
    }
}