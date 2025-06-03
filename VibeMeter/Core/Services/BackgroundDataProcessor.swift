import Foundation
import os.log

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
    ///
    /// - Parameters:
    ///   - provider: The service provider to fetch data for
    ///   - authToken: Authentication token for API access
    ///   - providerClient: Provider-specific API client
    /// - Returns: Tuple containing all fetched data
    /// - Throws: Provider-specific errors or network errors
    func processProviderData(
        provider: ServiceProvider,
        authToken: String,
        providerClient: any ProviderProtocol
    ) async throws -> (userInfo: ProviderUserInfo, teamInfo: ProviderTeamInfo, invoice: ProviderMonthlyInvoice, usage: ProviderUsageData) {
        logger.info("Processing data for \(provider.displayName) on background actor")
        
        // Fetch user and team info concurrently
        async let userTask = providerClient.fetchUserInfo(authToken: authToken)
        async let teamTask = providerClient.fetchTeamInfo(authToken: authToken)
        
        let userInfo = try await userTask
        let teamInfo = try await teamTask
        
        // Calculate current month for invoice data
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date()) - 1 // 0-based for API
        let year = calendar.component(.year, from: Date())
        
        // Fetch invoice and usage data concurrently
        async let invoiceTask = providerClient.fetchMonthlyInvoice(
            authToken: authToken,
            month: month,
            year: year
        )
        async let usageTask = providerClient.fetchUsageData(authToken: authToken)
        
        let invoice = try await invoiceTask
        let usage = try await usageTask
        
        logger.info("Completed background processing for \(provider.displayName)")
        return (userInfo, teamInfo, invoice, usage)
    }
}