@testable import VibeMeter
import XCTest

/// Tests for the focused SpendingData observable model.
///
/// These tests follow Thomas Ricouard's modern SwiftUI testing principles:
/// - Fast, focused unit tests
/// - No complex setup or shared state
/// - Direct testing of business logic
/// - Clear test boundaries
@MainActor
final class SpendingDataTests: XCTestCase, @unchecked Sendable {
    var spendingData: SpendingData!

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            spendingData = SpendingData()
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
        // All properties should start as nil/empty
        XCTAssertNil(spendingData.currentSpendingUSD)
        XCTAssertNil(spendingData.currentSpendingConverted)
        XCTAssertNil(spendingData.warningLimitConverted)
        XCTAssertNil(spendingData.upperLimitConverted)
        XCTAssertNil(spendingData.latestInvoiceResponse)
        XCTAssertNil(spendingData.displaySpending)
        XCTAssertNil(spendingData.displayWarningLimit)
        XCTAssertNil(spendingData.displayUpperLimit)
    }

    // MARK: - Update Spending Tests

    func testUpdateSpending_USD_SetsCorrectValues() {
        // Arrange
        let invoice = MonthlyInvoice(
            items: [
                InvoiceItem(cents: 5000, description: "API calls"),
                InvoiceItem(cents: 3000, description: "Storage"),
            ],
            pricingDescription: nil)
        let rates: [String: Double] = [:]
        let targetCurrency = "USD"

        // Act
        spendingData.updateSpending(from: invoice, rates: rates, targetCurrency: targetCurrency)

        // Assert
        XCTAssertEqual(spendingData.currentSpendingUSD!, 80.0, accuracy: 0.01)
        XCTAssertEqual(spendingData.currentSpendingConverted!, 80.0, accuracy: 0.01)
        XCTAssertEqual(spendingData.latestInvoiceResponse?.totalSpendingCents, 8000)
        XCTAssertEqual(spendingData.displaySpending!, 80.0, accuracy: 0.01)
    }

    func testUpdateSpending_EUR_ConvertsCorrectly() {
        // Arrange
        let invoice = MonthlyInvoice(
            items: [InvoiceItem(cents: 10000, description: "API calls")],
            pricingDescription: nil)
        let rates = ["EUR": 0.9]
        let targetCurrency = "EUR"

        // Act
        spendingData.updateSpending(from: invoice, rates: rates, targetCurrency: targetCurrency)

        // Assert
        XCTAssertEqual(spendingData.currentSpendingUSD!, 100.0, accuracy: 0.01)
        XCTAssertEqual(spendingData.currentSpendingConverted!, 90.0, accuracy: 0.01) // 100 * 0.9
        XCTAssertEqual(spendingData.displaySpending!, 90.0, accuracy: 0.01)
    }

    func testUpdateSpending_NonUSD_NoRates_FallsBackToUSD() {
        // Arrange
        let invoice = MonthlyInvoice(
            items: [InvoiceItem(cents: 5000, description: "Test")],
            pricingDescription: nil)
        let rates: [String: Double] = [:] // No rates available
        let targetCurrency = "EUR"

        // Act
        spendingData.updateSpending(from: invoice, rates: rates, targetCurrency: targetCurrency)

        // Assert
        XCTAssertEqual(spendingData.currentSpendingUSD!, 50.0, accuracy: 0.01)
        XCTAssertEqual(spendingData.currentSpendingConverted!, 50.0, accuracy: 0.01) // Falls back to USD
        XCTAssertEqual(spendingData.displaySpending!, 50.0, accuracy: 0.01)
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
            warningUSD: warningUSD,
            upperUSD: upperUSD,
            rates: rates,
            targetCurrency: targetCurrency)

        // Assert
        XCTAssertEqual(spendingData.warningLimitConverted!, 200.0, accuracy: 0.01)
        XCTAssertEqual(spendingData.upperLimitConverted!, 1000.0, accuracy: 0.01)
        XCTAssertEqual(spendingData.displayWarningLimit!, 200.0, accuracy: 0.01)
        XCTAssertEqual(spendingData.displayUpperLimit!, 1000.0, accuracy: 0.01)
    }

    func testUpdateLimits_EUR_ConvertsCorrectly() {
        // Arrange
        let warningUSD = 200.0
        let upperUSD = 1000.0
        let rates = ["EUR": 0.85]
        let targetCurrency = "EUR"

        // Act
        spendingData.updateLimits(
            warningUSD: warningUSD,
            upperUSD: upperUSD,
            rates: rates,
            targetCurrency: targetCurrency)

        // Assert
        XCTAssertEqual(spendingData.warningLimitConverted!, 170.0, accuracy: 0.01) // 200 * 0.85
        XCTAssertEqual(spendingData.upperLimitConverted!, 850.0, accuracy: 0.01) // 1000 * 0.85
        XCTAssertEqual(spendingData.displayWarningLimit!, 170.0, accuracy: 0.01)
        XCTAssertEqual(spendingData.displayUpperLimit!, 850.0, accuracy: 0.01)
    }

    func testUpdateLimits_InvalidRate_FallsBackToUSD() {
        // Arrange
        let warningUSD = 200.0
        let upperUSD = 1000.0
        let rates: [String: Double] = [:] // No EUR rate
        let targetCurrency = "EUR"

        // Act
        spendingData.updateLimits(
            warningUSD: warningUSD,
            upperUSD: upperUSD,
            rates: rates,
            targetCurrency: targetCurrency)

        // Assert - Should fall back to USD amounts
        XCTAssertEqual(spendingData.warningLimitConverted!, 200.0, accuracy: 0.01)
        XCTAssertEqual(spendingData.upperLimitConverted!, 1000.0, accuracy: 0.01)
    }

    // MARK: - Clear Tests

    func testClear_ResetsAllProperties() {
        // Arrange - Set some values first
        let invoice = MonthlyInvoice(
            items: [InvoiceItem(cents: 5000, description: "Test")],
            pricingDescription: nil)
        spendingData.updateSpending(from: invoice, rates: [:], targetCurrency: "USD")
        spendingData.updateLimits(warningUSD: 200.0, upperUSD: 1000.0, rates: [:], targetCurrency: "USD")

        // Verify values are set
        XCTAssertNotNil(spendingData.currentSpendingUSD)
        XCTAssertNotNil(spendingData.displaySpending)

        // Act
        spendingData.clear()

        // Assert - All values should be cleared
        XCTAssertNil(spendingData.currentSpendingUSD)
        XCTAssertNil(spendingData.currentSpendingConverted)
        XCTAssertNil(spendingData.warningLimitConverted)
        XCTAssertNil(spendingData.upperLimitConverted)
        XCTAssertNil(spendingData.latestInvoiceResponse)
        XCTAssertNil(spendingData.displaySpending)
        XCTAssertNil(spendingData.displayWarningLimit)
        XCTAssertNil(spendingData.displayUpperLimit)
    }

    // MARK: - Display Properties Tests

    func testDisplaySpending_ReturnsConvertedWhenAvailable() {
        // Arrange
        let invoice = MonthlyInvoice(
            items: [InvoiceItem(cents: 10000, description: "Test")],
            pricingDescription: nil)
        spendingData.updateSpending(from: invoice, rates: ["EUR": 0.9], targetCurrency: "EUR")

        // Act & Assert
        XCTAssertEqual(spendingData.displaySpending!, 90.0, accuracy: 0.01) // Converted amount
    }

    func testDisplaySpending_FallsBackToUSD() {
        // Arrange
        let invoice = MonthlyInvoice(
            items: [InvoiceItem(cents: 10000, description: "Test")],
            pricingDescription: nil)
        spendingData.updateSpending(from: invoice, rates: [:], targetCurrency: "USD")

        // Act & Assert
        XCTAssertEqual(spendingData.displaySpending!, 100.0, accuracy: 0.01) // USD amount
    }

    func testDisplaySpending_NilWhenNoData() {
        // No spending data set
        XCTAssertNil(spendingData.displaySpending)
    }
}
