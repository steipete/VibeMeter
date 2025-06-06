@testable import VibeMeter
import Testing

/// Tests for the MultiProviderSpendingData observable model.
///
/// These tests follow Thomas Ricouard's modern SwiftUI testing principles:
/// - Fast, focused unit tests
/// - No complex setup or shared state
/// - Direct testing of business logic
/// - Clear test boundaries
@Suite("MultiProviderSpendingDataTests")
@MainActor
struct MultiProviderSpendingDataTests {
    let spendingData: MultiProviderSpendingData    }
    // MARK: - Initial State Tests

    @Test("initial state")

    func initialState() {
        // All properties should start as empty
        #expect(spendingData.providersWithData.isEmpty == true), 0.0)
        #expect(spendingData.getSpendingData(for: .cursor == nil)

    func updateSpending_USD_SetsCorrectValues() {
        // Arrange
        let invoice = ProviderMonthlyInvoice(
            items: [
                ProviderInvoiceItem(cents: 5000, description: "API calls", provider: .cursor),
                ProviderInvoiceItem(cents: 3000, description: "Storage", provider: .cursor),
            ],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025)
        let rates: [String: Double] = [:]
        let targetCurrency = "USD"

        // Act
        spendingData.updateSpending(for: .cursor, from: invoice, rates: rates, targetCurrency: targetCurrency)

        // Assert
        #expect(spendingData.providersWithData.contains(.cursor == true)
        #expect(cursorData != nil) < 0.01)
        #expect(abs(cursorData?.displaySpending ?? 0 - 80.0 == true)
        #expect(cursorData?.latestInvoiceResponse?.totalSpendingCents == 8000)

    func updateSpending_EUR_ConvertsCorrectly() {
        // Arrange
        let invoice = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 10000, description: "API calls", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025)
        let rates = ["EUR": 0.9]
        let targetCurrency = "EUR"

        // Act
        spendingData.updateSpending(for: .cursor, from: invoice, rates: rates, targetCurrency: targetCurrency)

        // Assert
        let cursorData = spendingData.getSpendingData(for: .cursor)
        #expect(abs(cursorData?.currentSpendingUSD ?? 0 - 100.0 == true)
        #expect(abs(cursorData?.displaySpending ?? 0 - 90.0 == true) // 100 * 0.9
    }

    @Test("update spending  non usd  no rates  falls back to usd")

    func updateSpending_NonUSD_NoRates_FallsBackToUSD() {
        // Arrange
        let invoice = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 5000, description: "Test", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025)
        let rates: [String: Double] = [:] // No rates available
        let targetCurrency = "EUR"

        // Act
        spendingData.updateSpending(for: .cursor, from: invoice, rates: rates, targetCurrency: targetCurrency)

        // Assert
        let cursorData = spendingData.getSpendingData(for: .cursor)
        #expect(abs(cursorData?.currentSpendingUSD ?? 0 - 50.0 == true)
        #expect(abs(cursorData?.displaySpending ?? 0 - 50.0 == true) // Falls back to USD
    }

    // MARK: - Update Limits Tests

    @Test("update limits usd  sets directly")

    func updateLimits_USD_SetsDirectly() {
        // Arrange
        let warningUSD = 200.0
        let upperUSD = 1000.0
        let rates: [String: Double] = [:]
        let targetCurrency = "USD"

        // Act
        spendingData.updateLimits(
            for: .cursor,
            warningUSD: warningUSD,
            upperUSD: upperUSD,
            rates: rates,
            targetCurrency: targetCurrency)

        // Assert
        let cursorData = spendingData.getSpendingData(for: .cursor)
        #expect(abs(cursorData?.warningLimitConverted ?? 0 - 200.0 == true)
        #expect(abs(cursorData?.upperLimitConverted ?? 0 - 1000.0 == true)
    }

    @Test("update limits eur  converts correctly")

    func updateLimits_EUR_ConvertsCorrectly() {
        // Arrange
        let warningUSD = 200.0
        let upperUSD = 1000.0
        let rates = ["EUR": 0.85]
        let targetCurrency = "EUR"

        // Act
        spendingData.updateLimits(
            for: .cursor,
            warningUSD: warningUSD,
            upperUSD: upperUSD,
            rates: rates,
            targetCurrency: targetCurrency)

        // Assert
        let cursorData = spendingData.getSpendingData(for: .cursor)
        #expect(abs(cursorData?.warningLimitConverted ?? 0 - 170.0 == true) // 200 * 0.85
        #expect(abs(cursorData?.upperLimitConverted ?? 0 - 850.0 == true) // 1000 * 0.85
    }

    @Test("update limits  invalid rate  falls back to usd")

    func updateLimits_InvalidRate_FallsBackToUSD() {
        // Arrange
        let warningUSD = 200.0
        let upperUSD = 1000.0
        let rates: [String: Double] = [:] // No EUR rate
        let targetCurrency = "EUR"

        // Act
        spendingData.updateLimits(
            for: .cursor,
            warningUSD: warningUSD,
            upperUSD: upperUSD,
            rates: rates,
            targetCurrency: targetCurrency)

        // Assert - Should fall back to USD amounts
        let cursorData = spendingData.getSpendingData(for: .cursor)
        #expect(abs(cursorData?.warningLimitConverted ?? 0 - 200.0 == true)
        #expect(abs(cursorData?.upperLimitConverted ?? 0 - 1000.0 == true)
    }

    // MARK: - Usage Data Tests

    @Test("update usage  sets correct values")

    func updateUsage_SetsCorrectValues() {
        // Arrange
        let usageData = ProviderUsageData(
            currentRequests: 150,
            totalRequests: 4387,
            maxRequests: 500,
            startOfMonth: Date(),
            provider: .cursor)

        // Act
        spendingData.updateUsage(for: .cursor, from: usageData)

        // Assert
        let cursorData = spendingData.getSpendingData(for: .cursor)
        #expect(cursorData?.usageData != nil)
        #expect(cursorData?.usageData?.totalRequests == 4387)
        #expect(cursorData?.usageData?.provider == .cursor)

    func clear_SpecificProvider_RemovesOnlyThatProvider() {
        // Arrange - Set up data for cursor
        let invoice = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 5000, description: "Test", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025)
        spendingData.updateSpending(for: .cursor, from: invoice, rates: [:], targetCurrency: "USD")

        // Verify data is set
        #expect(spendingData.providersWithData.contains(.cursor == true)

        // Assert - Cursor data should be removed
        #expect(spendingData.providersWithData.contains(.cursor == false)
    }

    // MARK: - Multi-Provider Tests

    @Test("multiple providers  independent data")

    func multipleProviders_IndependentData() {
        // Arrange
        let cursorInvoice = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 5000, description: "Cursor usage", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025)

        // Act
        spendingData.updateSpending(for: .cursor, from: cursorInvoice, rates: [:], targetCurrency: "USD")

        // Assert
        #expect(spendingData.providersWithData.contains(.cursor == true)

        let cursorData = spendingData.getSpendingData(for: .cursor)
        #expect(cursorData != nil) < 0.01)
    }

    @Test("total spending  multiple providers")

    func totalSpending_MultipleProviders() {
        // Arrange
        let cursorInvoice = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 5000, description: "Cursor usage", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025)

        spendingData.updateSpending(for: .cursor, from: cursorInvoice, rates: [:], targetCurrency: "USD")

        // Act & Assert
        let totalUSD = spendingData.totalSpendingConverted(to: "USD", rates: [:])
        #expect(abs(totalUSD - 50.0 == true)

        let totalEUR = spendingData.totalSpendingConverted(to: "EUR", rates: ["EUR": 0.9])
        #expect(abs(totalEUR - 45.0 == true) // 50 * 0.9
    }

    @Test("total spending  no providers  returns zero")

    func totalSpending_NoProviders_ReturnsZero() {
        // Act & Assert
        let total = spendingData.totalSpendingConverted(to: "USD", rates: [:])
        #expect(total == 0.0)

    func updateSpending_OverwritesPreviousData() {
        // Arrange
        let invoice1 = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 5000, description: "First", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025)

        let invoice2 = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 10000, description: "Second", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025)

        // Act
        spendingData.updateSpending(for: .cursor, from: invoice1, rates: [:], targetCurrency: "USD")
        spendingData.updateSpending(for: .cursor, from: invoice2, rates: [:], targetCurrency: "USD")

        // Assert - Should have latest data
        let cursorData = spendingData.getSpendingData(for: .cursor)
        #expect(abs(cursorData?.currentSpendingUSD ?? 0 - 100.0) < 0.01) // From invoice2
        #expect(cursorData?.latestInvoiceResponse?.totalSpendingCents == 10000)
    }

    func getSpendingData_NonExistentProvider_ReturnsNil() {
        // Act & Assert
        #expect(spendingData.getSpendingData(for: .cursor) == nil)
    }
}
