import Foundation
import os.log

/// Provider implementation for Claude AI usage tracking
///
/// Unlike other providers, ClaudeProvider reads local log files instead of using network APIs.
/// It requires file system access granted through the ClaudeLogManager.
public actor ClaudeProvider: ProviderProtocol {
    // MARK: - Properties

    public let provider: ServiceProvider = .claude
    private let logger = Logger.vibeMeter(category: "ClaudeProvider")
    private let logManager: any ClaudeLogManagerProtocol
    private let settingsManager: any SettingsManagerProtocol
    private let pricingManager = PricingDataManager.shared

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

        logger.info("Claude: Fetched user info - username: \(username)")
        return ProviderUserInfo(
            email: username,
            provider: .claude)
    }

    public func fetchMonthlyInvoice(authToken _: String, month: Int, year: Int,
                                    teamId _: Int?) async throws -> ProviderMonthlyInvoice {
        logger.info("Claude: fetchMonthlyInvoice called for month: \(month + 1)/\(year)")

        // Get monthly entries
        let monthlyEntries = try await getMonthlyEntries(month: month, year: year)
        logger.info("Claude: Filtered to \(monthlyEntries.count) days for month \(month + 1)/\(year)")

        // Calculate invoice items
        let invoiceItems = try await calculateInvoiceItems(from: monthlyEntries)

        // Calculate monthly totals
        let (totalInputTokens, totalOutputTokens, totalCost) = try await calculateMonthlyTotals(from: monthlyEntries)
        logger
            .info(
                "Claude: Monthly totals - Input tokens: \(totalInputTokens), Output tokens: \(totalOutputTokens), Total cost: $\(totalCost)")

        // Create pricing description
        let allEntries = monthlyEntries.flatMap(\.1)
        let pricingDescription = try await createPricingDescription(
            totalInputTokens: totalInputTokens,
            totalOutputTokens: totalOutputTokens,
            entries: allEntries)

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

        // Use real-time window usage for accurate gauge updates
        let fiveHourWindow = await logManager.getCurrentWindowUsage()

        logger.info("Claude: 5-hour window - Used: \(fiveHourWindow.percentageUsed)% (real-time)")

        // Convert to ProviderUsageData format
        // For Claude quota gauge representation, we need to pass the percentage as currentRequests
        // This is expected by calculateClaudeQuotaPercentage() in StatusBarController
        let percentageAsInt = Int(fiveHourWindow.percentageUsed)

        return ProviderUsageData(
            currentRequests: percentageAsInt, // Pass percentage (0-100) for gauge
            totalRequests: fiveHourWindow.tokensUsed, // Keep actual token count for display
            maxRequests: 100, // Max percentage is always 100
            startOfMonth: Date().startOfMonth,
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
        // Use real-time data for accurate current window usage
        await logManager.getCurrentWindowUsage()
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
    
    /// Calculate token burn rate from recent log entries
    public func calculateTokenBurnRate() async -> BurnRateCalculator.BurnRate? {
        do {
            // Get recent log entries (last 2 hours to ensure we have enough data)
            let dailyUsage = try await getDailyUsageWithCache()
            let now = Date()
            let twoHoursAgo = now.addingTimeInterval(-7200)
            
            // Flatten all entries and filter by time
            let recentEntries = dailyUsage.values
                .flatMap { $0 }
                .filter { $0.timestamp >= twoHoursAgo }
                .sorted { $0.timestamp < $1.timestamp }
            
            guard !recentEntries.isEmpty else { return nil }
            
            // Calculate burn rate using the BurnRateCalculator
            let calculator = BurnRateCalculator()
            return await calculator.calculateClaudeTokenBurnRate(
                entries: recentEntries,
                in: 3600, // 1 hour window
                currentTime: now
            )
        } catch {
            logger.error("Failed to calculate token burn rate: \(error)")
            return nil
        }
    }

    // MARK: - Private Methods

    private func getMonthlyEntries(month: Int, year: Int) async throws -> [(Date, [ClaudeLogEntry])] {
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
        return dailyUsage.compactMap { date, entries -> (Date, [ClaudeLogEntry])? in
            guard calendar.isDate(date, equalTo: targetMonth, toGranularity: .month) else {
                return nil
            }
            return (date, entries)
        }
    }

    private func calculateInvoiceItems(from monthlyEntries: [(Date, [ClaudeLogEntry])]) async throws
        -> [ProviderInvoiceItem] {
        var invoiceItems: [ProviderInvoiceItem] = []
        let costStrategy = await MainActor.run {
            settingsManager.displaySettingsManager.costCalculationStrategy
        }

        for (date, entries) in monthlyEntries {
            var totalDailyCost = 0.0

            for entry in entries {
                let cost = entry.calculateCost(strategy: costStrategy)
                totalDailyCost += cost
            }

            if totalDailyCost > 0 {
                let item = ProviderInvoiceItem(
                    cents: Int(totalDailyCost * 100),
                    description: "Claude usage on \(formatDate(date))",
                    provider: .claude)
                invoiceItems.append(item)
            }
        }

        return invoiceItems
    }

    private func calculateMonthlyTotals(from monthlyEntries: [(Date, [ClaudeLogEntry])]) async throws
        -> (inputTokens: Int, outputTokens: Int, totalCost: Double) {
        var totalInputTokens = 0
        var totalOutputTokens = 0
        var totalCost = 0.0

        let costStrategy = await MainActor.run {
            settingsManager.displaySettingsManager.costCalculationStrategy
        }

        for (_, entries) in monthlyEntries {
            for entry in entries {
                totalInputTokens += entry.inputTokens
                totalOutputTokens += entry.outputTokens

                let cost = entry.calculateCost(strategy: costStrategy)
                totalCost += cost
            }
        }

        return (totalInputTokens, totalOutputTokens, totalCost)
    }

    private func createPricingDescription(
        totalInputTokens: Int,
        totalOutputTokens: Int,
        entries: [ClaudeLogEntry]) async throws -> ProviderPricingDescription {
        // Format token counts
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","

        let inputStr = formatter.string(from: NSNumber(value: totalInputTokens)) ?? "\(totalInputTokens)"
        let outputStr = formatter.string(from: NSNumber(value: totalOutputTokens)) ?? "\(totalOutputTokens)"

        // Get most common model
        let modelCounts = entries.reduce(into: [String: Int]()) { counts, entry in
            let model = entry.model ?? "claude-3-5-sonnet"
            counts[model, default: 0] += 1
        }
        let mostCommonModel = modelCounts.max(by: { $0.value < $1.value })?.key ?? "claude-3-5-sonnet"

        // Calculate individual costs
        let inputTokenUsage = TokenUsage(inputTokens: totalInputTokens, outputTokens: 0)
        let outputTokenUsage = TokenUsage(inputTokens: 0, outputTokens: totalOutputTokens)

        let inputCost = await pricingManager.calculateCost(
            tokens: inputTokenUsage,
            model: mostCommonModel,
            mode: .calculate)
        let outputCost = await pricingManager.calculateCost(
            tokens: outputTokenUsage,
            model: mostCommonModel,
            mode: .calculate)

        // Format costs
        let costFormatter = NumberFormatter()
        costFormatter.numberStyle = .currency
        costFormatter.currencyCode = "USD"
        costFormatter.usesGroupingSeparator = false

        if inputCost < 0.01 || outputCost < 0.01 {
            costFormatter.minimumFractionDigits = 2
            costFormatter.maximumFractionDigits = 4
        } else {
            costFormatter.minimumFractionDigits = 0
            costFormatter.maximumFractionDigits = 2
        }

        let inputCostStr = costFormatter.string(from: NSNumber(value: inputCost)) ?? "$\(inputCost)"
        let outputCostStr = costFormatter.string(from: NSNumber(value: outputCost)) ?? "$\(outputCost)"

        let pricingDescriptionText = "\(inputStr) input (\(inputCostStr)), \(outputStr) output (\(outputCostStr))"
        return ProviderPricingDescription(
            description: pricingDescriptionText,
            id: "claude-token-usage",
            provider: .claude)
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

        // Fetch data with parallel processing
        let usage = await logManager.getDailyUsage()

        // Update cache
        cachedDailyUsage = usage
        cacheTimestamp = Date()

        return usage
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
