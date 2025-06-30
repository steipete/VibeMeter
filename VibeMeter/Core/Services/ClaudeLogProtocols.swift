import Foundation

// MARK: - Protocols

/// Protocol for receiving progress updates during log processing
@MainActor
public protocol ClaudeLogProgressDelegate: AnyObject, Sendable {
    func logProcessingDidStart(totalFiles: Int)
    func logProcessingDidUpdate(filesProcessed: Int, dailyUsage: [Date: [ClaudeLogEntry]])
    func logProcessingDidComplete(dailyUsage: [Date: [ClaudeLogEntry]])
    func logProcessingDidFail(error: Error)
}

/// Protocol for managing Claude log file access and parsing
@MainActor
public protocol ClaudeLogManagerProtocol: AnyObject, Sendable {
    var hasAccess: Bool { get }
    var isProcessing: Bool { get }
    var lastError: Error? { get }

    func requestLogAccess() async -> Bool
    func revokeAccess()
    func getDailyUsage() async -> [Date: [ClaudeLogEntry]]
    func getDailyUsageWithProgress(delegate: ClaudeLogProgressDelegate?) async -> [Date: [ClaudeLogEntry]]
    func calculateFiveHourWindow(from dailyUsage: [Date: [ClaudeLogEntry]]) -> FiveHourWindow
    func countTokens(in text: String) -> Int
    func getCurrentWindowUsage() async -> FiveHourWindow
    func getSessionTracker() -> ClaudeSessionTracker
}

// MARK: - Errors

public enum ClaudeLogManagerError: LocalizedError {
    case noAccess
    case invalidLogFormat
    case fileSystemError(Error)

    public var errorDescription: String? {
        switch self {
        case .noAccess:
            "No access to Claude logs. Please grant folder access in settings."
        case .invalidLogFormat:
            "Invalid Claude log format"
        case let .fileSystemError(error):
            "File system error: \(error.localizedDescription)"
        }
    }
}