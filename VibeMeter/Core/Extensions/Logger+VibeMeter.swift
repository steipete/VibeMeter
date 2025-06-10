import Foundation
import os

extension Logger {
    /// Creates a VibeMeter logger with the standard subsystem and specified category
    static func vibeMeter(category: String) -> Logger {
        Logger(subsystem: "com.vibemeter", category: category)
    }

    /// Logs an error with a consistent format
    func logError(_ message: String, error: Error) {
        self.error("\(message): \(error.localizedDescription, privacy: .public)")
    }

    /// Logs a network error with additional context
    func logNetworkError(_ message: String, error: Error, url: URL? = nil) {
        if let url {
            self
                .error(
                    "\(message) for \(url.absoluteString, privacy: .public): \(error.localizedDescription, privacy: .public)")
        } else {
            self.logError(message, error: error)
        }
    }

    /// Logs a debug message only in debug builds
    func debugLog(_ message: String) {
        #if DEBUG
            self.debug("\(message, privacy: .public)")
        #endif
    }
}
