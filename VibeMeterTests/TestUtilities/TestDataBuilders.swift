import Foundation
@testable import VibeMeter

// MARK: - Test Data Builders

/// Builder pattern for creating test provider sessions
@MainActor
final class ProviderSessionBuilder {
    private var provider: ServiceProvider = .cursor
    private var teamId: Int?
    private var teamName: String?
    private var userEmail: String = "test@example.com"
    private var isActive: Bool = true
    
    func with(provider: ServiceProvider) -> Self {
        self.provider = provider
        return self
    }
    
    func withTeam(id: Int, name: String) -> Self {
        self.teamId = id
        self.teamName = name
        return self
    }
    
    func withEmail(_ email: String) -> Self {
        self.userEmail = email
        return self
    }
    
    func inactive() -> Self {
        self.isActive = false
        return self
    }
    
    func build() -> ProviderSession {
        ProviderSession(
            provider: provider,
            teamId: teamId,
            teamName: teamName,
            userEmail: userEmail,
            isActive: isActive
        )
    }
}

/// Builder pattern for creating test invoices
@MainActor
final class InvoiceBuilder {
    private var provider: ServiceProvider = .cursor
    private var items: [ProviderInvoiceItem] = []
    private var pricingDescription: ProviderPricingDescription?
    private var month: Int = 1
    private var year: Int = 2025
    
    func for(provider: ServiceProvider) -> Self {
        self.provider = provider
        return self
    }
    
    func withItem(cents: Int, description: String) -> Self {
        items.append(ProviderInvoiceItem(cents: cents, description: description, provider: provider))
        return self
    }
    
    func withItems(_ newItems: [ProviderInvoiceItem]) -> Self {
        items.append(contentsOf: newItems)
        return self
    }
    
    func withPricing(description: String, id: String) -> Self {
        self.pricingDescription = ProviderPricingDescription(description: description, id: id)
        return self
    }
    
    func forMonth(_ month: Int, year: Int) -> Self {
        self.month = month
        self.year = year
        return self
    }
    
    func build() -> ProviderMonthlyInvoice {
        // If no items specified, add a default item
        let finalItems = items.isEmpty ? [
            ProviderInvoiceItem(cents: 5000, description: "Default usage", provider: provider)
        ] : items
        
        return ProviderMonthlyInvoice(
            items: finalItems,
            pricingDescription: pricingDescription,
            provider: provider,
            month: month,
            year: year
        )
    }
}

/// Builder pattern for creating test spending data
@MainActor
final class SpendingDataBuilder {
    private var provider: ServiceProvider = .cursor
    private var currentSpendingUSD: Double?
    private var displaySpending: Double?
    private var connectionStatus: ProviderConnectionStatus = .connected
    private var lastError: String?
    private var invoice: ProviderMonthlyInvoice?
    private var usageData: ProviderUsageData?
    private var warningLimit: Double = 100.0
    private var upperLimit: Double = 200.0
    
    func for(provider: ServiceProvider) -> Self {
        self.provider = provider
        return self
    }
    
    func withSpending(usd: Double, display: Double? = nil) -> Self {
        self.currentSpendingUSD = usd
        self.displaySpending = display ?? usd
        return self
    }
    
    func withStatus(_ status: ProviderConnectionStatus) -> Self {
        self.connectionStatus = status
        return self
    }
    
    func withError(_ error: String) -> Self {
        self.lastError = error
        return self
    }
    
    func withInvoice(_ invoice: ProviderMonthlyInvoice) -> Self {
        self.invoice = invoice
        return self
    }
    
    func withUsage(current: Int, total: Int, max: Int) -> Self {
        self.usageData = ProviderUsageData(
            currentRequests: current,
            totalRequests: total,
            maxRequests: max,
            startOfMonth: Date(),
            provider: provider
        )
        return self
    }
    
    func withLimits(warning: Double, upper: Double) -> Self {
        self.warningLimit = warning
        self.upperLimit = upper
        return self
    }
    
