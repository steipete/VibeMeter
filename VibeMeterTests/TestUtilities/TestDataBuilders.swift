// swiftlint:disable file_length
import Foundation
@testable import VibeMeter

// MARK: - Test Data Builders

/// Builder pattern for creating test provider sessions
final class ProviderSessionBuilder: Sendable {
    private let provider: ServiceProvider
    private let teamId: Int?
    private let teamName: String?
    private let userEmail: String
    private let isActive: Bool

    init(
        provider: ServiceProvider = .cursor,
        teamId: Int? = nil,
        teamName: String? = nil,
        userEmail: String = "test@example.com",
        isActive: Bool = true) {
        self.provider = provider
        self.teamId = teamId
        self.teamName = teamName
        self.userEmail = userEmail
        self.isActive = isActive
    }

    func withProvider(_ provider: ServiceProvider) -> ProviderSessionBuilder {
        ProviderSessionBuilder(
            provider: provider,
            teamId: teamId,
            teamName: teamName,
            userEmail: userEmail,
            isActive: isActive)
    }

    func withTeam(id: Int, name: String) -> ProviderSessionBuilder {
        ProviderSessionBuilder(
            provider: provider,
            teamId: id,
            teamName: name,
            userEmail: userEmail,
            isActive: isActive)
    }

    func withEmail(_ email: String) -> ProviderSessionBuilder {
        ProviderSessionBuilder(
            provider: provider,
            teamId: teamId,
            teamName: teamName,
            userEmail: email,
            isActive: isActive)
    }

    func inactive() -> ProviderSessionBuilder {
        ProviderSessionBuilder(
            provider: provider,
            teamId: teamId,
            teamName: teamName,
            userEmail: userEmail,
            isActive: false)
    }

    func build() -> ProviderSession {
        ProviderSession(
            provider: provider,
            teamId: teamId,
            teamName: teamName,
            userEmail: userEmail,
            isActive: isActive)
    }
}

/// Builder pattern for creating test invoices
final class InvoiceBuilder: Sendable {
    private let provider: ServiceProvider
    private let items: [ProviderInvoiceItem]
    private let pricingDescription: ProviderPricingDescription?
    private let month: Int
    private let year: Int

    init(
        provider: ServiceProvider = .cursor,
        items: [ProviderInvoiceItem] = [],
        pricingDescription: ProviderPricingDescription? = nil,
        month: Int = 1,
        year: Int = 2025) {
        self.provider = provider
        self.items = items
        self.pricingDescription = pricingDescription
        self.month = month
        self.year = year
    }

    func withProvider(_ provider: ServiceProvider) -> InvoiceBuilder {
        InvoiceBuilder(
            provider: provider,
            items: items,
            pricingDescription: pricingDescription,
            month: month,
            year: year)
    }

    func withItem(cents: Int, description: String) -> InvoiceBuilder {
        let newItem = ProviderInvoiceItem(cents: cents, description: description, provider: provider)
        return InvoiceBuilder(
            provider: provider,
            items: items + [newItem],
            pricingDescription: pricingDescription,
            month: month,
            year: year)
    }

    func withItems(_ newItems: [ProviderInvoiceItem]) -> InvoiceBuilder {
        InvoiceBuilder(
            provider: provider,
            items: items + newItems,
            pricingDescription: pricingDescription,
            month: month,
            year: year)
    }

    func withPricing(description: String, id: String) -> InvoiceBuilder {
        let pricing = ProviderPricingDescription(description: description, id: id, provider: provider)
        return InvoiceBuilder(
            provider: provider,
            items: items,
            pricingDescription: pricing,
            month: month,
            year: year)
    }

    func forMonth(_ month: Int, year: Int) -> InvoiceBuilder {
        InvoiceBuilder(
            provider: provider,
            items: items,
            pricingDescription: pricingDescription,
            month: month,
            year: year)
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
            year: year)
    }
}

/// Builder pattern for creating test spending data
final class SpendingDataBuilder: Sendable {
    private let provider: ServiceProvider
    private let currentSpendingUSD: Double?
    private let currentSpendingConverted: Double?
    private let connectionStatus: ProviderConnectionStatus
    private let lastError: String?
    private let invoice: ProviderMonthlyInvoice?
    private let usageData: ProviderUsageData?
    private let warningLimit: Double
    private let upperLimit: Double

