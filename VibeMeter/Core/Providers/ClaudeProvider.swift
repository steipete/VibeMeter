import Foundation
import os.log

/// Provider implementation for Claude AI usage tracking
///
/// Unlike other providers, ClaudeProvider reads local log files instead of using network APIs.
/// It requires file system access granted through the ClaudeLogManager.
public actor ClaudeProvider: ProviderProtocol {
    // MARK: - Properties

    public let provider: ServiceProvider = .claude
    private let logger = Logger(subsystem: "com.vibemeter", category: "ClaudeProvider")
    private let logManager: any ClaudeLogManagerProtocol
    private let settingsManager: any SettingsManagerProtocol

    // Cache for performance
    private var cachedDailyUsage: [Date: [ClaudeLogEntry]]?
    private var cacheTimestamp: Date?
    private let cacheValidityDuration: TimeInterval = 300 // 5 minutes

    // MARK: - Initialization

    public init(settingsManager: any SettingsManagerProtocol,
                logManager: any ClaudeLogManagerProtocol = ClaudeLogManager.shared) {
        self.settingsManager = settingsManager
        self.logManager = logManager
    }

    // MARK: - ProviderProtocol Implementation

    public func fetchTeamInfo(authToken _: String) async throws -> ProviderTeamInfo {
        // Claude doesn't support teams
        throw ProviderError.unsupportedProvider(.claude)
    }

    public func fetchUserInfo(authToken _: String) async throws -> ProviderUserInfo {
        logger.info("Claude: fetchUserInfo called")

        // Check if we have file access
        let hasAccess = await logManager.hasAccess
        logger.info("Claude: File access status: \(hasAccess)")

        guard hasAccess else {
            logger.error("Claude: No file access, cannot fetch user info")
            throw ProviderError.authenticationFailed(reason: "No folder access")
        }

        // Return local user info based on system username
        let username = NSUserName()
        let email = "\(username)@local"

        logger.info("Claude: Fetched user info - username: \(username), email: \(email)")
        return ProviderUserInfo(
            email: email,
            provider: .claude)
    }

    public func fetchMonthlyInvoice(authToken _: String, month: Int, year: Int,
                                    teamId _: Int?) async throws -> ProviderMonthlyInvoice {
        logger.info("Claude: fetchMonthlyInvoice called for month: \(month + 1)/\(year)")

        // Get daily usage data
        let dailyUsage = try await getDailyUsageWithCache()
        logger.info("Claude: Got daily usage data with \(dailyUsage.count) days")

        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month + 1) // month is 0-indexed
        guard let targetMonth = calendar.date(from: components) else {
            throw ProviderError.decodingError(
                message: "Invalid month/year: \(month + 1)/\(year)",
                statusCode: nil)
        }

        // Filter entries for the target month
        let monthlyEntries = dailyUsage.compactMap { date, entries -> (Date, [ClaudeLogEntry])? in
            guard calendar.isDate(date, equalTo: targetMonth, toGranularity: .month) else {
                return nil
            }
            return (date, entries)
        }

        logger.info("Claude: Filtered to \(monthlyEntries.count) days for month \(month + 1)/\(year)")

        // Calculate costs for each day
        var invoiceItems: [ProviderInvoiceItem] = []
        // Get account type from settings
        let accountType = await MainActor.run {
            SettingsManager.shared.sessionSettingsManager.claudeAccountType
        }

        for (date, entries) in monthlyEntries {
            let dailyUsage = ClaudeDailyUsage(date: date, entries: entries)
            let costUSD = calculateCost(for: dailyUsage, accountType: accountType)

            if costUSD > 0 {
                let item = ProviderInvoiceItem(
                    cents: Int(costUSD * 100),
                    description: "Claude usage on \(formatDate(date))",
                    provider: .claude)
                invoiceItems.append(item)
            }
        }

        // Sort by date
        invoiceItems.sort { _, _ in
            // Since we're creating items from entries, we use the daily date as a proxy
            true // Items are already in order from the loop
        }

        // Calculate total tokens for the month
        var totalInputTokens = 0
        var totalOutputTokens = 0
        var totalCost = 0.0
        for (date, entries) in monthlyEntries {
            let dailyUsage = ClaudeDailyUsage(date: date, entries: entries)
            totalInputTokens += dailyUsage.totalInputTokens
            totalOutputTokens += dailyUsage.totalOutputTokens

            let dailyCost = calculateCost(for: dailyUsage, accountType: accountType)
            totalCost += dailyCost

            logger
                .debug(
                    "Claude: Day \(self.formatDate(date)) - Input: \(dailyUsage.totalInputTokens), Output: \(dailyUsage.totalOutputTokens), Cost: $\(dailyCost)")
        }

        logger
            .info(
                "Claude: Monthly totals - Input tokens: \(totalInputTokens), Output tokens: \(totalOutputTokens), Total cost: $\(totalCost)")

        // Create pricing description with token counts and cost breakdown
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","

        let inputStr = formatter.string(from: NSNumber(value: totalInputTokens)) ?? "\(totalInputTokens)"
        let outputStr = formatter.string(from: NSNumber(value: totalOutputTokens)) ?? "\(totalOutputTokens)"

        // Calculate individual costs
        let (inputPrice, outputPrice) = getPricing(for: accountType)
        let inputCost = Double(totalInputTokens) / 1_000_000 * inputPrice
        let outputCost = Double(totalOutputTokens) / 1_000_000 * outputPrice

        let costFormatter = NumberFormatter()
        costFormatter.numberStyle = .currency
        costFormatter.currencyCode = "USD"
        costFormatter.maximumFractionDigits = 2

        let inputCostStr = costFormatter.string(from: NSNumber(value: inputCost)) ?? "$\(inputCost)"
        let outputCostStr = costFormatter.string(from: NSNumber(value: outputCost)) ?? "$\(outputCost)"

        let pricingDescriptionText = "\(inputStr) input (\(inputCostStr)), \(outputStr) output (\(outputCostStr))"
        let pricingDescription = ProviderPricingDescription(
            description: pricingDescriptionText,
            id: "claude-token-usage",
            provider: .claude)

        logger.info("Fetched monthly invoice for Claude: \(invoiceItems.count) items, month: \(month + 1)/\(year)")

        return ProviderMonthlyInvoice(
            items: invoiceItems,
            pricingDescription: pricingDescription,
            provider: .claude,
            month: month,
            year: year)
    }

    public func fetchUsageData(authToken _: String) async throws -> ProviderUsageData {
        logger.info("Claude: fetchUsageData called")

        // Calculate 5-hour window usage for Pro accounts
        let dailyUsage = try await getDailyUsageWithCache()
        let fiveHourWindow = await logManager.calculateFiveHourWindow(from: dailyUsage)

        logger.info("Claude: 5-hour window - Used: \(fiveHourWindow.used)/\(fiveHourWindow.total) messages")

        // Convert to ProviderUsageData format
        let currentRequests = Int(fiveHourWindow.used)
        let maxRequests = Int(fiveHourWindow.total)

        return ProviderUsageData(
            currentRequests: currentRequests,
            totalRequests: currentRequests,
            maxRequests: maxRequests,
            startOfMonth: Date().startOfMonth(),
            provider: .claude)
    }

    public func validateToken(authToken _: String) async -> Bool {
        // For Claude, validation means checking if we have file access
        let hasAccess = await logManager.hasAccess
        logger.info("Claude: validateToken called - hasAccess: \(hasAccess)")
        return hasAccess
    }

    public nonisolated func getAuthenticationURL() -> URL {
        // Not used for Claude
        URL(string: "file://localhost")!
    }

    public nonisolated func extractAuthToken(from _: [String: Any]) -> String? {
        // Return a dummy token for Claude since we use file access
        "claude_local_access"
    }

    // MARK: - Claude-Specific Methods

    /// Get five-hour window usage data
    func getFiveHourWindowUsage() async throws -> FiveHourWindow {
        let dailyUsage = try await getDailyUsageWithCache()
        return await logManager.calculateFiveHourWindow(from: dailyUsage)
    }

    /// Get daily usage breakdown
    func getDailyUsageBreakdown() async throws -> [ClaudeDailyUsage] {
        let dailyUsage = try await getDailyUsageWithCache()

        return dailyUsage.map { date, entries in
            ClaudeDailyUsage(date: date, entries: entries)
        }.sorted { $0.date > $1.date }
    }

    /// Request file access if not already granted
    public func requestFileAccess() async -> Bool {
        await logManager.requestLogAccess()
    }

    /// Check if file access is granted
    public func hasFileAccess() async -> Bool {
        await logManager.hasAccess
    }

    // MARK: - Private Methods

    private func getDailyUsageWithCache() async throws -> [Date: [ClaudeLogEntry]] {
        // Check cache validity
        if let cached = cachedDailyUsage,
           let timestamp = cacheTimestamp,
           Date().timeIntervalSince(timestamp) < cacheValidityDuration {
            return cached
        }

        // Fetch fresh data
        guard await logManager.hasAccess else {
            throw ProviderError
                .authenticationFailed(reason: "Grant folder access in settings")
        }

        let usage = await logManager.getDailyUsage()

        // Update cache
        cachedDailyUsage = usage
        cacheTimestamp = Date()

        return usage
    }

    private func calculateCost(for dailyUsage: ClaudeDailyUsage, accountType: ClaudePricingTier) -> Double {
        // Pricing based on account type
        let (inputPrice, outputPrice) = getPricing(for: accountType)
        return dailyUsage.calculateCost(
            inputPricePerMillion: inputPrice,
            outputPricePerMillion: outputPrice)
    }

    private func getPricing(for accountType: ClaudePricingTier) -> (input: Double, output: Double) {
        switch accountType {
        case .free:
            // Free tier has no cost
            (0, 0)
        case .pro, .max100, .max200:
            // All paid tiers use the same Claude 3.5 Sonnet pricing
            (3.0, 15.0) // $3/$15 per million tokens
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Date Extensions

private extension Date {
    func startOfMonth() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }
}
