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
        
        // Calculate total tokens used
        let totalInputTokens = recentEntries.reduce(0) { $0 + $1.inputTokens }
        let totalOutputTokens = recentEntries.reduce(0) { $0 + $1.outputTokens }
        
        // Get account type from settings
        let accountType = settingsManager.sessionSettingsManager.claudeAccountType
        
        // For Pro/Team accounts, calculate based on message count approximation
        // Since we don't have exact token limits, we'll estimate based on messages
        if accountType.usesFiveHourWindow, let messagesPerWindow = accountType.messagesPerFiveHours {
            // Estimate average tokens per message (input + output)
            // Average message might be ~2000 tokens input + ~1000 tokens output
            let avgTokensPerMessage = 3000
            let estimatedTokenLimit = messagesPerWindow * avgTokensPerMessage
            
            let totalTokensUsed = totalInputTokens + totalOutputTokens
            let usageRatio = Double(totalTokensUsed) / Double(estimatedTokenLimit)
            
            return FiveHourWindow(
                used: min(usageRatio * 100, 100),
                total: 100,
                resetDate: fiveHoursAgo.addingTimeInterval(5 * 60 * 60))
        } else {
            // Free tier - daily limit
            // Calculate usage for the whole day
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: now)
            let todayEntries = dailyUsage.values
                .flatMap(\.self)
                .filter { $0.timestamp >= startOfDay }
            
            let messageCount = todayEntries.count
            let dailyLimit = accountType.dailyMessageLimit ?? 50
            let usageRatio = Double(messageCount) / Double(dailyLimit)
            
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
                resetDate: resetDate)
        }
    }
    
    /// Calculate daily usage breakdown with cost information
    func calculateDailyUsageBreakdown(from dailyUsage: [Date: [ClaudeLogEntry]]) -> [ClaudeDailyUsage] {
        dailyUsage.map { date, entries in
            ClaudeDailyUsage(date: date, entries: entries)
        }.sorted { $0.date > $1.date }
    }
    
    /// Filter entries for a specific month
    func filterEntriesForMonth(from dailyUsage: [Date: [ClaudeLogEntry]], month: Int, year: Int) -> [(Date, [ClaudeLogEntry])] {
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
    func calculateTokenStatistics(for entries: [ClaudeLogEntry]) -> (inputTokens: Int, outputTokens: Int, totalCost: Double) {
        let totalInputTokens = entries.reduce(0) { $0 + $1.inputTokens }
        let totalOutputTokens = entries.reduce(0) { $0 + $1.outputTokens }
        
        // Note: Cost calculation would be done by the provider using PricingDataManager
        return (totalInputTokens, totalOutputTokens, 0.0)
    }
}