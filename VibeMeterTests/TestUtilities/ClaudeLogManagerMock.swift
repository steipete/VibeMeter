import Foundation
@testable import VibeMeter

/// Mock implementation of ClaudeLogManagerProtocol for testing
@MainActor
final class ClaudeLogManagerMock: BaseMock, ClaudeLogManagerProtocol {
    // MARK: - Properties

    private(set) var hasAccess = false
    private(set) var isProcessing = false
    private(set) var lastError: Error?

    // MARK: - Return Values

    var requestLogAccessResult = false
    var getDailyUsageResult: [Date: [ClaudeLogEntry]] = [:]
    var calculateFiveHourWindowResult = FiveHourWindow(
        used: 50,
        total: 100,
        resetDate: Date().addingTimeInterval(3600))
    var countTokensResult = 0

    // MARK: - Captured Parameters

    private(set) var capturedCountTokensText: String?
    private(set) var capturedCalculateFiveHourWindowUsage: [Date: [ClaudeLogEntry]]?

    // MARK: - ClaudeLogManagerProtocol

    func requestLogAccess() async -> Bool {
        recordCall("requestLogAccess")
        return requestLogAccessResult
    }

    func revokeAccess() {
        recordCall("revokeAccess")
        hasAccess = false
    }

    func getDailyUsage() async -> [Date: [ClaudeLogEntry]] {
        recordCall("getDailyUsage")
        isProcessing = true
        defer { isProcessing = false }
        return getDailyUsageResult
    }

    func calculateFiveHourWindow(from dailyUsage: [Date: [ClaudeLogEntry]]) -> FiveHourWindow {
        recordCall("calculateFiveHourWindow")
        capturedCalculateFiveHourWindowUsage = dailyUsage
        return calculateFiveHourWindowResult
    }

    func countTokens(in text: String) -> Int {
        recordCall("countTokens")
        capturedCountTokensText = text
        return countTokensResult
    }

    // MARK: - Mock Control Methods

    func setHasAccess(_ value: Bool) {
        hasAccess = value
    }

    func setLastError(_ error: Error?) {
        lastError = error
    }

    func setDailyUsage(_ usage: [Date: [ClaudeLogEntry]]) {
        getDailyUsageResult = usage
    }

    func setFiveHourWindow(used: Double, total: Double, resetDate: Date) {
        calculateFiveHourWindowResult = FiveHourWindow(
            used: used,
            total: total,
            resetDate: resetDate)
    }

    // MARK: - Reset

    override func resetReturnValues() {
        hasAccess = false
        isProcessing = false
        lastError = nil
        requestLogAccessResult = false
        getDailyUsageResult = [:]
        calculateFiveHourWindowResult = FiveHourWindow(
            used: 50,
            total: 100,
            resetDate: Date().addingTimeInterval(3600))
        countTokensResult = 0
        capturedCountTokensText = nil
        capturedCalculateFiveHourWindowUsage = nil
    }
}

// MARK: - Test Helpers

extension ClaudeLogManagerMock {
    /// Creates sample daily usage data for testing
    static func createSampleDailyUsage(daysCount: Int = 7) -> [Date: [ClaudeLogEntry]] {
        var usage: [Date: [ClaudeLogEntry]] = [:]
        let calendar = Calendar.current

        for i in 0 ..< daysCount {
            let date = calendar.date(byAdding: .day, value: -i, to: Date())!
            let startOfDay = calendar.startOfDay(for: date)

            // Create 3-5 entries per day
            let entryCount = Int.random(in: 3 ... 5)
            var entries: [ClaudeLogEntry] = []

            for j in 0 ..< entryCount {
                let timestamp = calendar.date(byAdding: .hour, value: j * 2, to: startOfDay)!
                let entry = ClaudeLogEntry(
                    timestamp: timestamp,
                    model: "claude-3.5-sonnet",
                    inputTokens: Int.random(in: 100 ... 5000),
                    outputTokens: Int.random(in: 50 ... 2000))
                entries.append(entry)
            }

            usage[startOfDay] = entries
        }

        return usage
    }

    /// Creates a five-hour window near exhaustion
    static func createExhaustedWindow() -> FiveHourWindow {
        FiveHourWindow(
            used: 95,
            total: 100,
            resetDate: Date().addingTimeInterval(1800) // 30 minutes
        )
    }
}
