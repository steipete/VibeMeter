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
    private let logger = Logger.vibeMeter(category: "BackgroundProcessor")

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

        // Fetch all available months of data
        let calendar = Calendar.current
        let currentDate = Date()
        let currentYear = calendar.component(.year, from: currentDate)
        let currentMonth = calendar.component(.month, from: currentDate) // 1-based (1-12)
        
        // Determine start date for historical data (e.g., 12 months back)
        let startDate = calendar.date(byAdding: .month, value: -12, to: currentDate) ?? currentDate
        let startYear = calendar.component(.year, from: startDate)
        let startMonth = calendar.component(.month, from: startDate) // 1-based (1-12)
        
        logger.info("Fetching historical data from \(startMonth)/\(startYear) to \(currentMonth)/\(currentYear)")
        
        // Collect all invoice tasks
        var invoiceTasks: [Task<ProviderMonthlyInvoice?, Never>] = []
        var yearMonth = (year: startYear, month: startMonth)
        
        // Get invoice cache for Cursor provider
        let invoiceCache = if provider == .cursor {
            await CursorInvoiceCache.shared
        } else {
            nil as CursorInvoiceCache?
        }
        
        while (yearMonth.year < currentYear) || (yearMonth.year == currentYear && yearMonth.month <= currentMonth) {
            let apiMonth = yearMonth.month - 1 // Convert to 0-based for API (0-11)
            let year = yearMonth.year
            let effectiveTeamId = teamInfo.id == 0 ? nil : teamInfo.id
            
            let task = Task { () -> ProviderMonthlyInvoice? in
                // Check cache first for Cursor provider
                if let cache = invoiceCache,
                   let cachedInvoice = await cache.getCachedInvoice(month: apiMonth, year: year, teamId: effectiveTeamId) {
                    logger.info("Using cached invoice for \(yearMonth.month)/\(year): \(cachedInvoice.totalSpendingCents) cents")
                    return cachedInvoice
                }
                
                // Fetch from API if not cached
                do {
                    let invoice = try await providerClient.fetchMonthlyInvoice(
                        authToken: authToken,
                        month: apiMonth,
                        year: year,
                        teamId: effectiveTeamId)
                    logger.info("Fetched invoice for \(yearMonth.month)/\(year): \(invoice.totalSpendingCents) cents")
                    
                    // Cache the result for Cursor provider
                    if let cache = invoiceCache {
                        await cache.cacheInvoice(invoice, month: apiMonth, year: year, teamId: effectiveTeamId)
                    }
                    
                    return invoice
                } catch {
                    logger.warning("Failed to fetch invoice for \(yearMonth.month)/\(year): \(error.localizedDescription)")
                    return nil
                }
            }
            invoiceTasks.append(task)
            
            // Move to next month
            if yearMonth.month == 12 {
                yearMonth = (year: yearMonth.year + 1, month: 1)
            } else {
                yearMonth = (year: yearMonth.year, month: yearMonth.month + 1)
            }
        }
        
        // Also fetch usage data concurrently
        async let usageTask = providerClient.fetchUsageData(authToken: authToken)
        
        // Wait for all invoice tasks to complete
        var invoices: [ProviderMonthlyInvoice] = []
        for task in invoiceTasks {
            if let invoice = await task.value {
                invoices.append(invoice)
            }
        }
        
        // Combine all invoices into a single invoice with all items
        let allItems = invoices.flatMap { $0.items }
        
        // Use the most recent invoice's pricing description
        let latestInvoice = invoices.last(where: { $0.totalSpendingCents > 0 }) ?? invoices.last
        
        let combinedInvoice = ProviderMonthlyInvoice(
            items: allItems,
            pricingDescription: latestInvoice?.pricingDescription,
            provider: provider,
            month: currentMonth - 1, // API month (0-based)
            year: currentYear
        )

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
            logger.info("Claude: Total invoice items across all months: \(combinedInvoice.items.count), total: \(combinedInvoice.totalSpendingCents) cents")
            logger.info("Claude: Usage data - current: \(usage.currentRequests), max: \(usage.maxRequests ?? 0)")
            if let pricing = combinedInvoice.pricingDescription {
                logger.info("Claude: Pricing description: \(pricing.description)")
            }
        }

        logger.info("Completed background processing for \(provider.displayName) - fetched \(invoices.count) months of data")
        return ProviderDataResult(
            userInfo: userInfo,
            teamInfo: teamInfo,
            invoice: combinedInvoice,
            usage: usage)
    }
}
