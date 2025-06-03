import Foundation
import os.log

enum LogCategory: String {
    case general = "General"
    case app = "AppLifecycle"
    case lifecycle = "Lifecycle" // Separate category
    case ui = "UI"
    case login = "Login"
    case api = "API"
    case apiClient = "APIClient" // Keep for compatibility
    case exchangeRate = "ExchangeRate"
    case settings = "Settings"
    case startup = "Startup"
    case notification = "Notification"
    case data = "DataCoordinator"
}

enum LoggingService {
    private static func getLogger(
        category: LogCategory,
        subsystem: String = Bundle.main.bundleIdentifier ?? "com.vibemeter.default") -> Logger {
        Logger(subsystem: subsystem, category: category.rawValue)
    }

    static func log(
        _ message: String,
        category: LogCategory = .general,
        level: OSLogType = .default,
        error: Error? = nil) {
        let logger = getLogger(category: category)
        var logMessage = message
        if let err = error {
            // Append a more detailed error description if available
            if let localizedError = error as? LocalizedError, let errorDescription = localizedError.errorDescription {
                logMessage += " - Error: \(errorDescription)"
            } else {
                logMessage += " - Error: \(err.localizedDescription)"
            }
            // For network or decoding errors, the error object itself might have useful details not in
            // localizedDescription
            if category == .api || category == .exchangeRate {
                logMessage += " (Details: \(String(describing: err)))"
            }
        }

        switch level {
        case .info:
            logger.info("\(logMessage)")
        case .debug:
            logger.debug("\(logMessage)")
        case .error:
            logger.error("\(logMessage)")
        case .fault:
            logger.fault("\(logMessage)")
        default:
            logger.log("\(logMessage)")
        }
    }

    // Convenience functions for specific levels
    static func info(_ message: String, category: LogCategory = .general) {
        log(message, category: category, level: .info)
    }

    static func debug(_ message: String, category: LogCategory = .general) {
        log(message, category: category, level: .debug)
    }

    static func warning(_ message: String, category: LogCategory = .general, error: Error? = nil) {
        log(message, category: category, level: .default, error: error)
    }

    static func critical(_ message: String, category: LogCategory = .general, error: Error? = nil) {
        log(message, category: category, level: .fault, error: error)
    }

    static func error(_ message: String, category: LogCategory = .general, error: Error? = nil) {
        log(message, category: category, level: .error, error: error)
    }

    static func fault(_ message: String, category: LogCategory = .general, error: Error? = nil) {
        log(message, category: category, level: .fault, error: error)
    }
}
