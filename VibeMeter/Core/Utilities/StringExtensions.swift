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
        return String(prefix(truncateLength)) + trailing
    }
}