    func build() -> ProviderSpendingData {
        ProviderSpendingData(
            provider: provider,
            currentSpendingUSD: currentSpendingUSD,
            currentSpendingConverted: currentSpendingUSD,
            displaySpending: displaySpending ?? currentSpendingUSD ?? 0,
            displayCurrency: "USD",
            connectionStatus: connectionStatus,
            lastUpdateTime: Date(),
            lastError: lastError,
            latestInvoiceResponse: invoice,
            usageData: usageData,
            warningLimitConverted: warningLimit,
            upperLimitConverted: upperLimit
        )
    }
}

/// Builder pattern for creating test currency data
@MainActor 
final class CurrencyDataBuilder {
    private var selectedCode: String = "USD"
    private var selectedSymbol: String = "$"
    private var exchangeRates: [String: Double] = [:]
    private var lastUpdated: Date = Date()
    private var isUpdating: Bool = false
    private var ratesAvailable: Bool = true
    
    func withCurrency(_ code: String, symbol: String) -> Self {
        self.selectedCode = code
        self.selectedSymbol = symbol
        return self
    }
    
    func withRates(_ rates: [String: Double]) -> Self {
        self.exchangeRates = rates
        return self
    }
    
    func withStandardRates() -> Self {
        self.exchangeRates = [
            "EUR": 0.92,
            "GBP": 0.82,
            "JPY": 110.0,
            "AUD": 1.35,
            "CAD": 1.25
        ]
        return self
    }
    
    func updating() -> Self {
        self.isUpdating = true
        return self
    }
    
    func ratesUnavailable() -> Self {
        self.ratesAvailable = false
        return self
    }
    
    func lastUpdated(_ date: Date) -> Self {
        self.lastUpdated = date
        return self
    }
    
    func build() -> CurrencyData {
        let data = CurrencyData()
        data.updateSelectedCurrency(selectedCode)
        if !exchangeRates.isEmpty {
            data.updateExchangeRates(exchangeRates, lastUpdated: lastUpdated)
        }
        return data
    }
}

// MARK: - Test Scenario Builders

/// Creates common test scenarios for multi-provider testing
struct TestScenarios {
    
    /// Creates a scenario with a single active provider
    static func singleActiveProvider() -> (session: ProviderSession, invoice: ProviderMonthlyInvoice) {
        let session = ProviderSessionBuilder()
            .withTeam(id: 12345, name: "Test Team")
            .build()
        
        let invoice = InvoiceBuilder()
            .withItem(cents: 5000, description: "API Usage")
            .withItem(cents: 3000, description: "Storage")
            .build()
        
        return (session, invoice)
    }
    
    /// Creates a scenario with spending near warning limit
    static func nearWarningLimit(warningLimit: Double = 100.0) -> ProviderSpendingData {
        return SpendingDataBuilder()
            .withSpending(usd: warningLimit * 0.76) // Just above 75%
            .withLimits(warning: warningLimit, upper: warningLimit * 2)
            .build()
    }
    
    /// Creates a scenario with spending over limit
    static func overLimit(limit: Double = 100.0) -> ProviderSpendingData {
        return SpendingDataBuilder()
            .withSpending(usd: limit * 1.2) // 20% over
            .withLimits(warning: limit * 0.75, upper: limit)
            .withStatus(.connected)
            .build()
    }
    
    /// Creates a scenario with connection error
    static func connectionError() -> ProviderSpendingData {
        return SpendingDataBuilder()
            .withStatus(.error(message: "Network connection failed"))
            .withError("Network connection failed")
            .build()
    }
    
    /// Creates a scenario with rate limiting
    static func rateLimited(until: Date? = Date(timeIntervalSinceNow: 3600)) -> ProviderSpendingData {
        return SpendingDataBuilder()
            .withStatus(.rateLimited(until: until))
            .withError("Rate limit exceeded")
            .build()
    }
}