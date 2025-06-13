import Foundation
@testable import VibeMeter

/// Mock implementation of ClaudeLogManagerProtocol for testing
@MainActor
final class ClaudeLogManagerMock: BaseMock, ClaudeLogManagerProtocol {
    // MARK: - Properties

    private(set) var hasAccess = false
    private(set) var isProcessing = false
    private(set) var lastError: Error?

    // Mock account type for testing
    var mockAccountType: ClaudePricingTier = .pro

    // MARK: - Return Values

    var requestLogAccessResult = false
    var getDailyUsageResult: [Date: [ClaudeLogEntry]] = [:]
    var calculateFiveHourWindowResult = FiveHourWindow(
        used: 50,
        total: 100,
        resetDate: Date().addingTimeInterval(3600),
        tokensUsed: 50000,
        estimatedTokenLimit: 100_000)
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

    func getDailyUsageWithProgress(delegate: ClaudeLogProgressDelegate?) async -> [Date: [ClaudeLogEntry]] {
        recordCall("getDailyUsageWithProgress")
        isProcessing = true
        defer { isProcessing = false }

        // Simulate progress updates if delegate provided
        if let delegate {
            delegate.logProcessingDidStart(totalFiles: 5)
            delegate.logProcessingDidUpdate(filesProcessed: 5, dailyUsage: getDailyUsageResult)
            delegate.logProcessingDidComplete(dailyUsage: getDailyUsageResult)
        }

        return getDailyUsageResult
    }

    func calculateFiveHourWindow(from dailyUsage: [Date: [ClaudeLogEntry]]) -> FiveHourWindow {
        recordCall("calculateFiveHourWindow")
        capturedCalculateFiveHourWindowUsage = dailyUsage

        // If we have a pre-configured result, return it
        // Check if it's different from the default value
        let defaultWindow = FiveHourWindow(
            used: 50,
            total: 100,
            resetDate: Date().addingTimeInterval(3600),
            tokensUsed: 50000,
            estimatedTokenLimit: 100_000)
        if calculateFiveHourWindowResult.used != defaultWindow.used ||
            calculateFiveHourWindowResult.total != defaultWindow.total {
            return calculateFiveHourWindowResult
        }

        // Otherwise, actually calculate the window based on the mock account type
        let now = Date()
        let fiveHoursAgo = now.addingTimeInterval(-5 * 60 * 60)

        // Filter entries within the last 5 hours
        let recentEntries = dailyUsage.values
            .flatMap(\.self)
            .filter { $0.timestamp >= fiveHoursAgo }

        // Calculate total tokens used
        let totalInputTokens = recentEntries.reduce(0) { $0 + $1.inputTokens }
        let totalOutputTokens = recentEntries.reduce(0) { $0 + $1.outputTokens }

        // For Pro/Team accounts, calculate based on message count approximation
        if mockAccountType.usesFiveHourWindow, let messagesPerWindow = mockAccountType.messagesPerFiveHours {
            let avgTokensPerMessage = 3000
            let estimatedTokenLimit = messagesPerWindow * avgTokensPerMessage

            let totalTokensUsed = totalInputTokens + totalOutputTokens
            let usageRatio = Double(totalTokensUsed) / Double(estimatedTokenLimit)

            // Find the oldest entry in the window to calculate reset time
            let oldestEntryTime = recentEntries.min(by: { $0.timestamp < $1.timestamp })?.timestamp ?? now
            let resetDate = oldestEntryTime.addingTimeInterval(5 * 60 * 60)

            return FiveHourWindow(
                used: min(usageRatio * 100, 100),
                total: 100,
                resetDate: resetDate,
                tokensUsed: totalTokensUsed,
                estimatedTokenLimit: estimatedTokenLimit)
        } else {
            // Free tier - daily limit
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: now)
            let todayEntries = dailyUsage.values
                .flatMap(\.self)
                .filter {
                    let entryDay = calendar.startOfDay(for: $0.timestamp)
                    return entryDay == startOfDay
                }

            let messageCount = todayEntries.count
            let dailyLimit = mockAccountType.dailyMessageLimit ?? 50
            let usageRatio = Double(messageCount) / Double(dailyLimit)

            // Calculate tokens for today
            let todayTokensUsed = todayEntries.reduce(0) { $0 + $1.inputTokens + $1.outputTokens }
            let estimatedDailyTokenLimit = dailyLimit * 3000

            // Reset at midnight PT
            var nextResetComponents = calendar.dateComponents([.year, .month, .day], from: now)
            nextResetComponents.day! += 1
            nextResetComponents.hour = 0
            nextResetComponents.minute = 0
            nextResetComponents.timeZone = TimeZone(identifier: "America/Los_Angeles")
            let resetDate = calendar.date(from: nextResetComponents) ?? now

            return FiveHourWindow(
                used: min(usageRatio * 100, 100),
                total: 100,
                resetDate: resetDate,
                tokensUsed: todayTokensUsed,
                estimatedTokenLimit: estimatedDailyTokenLimit)
        }
    }

    func countTokens(in text: String) -> Int {
        recordCall("countTokens")
        capturedCountTokensText = text
        return countTokensResult
    }

    func getCurrentWindowUsage() async -> FiveHourWindow {
        recordCall("getCurrentWindowUsage")
        return calculateFiveHourWindowResult
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
            resetDate: resetDate,
            tokensUsed: Int(used * 1000),
            estimatedTokenLimit: Int(total * 1000))
    }

    /// Set token window usage with explicit token counts
    func setTokenWindowUsage(
        tokensUsed: Int,
        estimatedTokenLimit: Int,
        resetDate: Date = Date().addingTimeInterval(3600)) {
        let percentageUsed = estimatedTokenLimit > 0 ? Double(tokensUsed) / Double(estimatedTokenLimit) * 100 : 0
        calculateFiveHourWindowResult = FiveHourWindow(
            used: percentageUsed,
            total: 100,
            resetDate: resetDate,
            tokensUsed: tokensUsed,
            estimatedTokenLimit: estimatedTokenLimit)
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
            resetDate: Date().addingTimeInterval(3600),
            tokensUsed: 50000,
            estimatedTokenLimit: 100_000)
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
            resetDate: Date().addingTimeInterval(1800), // 30 minutes
            tokensUsed: 95000,
            estimatedTokenLimit: 100_000)
    }
}
