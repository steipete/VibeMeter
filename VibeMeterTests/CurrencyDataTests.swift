@testable import VibeMeter
import XCTest

/// Tests for the focused CurrencyData observable model.
///
/// These tests follow modern SwiftUI testing principles:
/// - Fast, isolated unit tests
/// - No external dependencies or mocks needed
/// - Direct state verification
/// - Clear test boundaries and responsibilities
@MainActor
final class CurrencyDataTests: XCTestCase, @unchecked Sendable {
    var currencyData: CurrencyData!

    override func setUp() {
        super.setUp()
        MainActor.assumeIsolated {
            currencyData = CurrencyData()
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            currencyData = nil
        }
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        // Currency data should start with USD defaults
        XCTAssertEqual(currencyData.selectedCode, "USD")
        XCTAssertEqual(currencyData.selectedSymbol, "$")
        XCTAssertTrue(currencyData.exchangeRatesAvailable)
        XCTAssertTrue(currencyData.currentExchangeRates.isEmpty)
    }

    // MARK: - Currency Selection Tests

    func testUpdateSelectedCurrency_USD_SetsCorrectValues() {
        // Act
        currencyData.updateSelectedCurrency("USD")

        // Assert
        XCTAssertEqual(currencyData.selectedCode, "USD")
        XCTAssertEqual(currencyData.selectedSymbol, "$")
    }

    func testUpdateSelectedCurrency_EUR_SetsCorrectValues() {
        // Act
        currencyData.updateSelectedCurrency("EUR")

        // Assert
        XCTAssertEqual(currencyData.selectedCode, "EUR")
        XCTAssertEqual(currencyData.selectedSymbol, "€")
    }

    func testUpdateSelectedCurrency_GBP_SetsCorrectValues() {
        // Act
        currencyData.updateSelectedCurrency("GBP")

        // Assert
        XCTAssertEqual(currencyData.selectedCode, "GBP")
        XCTAssertEqual(currencyData.selectedSymbol, "£")
    }

    func testUpdateSelectedCurrency_JPY_SetsCorrectValues() {
        // Act
        currencyData.updateSelectedCurrency("JPY")

        // Assert
        XCTAssertEqual(currencyData.selectedCode, "JPY")
        XCTAssertEqual(currencyData.selectedSymbol, "¥")
    }

    func testUpdateSelectedCurrency_UnknownCurrency_UsesGenericSymbol() {
        // Act
        currencyData.updateSelectedCurrency("XYZ")

        // Assert
        XCTAssertEqual(currencyData.selectedCode, "XYZ")
        XCTAssertEqual(currencyData.selectedSymbol, "XYZ") // Falls back to currency code
    }

    // MARK: - Exchange Rates Tests

    func testUpdateExchangeRates_ValidRates_SetsRatesAndAvailability() {
        // Arrange
        let rates = ["USD": 1.0, "EUR": 0.85, "GBP": 0.75]

        // Act
        currencyData.updateExchangeRates(rates, available: true)

        // Assert
        XCTAssertEqual(currencyData.currentExchangeRates, rates)
        XCTAssertTrue(currencyData.exchangeRatesAvailable)
    }

    func testUpdateExchangeRates_EmptyRates_SetsUnavailable() {
        // Arrange
        let emptyRates: [String: Double] = [:]

        // Act
        currencyData.updateExchangeRates(emptyRates, available: false)

        // Assert
        XCTAssertEqual(currencyData.currentExchangeRates, emptyRates)
        XCTAssertFalse(currencyData.exchangeRatesAvailable)
    }

    func testUpdateExchangeRates_ValidRatesButMarkedUnavailable() {
        // Arrange
        let rates = ["USD": 1.0, "EUR": 0.85]

        // Act
        currencyData.updateExchangeRates(rates, available: false)

        // Assert
        XCTAssertEqual(currencyData.currentExchangeRates, rates)
        XCTAssertFalse(currencyData.exchangeRatesAvailable) // Should respect the available parameter
    }

    // MARK: - Currency Conversion Tests

    func testConvertAmount_SameCurrency_ReturnsOriginalAmount() {
        // Arrange
        currencyData.updateExchangeRates(["USD": 1.0, "EUR": 0.85], available: true)

        // Act
        let result = currencyData.convertAmount(100.0, from: "USD", to: "USD")

        // Assert
        XCTAssertEqual(result!, 100.0, accuracy: 0.01)
    }

