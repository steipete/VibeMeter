import Foundation

extension ISO8601DateFormatter {
    /// Standard ISO8601 formatter with internet date time and fractional seconds
    nonisolated(unsafe) static let vibeMeterDefault: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    /// ISO8601 formatter without fractional seconds
    nonisolated(unsafe) static let vibeMeterStandard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}

extension DateFormatter {
    /// Standard date formatter for UI display
    static let vibeMeterDisplay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// Formatter for log file names (yyyy-MM-dd)
    static let vibeMeterLogFile: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
