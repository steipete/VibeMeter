import Foundation
import os.log

// MARK: - Provider Data Result

/// Container for provider data processing results
struct ProviderDataResult {
    let userInfo: ProviderUserInfo
    let teamInfo: ProviderTeamInfo
    let invoice: ProviderMonthlyInvoice
    let usage: ProviderUsageData
}

// MARK: - Background Data Processor

/// Actor for performing concurrent data processing operations off the main thread.
///
/// This actor handles provider data fetching operations in the background to avoid
/// blocking the main thread during network operations. It processes multiple API
/// calls concurrently and returns consolidated results to the main actor.
actor BackgroundDataProcessor {
    private let logger = Logger(subsystem: "com.vibemeter", category: "BackgroundProcessor")

    /// Processes provider data concurrently without blocking the main thread.
    ///
    /// This method fetches user info, team info, invoice data, and usage data
    /// concurrently from the provider's API and returns consolidated results.
    /// If team info fails but user authentication is valid, a fallback team will be used.
    ///
    /// - Parameters:
    ///   - provider: The service provider to fetch data for
    ///   - authToken: Authentication token for API access
    ///   - providerClient: Provider-specific API client
    /// - Returns: Provider data result containing all fetched data
    /// - Throws: Provider-specific errors or network errors
    func processProviderData(
        provider: ServiceProvider,
        authToken: String,
        providerClient: any ProviderProtocol) async throws -> ProviderDataResult {
        logger.info("Processing data for \(provider.displayName) on background actor")

        if provider == .claude {
            logger.info("Claude: Starting background data processing")
        }

        // Fetch user info first - this is required for authentication validation
        let userInfo = try await providerClient.fetchUserInfo(authToken: authToken)

        if provider == .claude {
            logger.info("Claude: User info fetched - \(userInfo.email)")
        }

        // Try to fetch team info, but don't fail if it's unavailable
        let teamInfo: ProviderTeamInfo
        do {
            teamInfo = try await providerClient.fetchTeamInfo(authToken: authToken)
        } catch {
            logger
                .warning(
                    "Team info fetch failed for \(provider.displayName), using fallback: \(error.localizedDescription)")
            // Create fallback team info - user is authenticated but team data unavailable
            teamInfo = ProviderTeamInfo(id: 0, name: "Individual Account", provider: provider)
        }

        // Calculate current month for up-to-date spending data
        let calendar = Calendar.current
        let currentDate = Date()
        let calendarMonth = calendar.component(.month, from: currentDate) // 1-based (1-12)
        let month = calendarMonth - 1 // Convert to 0-based for API (0-11)
        let year = calendar.component(.year, from: currentDate)

        logger
            .info(
                """
                Requesting invoice data for current month \(month)/\(year) \
                (Calendar month \(calendarMonth) -> API month \(month))
                """)

        // Fetch invoice and usage data concurrently
        // Use team ID from team info (or 0 for fallback)
        async let invoiceTask = providerClient.fetchMonthlyInvoice(
            authToken: authToken,
            month: month,
            year: year,
            teamId: teamInfo.id == 0 ? nil : teamInfo.id) // Use nil for fallback team
        async let usageTask = providerClient.fetchUsageData(authToken: authToken)

        let invoice = try await invoiceTask

        // Try to fetch usage data, but don't fail if it's unavailable
        let usage: ProviderUsageData
        do {
            usage = try await usageTask
        } catch {
            let errorMessage = "Usage data fetch failed for \(provider.displayName), using fallback: " +
                "\(error.localizedDescription)"
            logger.warning("\(errorMessage)")
            // Create fallback usage data - zero usage with no limits
            usage = ProviderUsageData(
                currentRequests: 0,
                totalRequests: 0,
                maxRequests: nil,
                startOfMonth: currentDate,
                provider: provider)
        }

        if provider == .claude {
            logger.info("Claude: Invoice items: \(invoice.items.count), total: \(invoice.totalSpendingCents) cents")
            logger.info("Claude: Usage data - current: \(usage.currentRequests), max: \(usage.maxRequests ?? 0)")
            if let pricing = invoice.pricingDescription {
                logger.info("Claude: Pricing description: \(pricing.description)")
            }
        }

        logger.info("Completed background processing for \(provider.displayName)")
        return ProviderDataResult(
            userInfo: userInfo,
            teamInfo: teamInfo,
            invoice: invoice,
            usage: usage)
    }
}