    func testConvertAmount_USDToEUR_ConvertsCorrectly() {
        // Arrange
        currencyData.updateExchangeRates(["USD": 1.0, "EUR": 0.85], available: true)

        // Act
        let result = currencyData.convertAmount(100.0, from: "USD", to: "EUR")

        // Assert
        XCTAssertEqual(result!, 85.0, accuracy: 0.01) // 100 * 0.85
    }

    func testConvertAmount_EURToUSD_ConvertsCorrectly() {
        // Arrange
        currencyData.updateExchangeRates(["USD": 1.0, "EUR": 0.85], available: true)

        // Act
        let result = currencyData.convertAmount(85.0, from: "EUR", to: "USD")

        // Assert
        XCTAssertEqual(result!, 100.0, accuracy: 0.01) // 85 / 0.85
    }

    func testConvertAmount_MissingTargetRate_ReturnsNil() {
        // Arrange
        currencyData.updateExchangeRates(["USD": 1.0], available: true)

        // Act
        let result = currencyData.convertAmount(100.0, from: "USD", to: "EUR")

        // Assert
        XCTAssertNil(result) // EUR rate not available
    }

    func testConvertAmount_MissingSourceRate_ReturnsNil() {
        // Arrange
        currencyData.updateExchangeRates(["USD": 1.0], available: true)

        // Act
        let result = currencyData.convertAmount(100.0, from: "EUR", to: "USD")

        // Assert
        XCTAssertNil(result) // EUR rate not available
    }

    func testConvertAmount_NoRatesAvailable_ReturnsNil() {
        // Arrange
        currencyData.updateExchangeRates([:], available: false)

        // Act
        let result = currencyData.convertAmount(100.0, from: "USD", to: "EUR")

        // Assert
        XCTAssertNil(result)
    }

    // MARK: - Reset Tests

    func testReset_ClearsRatesAndResetsToDefaults() {
        // Arrange - Set some non-default values
        currencyData.updateSelectedCurrency("EUR")
        currencyData.updateExchangeRates(["USD": 1.0, "EUR": 0.85], available: true)

        // Verify non-default state
        XCTAssertEqual(currencyData.selectedCode, "EUR")
        XCTAssertFalse(currencyData.currentExchangeRates.isEmpty)

        // Act
        currencyData.reset()

        // Assert
        XCTAssertEqual(currencyData.selectedCode, "USD")
        XCTAssertEqual(currencyData.selectedSymbol, "$")
        XCTAssertTrue(currencyData.exchangeRatesAvailable)
        XCTAssertTrue(currencyData.currentExchangeRates.isEmpty)
    }

    // MARK: - Integration Tests

    func testCurrencyWorkflow_SelectCurrency_UpdateRates_Convert() {
        // Start with USD
        XCTAssertEqual(currencyData.selectedCode, "USD")

        // Switch to EUR
        currencyData.updateSelectedCurrency("EUR")
        XCTAssertEqual(currencyData.selectedCode, "EUR")
        XCTAssertEqual(currencyData.selectedSymbol, "€")

        // Update exchange rates
        let rates = ["USD": 1.0, "EUR": 0.9, "GBP": 0.8]
        currencyData.updateExchangeRates(rates, available: true)
        XCTAssertEqual(currencyData.currentExchangeRates, rates)
        XCTAssertTrue(currencyData.exchangeRatesAvailable)

        // Convert amounts
        let usdToEur = currencyData.convertAmount(100.0, from: "USD", to: "EUR")
        XCTAssertEqual(usdToEur!, 90.0, accuracy: 0.01)

        let eurToGbp = currencyData.convertAmount(90.0, from: "EUR", to: "GBP")
        XCTAssertEqual(eurToGbp!, 112.5, accuracy: 0.01) // 90 / 0.8
    }

    func testRatesUnavailable_Workflow() {
        // Select non-USD currency
        currencyData.updateSelectedCurrency("EUR")

        // Simulate rates being unavailable
        currencyData.updateExchangeRates([:], available: false)
        XCTAssertFalse(currencyData.exchangeRatesAvailable)
        XCTAssertTrue(currencyData.currentExchangeRates.isEmpty)

        // Conversion should fail
        let result = currencyData.convertAmount(100.0, from: "USD", to: "EUR")
        XCTAssertNil(result)

        // But currency selection should still work
        XCTAssertEqual(currencyData.selectedCode, "EUR")
        XCTAssertEqual(currencyData.selectedSymbol, "€")
    }
}
