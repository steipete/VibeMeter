@testable import VibeMeter
import XCTest

/// Tests for the MultiProviderSpendingData observable model.
///
/// These tests follow Thomas Ricouard's modern SwiftUI testing principles:
/// - Fast, focused unit tests
/// - No complex setup or shared state
/// - Direct testing of business logic
/// - Clear test boundaries
@MainActor
final class MultiProviderSpendingDataTests: XCTestCase, @unchecked Sendable {
    var spendingData: MultiProviderSpendingData!

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            spendingData = MultiProviderSpendingData()
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            spendingData = nil
        }
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        // All properties should start as empty
        XCTAssertTrue(spendingData.providersWithData.isEmpty)
        XCTAssertEqual(spendingData.totalSpendingConverted(to: "USD", rates: [:]), 0.0)
        XCTAssertNil(spendingData.getSpendingData(for: .cursor))
    }

    // MARK: - Update Spending Tests

    func testUpdateSpending_USD_SetsCorrectValues() {
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
        XCTAssertTrue(spendingData.providersWithData.contains(.cursor))

        let cursorData = spendingData.getSpendingData(for: .cursor)
        XCTAssertNotNil(cursorData)
        XCTAssertEqual(cursorData?.currentSpendingUSD, 80.0, accuracy: 0.01)
        XCTAssertEqual(cursorData?.displaySpending, 80.0, accuracy: 0.01)
        XCTAssertEqual(cursorData?.latestInvoiceResponse?.totalSpendingCents, 8000)
    }

    func testUpdateSpending_EUR_ConvertsCorrectly() {
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
        XCTAssertEqual(cursorData?.currentSpendingUSD, 100.0, accuracy: 0.01)
        XCTAssertEqual(cursorData?.displaySpending, 90.0, accuracy: 0.01) // 100 * 0.9
    }

    func testUpdateSpending_NonUSD_NoRates_FallsBackToUSD() {
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
        XCTAssertEqual(cursorData?.currentSpendingUSD, 50.0, accuracy: 0.01)
        XCTAssertEqual(cursorData?.displaySpending, 50.0, accuracy: 0.01) // Falls back to USD
    }

    // MARK: - Update Limits Tests

    func testUpdateLimits_USD_SetsDirectly() {
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
        XCTAssertEqual(cursorData?.warningLimitConverted, 200.0, accuracy: 0.01)
        XCTAssertEqual(cursorData?.upperLimitConverted, 1000.0, accuracy: 0.01)
    }

    func testUpdateLimits_EUR_ConvertsCorrectly() {
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
        XCTAssertEqual(cursorData?.warningLimitConverted, 170.0, accuracy: 0.01) // 200 * 0.85
        XCTAssertEqual(cursorData?.upperLimitConverted, 850.0, accuracy: 0.01) // 1000 * 0.85
    }

    func testUpdateLimits_InvalidRate_FallsBackToUSD() {
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
        XCTAssertEqual(cursorData?.warningLimitConverted, 200.0, accuracy: 0.01)
        XCTAssertEqual(cursorData?.upperLimitConverted, 1000.0, accuracy: 0.01)
    }

    // MARK: - Usage Data Tests

    func testUpdateUsage_SetsCorrectValues() {
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
        XCTAssertNotNil(cursorData?.usageData)
        XCTAssertEqual(cursorData?.usageData?.currentRequests, 150)
        XCTAssertEqual(cursorData?.usageData?.totalRequests, 4387)
        XCTAssertEqual(cursorData?.usageData?.maxRequests, 500)
        XCTAssertEqual(cursorData?.usageData?.provider, .cursor)
    }

    // MARK: - Clear Tests

    func testClear_SpecificProvider_RemovesOnlyThatProvider() {
        // Arrange - Set up data for cursor
        let invoice = ProviderMonthlyInvoice(
            items: [ProviderInvoiceItem(cents: 5000, description: "Test", provider: .cursor)],
            pricingDescription: nil,
            provider: .cursor,
            month: 5,
            year: 2025)
        spendingData.updateSpending(for: .cursor, from: invoice, rates: [:], targetCurrency: "USD")

        // Verify data is set
        XCTAssertTrue(spendingData.providersWithData.contains(.cursor))

        // Act
        spendingData.clear(provider: .cursor)

        // Assert - Cursor data should be removed
        XCTAssertFalse(spendingData.providersWithData.contains(.cursor))
        XCTAssertNil(spendingData.getSpendingData(for: .cursor))
    }

    // MARK: - Multi-Provider Tests

    func testMultipleProviders_IndependentData() {
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
        XCTAssertTrue(spendingData.providersWithData.contains(.cursor))
        XCTAssertEqual(spendingData.providersWithData.count, 1)

        let cursorData = spendingData.getSpendingData(for: .cursor)
        XCTAssertNotNil(cursorData)
        XCTAssertEqual(cursorData?.currentSpendingUSD, 50.0, accuracy: 0.01)
    }

    func testTotalSpending_MultipleProviders() {
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
        XCTAssertEqual(totalUSD, 50.0, accuracy: 0.01)

        let totalEUR = spendingData.totalSpendingConverted(to: "EUR", rates: ["EUR": 0.9])
        XCTAssertEqual(totalEUR, 45.0, accuracy: 0.01) // 50 * 0.9
    }

    func testTotalSpending_NoProviders_ReturnsZero() {
        // Act & Assert
        let total = spendingData.totalSpendingConverted(to: "USD", rates: [:])
        XCTAssertEqual(total, 0.0)
    }

    // MARK: - Edge Cases

    func testUpdateSpending_OverwritesPreviousData() {
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
        XCTAssertEqual(cursorData?.currentSpendingUSD, 100.0, accuracy: 0.01) // From invoice2
        XCTAssertEqual(cursorData?.latestInvoiceResponse?.totalSpendingCents, 10000)
    }

    func testGetSpendingData_NonExistentProvider_ReturnsNil() {
        // Act & Assert
        XCTAssertNil(spendingData.getSpendingData(for: .cursor))
    }
}
