import Foundation
import os.log

/// Calculates five-hour window usage quotas for Claude accounts
@MainActor
final class ClaudeFiveHourWindowCalculator: @unchecked Sendable {
    private let logger = Logger.vibeMeter(category: "ClaudeFiveHourWindowCalculator")
    private let settingsManager: any SettingsManagerProtocol

    init(settingsManager: any SettingsManagerProtocol = SettingsManager.shared) {
        self.settingsManager = settingsManager
    }

    /// Calculate the current 5-hour window usage
    func calculateFiveHourWindow(from dailyUsage: [Date: [ClaudeLogEntry]]) -> FiveHourWindow {
        let now = Date()
        let fiveHoursAgo = now.addingTimeInterval(-5 * 60 * 60)

        // Filter entries within the last 5 hours
        let recentEntries = dailyUsage.values
            .flatMap(\.self)
            .filter { $0.timestamp >= fiveHoursAgo }

        // Calculate total tokens used in this window
        let totalInputTokens = recentEntries.reduce(0) { $0 + $1.inputTokens }
        let totalOutputTokens = recentEntries.reduce(0) { $0 + $1.outputTokens }
        let totalTokensUsed = totalInputTokens + totalOutputTokens

        // Calculate average tokens per message from recent data
        let messageCount = recentEntries.count
        let avgTokensPerMessage = messageCount > 0 ? totalTokensUsed / messageCount : 3000

        // Get account type from settings
        let accountType = settingsManager.sessionSettingsManager.claudeAccountType

        // For Pro/Team accounts, calculate based on estimated token limits
        if accountType.usesFiveHourWindow, let messagesPerWindow = accountType.messagesPerFiveHours {
            // Use dynamic token limit based on historical usage patterns
            // Claude Pro typically allows ~45 messages per 5 hours for average conversations
            // But this varies significantly based on conversation complexity

            // Calculate an adaptive limit based on current usage pattern
            let estimatedTokenLimit: Int
            if messageCount > 0 {
                // If we have recent messages, extrapolate based on current usage
                let messagesRemaining = max(0, messagesPerWindow - messageCount)
                estimatedTokenLimit = totalTokensUsed + (messagesRemaining * avgTokensPerMessage)
            } else {
                // No recent messages, use conservative estimate
                // Assume average of 4000 tokens per message for Claude Pro
                estimatedTokenLimit = messagesPerWindow * 4000
            }

            // Calculate usage percentage (0-100)
            let usagePercentage = estimatedTokenLimit > 0
                ? min(Double(totalTokensUsed) / Double(estimatedTokenLimit) * 100, 100)
                : 0

            logger
                .info(
                    "🎯 Claude 5-hour window: \(messageCount) messages, \(totalTokensUsed) tokens used, estimated limit: \(estimatedTokenLimit), usage: \(usagePercentage)%")

            return FiveHourWindow(
                used: usagePercentage,
                total: 100,
                resetDate: fiveHoursAgo.addingTimeInterval(5 * 60 * 60),
                tokensUsed: totalTokensUsed,
                estimatedTokenLimit: estimatedTokenLimit)
        } else {
            // Free tier - daily limit based on message count
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: now)
            let todayEntries = dailyUsage.values
                .flatMap(\.self)
                .filter { $0.timestamp >= startOfDay }

            let todayMessageCount = todayEntries.count
            let dailyLimit = accountType.dailyMessageLimit ?? 50
            let usagePercentage = dailyLimit > 0
                ? min(Double(todayMessageCount) / Double(dailyLimit) * 100, 100)
                : 0

            // Reset at midnight PT
            var nextResetComponents = calendar.dateComponents([.year, .month, .day], from: now)
            nextResetComponents.day! += 1
            nextResetComponents.hour = 0
            nextResetComponents.minute = 0
            nextResetComponents.timeZone = TimeZone(identifier: "America/Los_Angeles")
            let resetDate = calendar.date(from: nextResetComponents) ?? now

            // For free tier, we'll calculate tokens for the daily usage
            let todayTokensUsed = todayEntries.reduce(0) { $0 + $1.inputTokens + $1.outputTokens }
            // Estimate based on message limit and average tokens per message
            let estimatedDailyTokenLimit = dailyLimit * 4000

            return FiveHourWindow(
                used: usagePercentage,
                total: 100,
                resetDate: resetDate,
                tokensUsed: todayTokensUsed,
                estimatedTokenLimit: estimatedDailyTokenLimit)
        }
    }

    /// Calculate daily usage breakdown with cost information
    func calculateDailyUsageBreakdown(from dailyUsage: [Date: [ClaudeLogEntry]]) -> [ClaudeDailyUsage] {
        dailyUsage.map { date, entries in
            ClaudeDailyUsage(date: date, entries: entries)
        }.sorted { $0.date > $1.date }
    }

    /// Filter entries for a specific month
    func filterEntriesForMonth(from dailyUsage: [Date: [ClaudeLogEntry]], month: Int, year: Int) -> [(
        Date,
        [ClaudeLogEntry])] {
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month + 1) // month is 0-indexed
        guard let targetMonth = calendar.date(from: components) else {
            logger.error("Invalid month/year: \(month + 1)/\(year)")
            return []
        }

        // Filter entries for the target month
        return dailyUsage.compactMap { date, entries -> (Date, [ClaudeLogEntry])? in
            guard calendar.isDate(date, equalTo: targetMonth, toGranularity: .month) else {
                return nil
            }
            return (date, entries)
        }
    }

    /// Calculate token statistics for a set of entries
    func calculateTokenStatistics(for entries: [ClaudeLogEntry])
        -> (inputTokens: Int, outputTokens: Int, totalCost: Double) {
        let totalInputTokens = entries.reduce(0) { $0 + $1.inputTokens }
        let totalOutputTokens = entries.reduce(0) { $0 + $1.outputTokens }

        // Note: Cost calculation would be done by the provider using PricingDataManager
        return (totalInputTokens, totalOutputTokens, 0.0)
    }
}