    init(
        provider: ServiceProvider = .cursor,
        currentSpendingUSD: Double? = nil,
        currentSpendingConverted: Double? = nil,
        connectionStatus: ProviderConnectionStatus = .connected,
        lastError: String? = nil,
        invoice: ProviderMonthlyInvoice? = nil,
        usageData: ProviderUsageData? = nil,
        warningLimit: Double = 100.0,
        upperLimit: Double = 200.0) {
        self.provider = provider
        self.currentSpendingUSD = currentSpendingUSD
        self.currentSpendingConverted = currentSpendingConverted
        self.connectionStatus = connectionStatus
        self.lastError = lastError
        self.invoice = invoice
        self.usageData = usageData
        self.warningLimit = warningLimit
        self.upperLimit = upperLimit
    }

    func withProvider(_ provider: ServiceProvider) -> SpendingDataBuilder {
        SpendingDataBuilder(
            provider: provider,
            currentSpendingUSD: currentSpendingUSD,
            currentSpendingConverted: currentSpendingConverted,
            connectionStatus: connectionStatus,
            lastError: lastError,
            invoice: invoice,
            usageData: usageData,
            warningLimit: warningLimit,
            upperLimit: upperLimit)
    }

    func withSpending(usd: Double, converted: Double? = nil) -> SpendingDataBuilder {
        SpendingDataBuilder(
            provider: provider,
            currentSpendingUSD: usd,
            currentSpendingConverted: converted ?? usd,
            connectionStatus: connectionStatus,
            lastError: lastError,
            invoice: invoice,
            usageData: usageData,
            warningLimit: warningLimit,
            upperLimit: upperLimit)
    }

    func withStatus(_ status: ProviderConnectionStatus) -> SpendingDataBuilder {
        SpendingDataBuilder(
            provider: provider,
            currentSpendingUSD: currentSpendingUSD,
            currentSpendingConverted: currentSpendingConverted,
            connectionStatus: status,
            lastError: lastError,
            invoice: invoice,
            usageData: usageData,
            warningLimit: warningLimit,
            upperLimit: upperLimit)
    }

    func withError(_ error: String) -> SpendingDataBuilder {
        SpendingDataBuilder(
            provider: provider,
            currentSpendingUSD: currentSpendingUSD,
            currentSpendingConverted: currentSpendingConverted,
            connectionStatus: connectionStatus,
            lastError: error,
            invoice: invoice,
            usageData: usageData,
            warningLimit: warningLimit,
            upperLimit: upperLimit)
    }

    func withInvoice(_ invoice: ProviderMonthlyInvoice) -> SpendingDataBuilder {
        SpendingDataBuilder(
            provider: provider,
            currentSpendingUSD: currentSpendingUSD,
            currentSpendingConverted: currentSpendingConverted,
            connectionStatus: connectionStatus,
            lastError: lastError,
            invoice: invoice,
            usageData: usageData,
            warningLimit: warningLimit,
            upperLimit: upperLimit)
    }

    func withUsage(current: Int, total: Int, max: Int) -> SpendingDataBuilder {
        let usage = ProviderUsageData(
            currentRequests: current,
            totalRequests: total,
            maxRequests: max,
            startOfMonth: Date(),
            provider: provider)
        return SpendingDataBuilder(
            provider: provider,
            currentSpendingUSD: currentSpendingUSD,
            currentSpendingConverted: currentSpendingConverted,
            connectionStatus: connectionStatus,
            lastError: lastError,
            invoice: invoice,
            usageData: usage,
            warningLimit: warningLimit,
            upperLimit: upperLimit)
    }

    func withLimits(warning: Double, upper: Double) -> SpendingDataBuilder {
        SpendingDataBuilder(
            provider: provider,
            currentSpendingUSD: currentSpendingUSD,
            currentSpendingConverted: currentSpendingConverted,
            connectionStatus: connectionStatus,
            lastError: lastError,
            invoice: invoice,
            usageData: usageData,
            warningLimit: warning,
            upperLimit: upper)
    }

    func build() -> ProviderSpendingData {
        ProviderSpendingData(
            provider: provider,
            currentSpendingUSD: currentSpendingUSD,
            currentSpendingConverted: currentSpendingConverted,
            warningLimitConverted: warningLimit,
            upperLimitConverted: upperLimit,
            latestInvoiceResponse: invoice,
            usageData: usageData,
            connectionStatus: connectionStatus,
            lastError: lastError)
    }
}

