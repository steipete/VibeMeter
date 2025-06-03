import SwiftUI

/// Factory for creating consistent preview data across SwiftUI previews.
///
/// This factory provides standardized mock data for common preview scenarios,
/// reducing duplication and ensuring consistency across preview implementations.
public struct PreviewData {
    
    // MARK: - User Session Data
    
    /// Creates a MultiProviderUserSessionData with a logged-in session for previews.
    ///
    /// - Parameters:
    ///   - provider: The service provider to create session for (default: .cursor)
    ///   - email: User email address (default: "user@example.com")
    ///   - teamName: Team name (default: "Example Team")
    ///   - teamId: Team ID (default: 123)
    /// - Returns: Configured MultiProviderUserSessionData
    @MainActor
    public static func mockUserSession(
        for provider: ServiceProvider = .cursor,
        email: String = "user@example.com",
        teamName: String = "Example Team",
        teamId: Int = 123
    ) -> MultiProviderUserSessionData {
        let userSessionData = MultiProviderUserSessionData()
        userSessionData.handleLoginSuccess(
            for: provider,
            email: email,
            teamName: teamName,
            teamId: teamId
        )
        return userSessionData
    }
    
    /// Creates a MultiProviderUserSessionData with no logged-in sessions.
    ///
    /// - Returns: Empty MultiProviderUserSessionData
    @MainActor
    public static func emptyUserSession() -> MultiProviderUserSessionData {
        MultiProviderUserSessionData()
    }
    
    // MARK: - Spending Data
    
    /// Creates a MultiProviderSpendingData with sample spending and usage data.
    ///
    /// - Parameters:
    ///   - provider: The service provider (default: .cursor)
    ///   - cents: Amount in cents for the invoice (default: 2497)
    ///   - description: Description for the invoice item (default: "Pro Usage")
    ///   - currentRequests: Current usage requests (default: 350)
    ///   - maxRequests: Maximum allowed requests (default: 500)
    ///   - targetCurrency: Target currency for conversion (default: "USD")
    /// - Returns: Configured MultiProviderSpendingData
    @MainActor
    public static func mockSpendingData(
        for provider: ServiceProvider = .cursor,
        cents: Int = 2497,
        description: String = "Pro Usage",
        currentRequests: Int = 350,
        maxRequests: Int = 500,
        targetCurrency: String = "USD"
    ) -> MultiProviderSpendingData {
        let spendingData = MultiProviderSpendingData()
        
        // Add invoice data
        spendingData.updateSpending(
            for: provider,
            from: ProviderMonthlyInvoice(
                items: [
                    ProviderInvoiceItem(cents: cents, description: description, provider: provider)
                ],
                pricingDescription: nil,
                provider: provider,
                month: 5,
                year: 2025
            ),
            rates: [:],
            targetCurrency: targetCurrency
        )
        
        // Add usage data if maxRequests > 0
        if maxRequests > 0 {
            spendingData.updateUsage(
                for: provider,
                from: ProviderUsageData(
                    currentRequests: currentRequests,
                    totalRequests: currentRequests + 3000,
                    maxRequests: maxRequests,
                    startOfMonth: Date(),
                    provider: provider
                )
            )
        }
        
        return spendingData
    }
    
    /// Creates an empty MultiProviderSpendingData for loading state previews.
    ///
    /// - Returns: Empty MultiProviderSpendingData
    @MainActor
    public static func emptySpendingData() -> MultiProviderSpendingData {
        MultiProviderSpendingData()
    }
    
    // MARK: - Currency Data
    
    /// Creates a CurrencyData with specified currency and exchange rates.
    ///
    /// - Parameters:
    ///   - code: Currency code (default: "USD")
    ///   - rates: Exchange rates dictionary (default: empty)
    /// - Returns: Configured CurrencyData
    @MainActor
    public static func mockCurrencyData(
        code: String = "USD",
        rates: [String: Double] = [:]
    ) -> CurrencyData {
        let currencyData = CurrencyData()
        currencyData.updateSelectedCurrency(code)
        if !rates.isEmpty {
            currencyData.updateExchangeRates(rates)
        }
        return currencyData
    }
    
    /// Creates CurrencyData configured for EUR with realistic exchange rate.
    ///
    /// - Returns: CurrencyData configured for EUR
    @MainActor
    public static func eurCurrencyData() -> CurrencyData {
        mockCurrencyData(code: "EUR", rates: ["EUR": 0.92])
    }
    
    /// Creates CurrencyData configured for GBP with realistic exchange rate.
    ///
    /// - Returns: CurrencyData configured for GBP
    @MainActor
    public static func gbpCurrencyData() -> CurrencyData {
        mockCurrencyData(code: "GBP", rates: ["GBP": 0.79])
    }
}

// MARK: - Preview Scenarios

public extension PreviewData {
    /// Complete preview setup for logged-in state with spending data.
    ///
    /// - Parameters:
    ///   - email: User email (default: "user@example.com")
    ///   - cents: Spending amount in cents (default: 2497)
    ///   - currencyCode: Display currency (default: "USD")
    /// - Returns: Tuple containing (userSession, spendingData, currencyData)
    @MainActor
    static func loggedInWithSpending(
        email: String = "user@example.com",
        cents: Int = 2497,
        currencyCode: String = "USD"
    ) -> (MultiProviderUserSessionData, MultiProviderSpendingData, CurrencyData) {
        let userSession = mockUserSession(email: email)
        let spendingData = mockSpendingData(cents: cents)
        let currencyData = mockCurrencyData(code: currencyCode)
        
        return (userSession, spendingData, currencyData)
    }
    
    /// Complete preview setup for logged-out state.
    ///
    /// - Returns: Tuple containing (userSession, spendingData, currencyData)
    @MainActor
    static func loggedOut() -> (MultiProviderUserSessionData, MultiProviderSpendingData, CurrencyData) {
        let userSession = emptyUserSession()
        let spendingData = emptySpendingData()
        let currencyData = mockCurrencyData()
        
        return (userSession, spendingData, currencyData)
    }
}