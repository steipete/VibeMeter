import Foundation

/// String extension providing utility methods for text manipulation and formatting.
///
/// This extension adds convenience methods for string operations commonly used throughout
/// the application, including trimming whitespace and checking for empty content.
extension String {
    func truncate(length: Int, trailing: String = "...") -> String {
        if count > length {
            return String(prefix(length)) + trailing
        }
        return self
    }
}