/// Builder pattern for creating test currency data
@MainActor
final class CurrencyDataBuilder {
    private let selectedCode: String
    private let selectedSymbol: String
    private let exchangeRates: [String: Double]
    private let lastUpdated: Date
    private let isUpdating: Bool
    private let ratesAvailable: Bool

    init(
        selectedCode: String = "USD",
        selectedSymbol: String = "$",
        exchangeRates: [String: Double] = [:],
        lastUpdated: Date = Date(),
        isUpdating: Bool = false,
        ratesAvailable: Bool = true) {
        self.selectedCode = selectedCode
        self.selectedSymbol = selectedSymbol
        self.exchangeRates = exchangeRates
        self.lastUpdated = lastUpdated
        self.isUpdating = isUpdating
        self.ratesAvailable = ratesAvailable
    }

    func withCurrency(_ code: String, symbol: String) -> CurrencyDataBuilder {
        CurrencyDataBuilder(
            selectedCode: code,
            selectedSymbol: symbol,
            exchangeRates: exchangeRates,
            lastUpdated: lastUpdated,
            isUpdating: isUpdating,
            ratesAvailable: ratesAvailable)
    }

    func withRates(_ rates: [String: Double]) -> CurrencyDataBuilder {
        CurrencyDataBuilder(
            selectedCode: selectedCode,
            selectedSymbol: selectedSymbol,
            exchangeRates: rates,
            lastUpdated: lastUpdated,
            isUpdating: isUpdating,
            ratesAvailable: ratesAvailable)
    }

    func withStandardRates() -> CurrencyDataBuilder {
        CurrencyDataBuilder(
            selectedCode: selectedCode,
            selectedSymbol: selectedSymbol,
            exchangeRates: [
                "EUR": 0.92,
                "GBP": 0.82,
                "JPY": 110.0,
                "AUD": 1.35,
                "CAD": 1.25,
            ],
            lastUpdated: lastUpdated,
            isUpdating: isUpdating,
            ratesAvailable: ratesAvailable)
    }

    func updating() -> CurrencyDataBuilder {
        CurrencyDataBuilder(
            selectedCode: selectedCode,
            selectedSymbol: selectedSymbol,
            exchangeRates: exchangeRates,
            lastUpdated: lastUpdated,
            isUpdating: true,
            ratesAvailable: ratesAvailable)
    }

    func ratesUnavailable() -> CurrencyDataBuilder {
        CurrencyDataBuilder(
            selectedCode: selectedCode,
            selectedSymbol: selectedSymbol,
            exchangeRates: exchangeRates,
            lastUpdated: lastUpdated,
            isUpdating: isUpdating,
            ratesAvailable: false)
    }

    func lastUpdated(_ date: Date) -> CurrencyDataBuilder {
        CurrencyDataBuilder(
            selectedCode: selectedCode,
            selectedSymbol: selectedSymbol,
            exchangeRates: exchangeRates,
            lastUpdated: date,
            isUpdating: isUpdating,
            ratesAvailable: ratesAvailable)
    }

    func build() -> CurrencyData {
        let data = CurrencyData()
        data.updateSelectedCurrency(selectedCode)
        if !exchangeRates.isEmpty {
            data.updateExchangeRates(exchangeRates)
        }
        return data
    }
}

// MARK: - Test Scenario Builders

enum TestScenarios {
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
        SpendingDataBuilder()
            .withSpending(usd: warningLimit * 0.76) // Just above 75%
            .withLimits(warning: warningLimit, upper: warningLimit * 2)
            .build()
    }

    /// Creates a scenario with spending over limit
    static func overLimit(limit: Double = 100.0) -> ProviderSpendingData {
        SpendingDataBuilder()
            .withSpending(usd: limit * 1.2) // 20% over
            .withLimits(warning: limit * 0.75, upper: limit)
            .withStatus(.connected)
            .build()
    }

    /// Creates a scenario with connection error
    static func connectionError() -> ProviderSpendingData {
        SpendingDataBuilder()
            .withStatus(.error(message: "Network connection failed"))
            .withError("Network connection failed")
            .build()
    }

    /// Creates a scenario with rate limiting
    static func rateLimited(until: Date? = Date(timeIntervalSinceNow: 3600)) -> ProviderSpendingData {
        SpendingDataBuilder()
            .withStatus(.rateLimited(until: until))
            .withError("Rate limit exceeded")
            .build()
    }
}
