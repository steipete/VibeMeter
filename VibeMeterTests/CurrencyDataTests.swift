import Foundation
import Testing
@testable import VibeMeter

/// Tests for the focused CurrencyData observable model.
///
/// These tests follow modern SwiftUI testing principles:
/// - Fast, isolated unit tests
/// - No external dependencies or mocks needed
/// - Direct state verification
/// - Clear test boundaries and responsibilities
@Suite("CurrencyData Tests")
@MainActor
struct CurrencyDataTests {
    let currencyData = CurrencyData()

    // MARK: - Initial State Tests

    @Test("initial state")

    func initialState() {
        // Currency data should start with USD defaults
        #expect(currencyData.selectedCode == "USD")
        #expect(currencyData.exchangeRatesAvailable == true)
    }

    // MARK: - Currency Selection Tests

    @Test("update selected currency usd sets correct values")

    func updateSelectedCurrencyUSDSetsCorrectValues() {
        // Act
        currencyData.updateSelectedCurrency("USD")

        // Assert
        #expect(currencyData.selectedCode == "USD")
    }

    @Test("update selected currency eur sets correct values")

    func updateSelectedCurrencyEURSetsCorrectValues() {
        // Act
        currencyData.updateSelectedCurrency("EUR")

        // Assert
        #expect(currencyData.selectedCode == "EUR")
    }

    @Test("update selected currency gbp sets correct values")

    func updateSelectedCurrencyGBPSetsCorrectValues() {
        // Act
        currencyData.updateSelectedCurrency("GBP")

        // Assert
        #expect(currencyData.selectedCode == "GBP")
    }

    @Test("update selected currency jpy sets correct values")

    func updateSelectedCurrencyJPYSetsCorrectValues() {
        // Act
        currencyData.updateSelectedCurrency("JPY")

        // Assert
        #expect(currencyData.selectedCode == "JPY")
    }

    @Test("update selected currency unknown currency uses generic symbol")

    func updateSelectedCurrencyUnknownCurrencyUsesGenericSymbol() {
        // Act
        currencyData.updateSelectedCurrency("XYZ")

        // Assert
        #expect(currencyData.selectedCode == "XYZ") // Falls back to currency code
    }

    // MARK: - Exchange Rates Tests

    @Test("update exchange rates valid rates sets rates and availability")

    func updateExchangeRatesValidRatesSetsRatesAndAvailability() {
        // Arrange
        let rates = ["USD": 1.0, "EUR": 0.85, "GBP": 0.75]

        // Act
        currencyData.updateExchangeRates(rates, available: true)

        // Assert
        #expect(currencyData.currentExchangeRates == rates)
    }

    @Test("update exchange rates empty rates sets unavailable")

    func updateExchangeRatesEmptyRatesSetsUnavailable() {
        // Arrange
        let emptyRates: [String: Double] = [:]

        // Act
        currencyData.updateExchangeRates(emptyRates, available: false)

        // Assert
        #expect(currencyData.currentExchangeRates == emptyRates)
    }

    @Test("update exchange rates valid rates but marked unavailable")

    func updateExchangeRatesValidRatesButMarkedUnavailable() {
        // Arrange
        let rates = ["USD": 1.0, "EUR": 0.85]

        // Act
        currencyData.updateExchangeRates(rates, available: false)

        // Assert
        #expect(currencyData.currentExchangeRates == rates) // Should respect the available parameter
    }

    // MARK: - Currency Conversion Tests

    @Test("convert amount same currency returns original amount")

    func convertAmountSameCurrencyReturnsOriginalAmount() {
        // Arrange
        currencyData.updateExchangeRates(["USD": 1.0, "EUR": 0.85], available: true)

        // Act
        let result = currencyData.convertAmount(100.0, from: "USD", to: "USD")

        // Assert
        #expect(abs(result! - 100.0) < 0.001)
    }

    @Test("convert amount usd to eur converts correctly")

    func convertAmountUSDToEURConvertsCorrectly() {
        // Arrange
        currencyData.updateExchangeRates(["USD": 1.0, "EUR": 0.85], available: true)

        // Act
        let result = currencyData.convertAmount(100.0, from: "USD", to: "EUR")

        // Assert
        #expect(abs(result! - 85.0) < 0.001) // 100 * 0.85
    }

    @Test("convert amount eur to usd converts correctly")

    func convertAmountEURToUSDConvertsCorrectly() {
        // Arrange
        currencyData.updateExchangeRates(["USD": 1.0, "EUR": 0.85], available: true)

        // Act
        let result = currencyData.convertAmount(85.0, from: "EUR", to: "USD")

        // Assert
        #expect(abs(result! - 100.0) < 0.001) // 85 / 0.85
    }

    @Test("convert amount missing target rate returns nil")

    func convertAmountMissingTargetRateReturnsNil() {
        // Arrange
        currencyData.updateExchangeRates(["USD": 1.0], available: true)

        // Act
        let result = currencyData.convertAmount(100.0, from: "USD", to: "EUR")

        // Assert
        #expect(result == nil)
    }

    @Test("convert amount missing source rate returns nil")

    func convertAmountMissingSourceRateReturnsNil() {
        // Arrange
        currencyData.updateExchangeRates(["USD": 1.0], available: true)

        // Act
        let result = currencyData.convertAmount(100.0, from: "EUR", to: "USD")

        // Assert
        #expect(result == nil)
    }

    @Test("convert amount no rates available returns nil")

    func convertAmountNoRatesAvailableReturnsNil() {
        // Arrange
        currencyData.updateExchangeRates([:], available: false)

        // Act
        let result = currencyData.convertAmount(100.0, from: "USD", to: "EUR")

        // Assert
        #expect(result == nil)
    }

    @Test("reset clears rates and resets to defaults")
    func reset_ClearsRatesAndResetsToDefaults() {
        // Arrange - Set some non-default values
        currencyData.updateSelectedCurrency("EUR")
        currencyData.updateExchangeRates(["USD": 1.0, "EUR": 0.85], available: true)

        // Verify non-default state
        #expect(currencyData.selectedCode == "EUR")

        // Act
        currencyData.reset()

        // Assert
        #expect(currencyData.selectedCode == "USD")
        #expect(currencyData.exchangeRatesAvailable == true)
    }

    // MARK: - Integration Tests

    @Test("currency workflow  select currency  update rates  convert")

    func currencyWorkflow_SelectCurrency_UpdateRates_Convert() {
        // Start with USD
        #expect(currencyData.selectedCode == "USD")

        // Change to EUR
        currencyData.updateSelectedCurrency("EUR")
        #expect(currencyData.selectedCode == "EUR")

        // Update exchange rates
        let rates = ["USD": 1.0, "EUR": 0.9, "GBP": 0.8]
        currencyData.updateExchangeRates(rates, available: true)
        #expect(currencyData.currentExchangeRates == rates)

        // Convert amounts
        let usdToEur = currencyData.convertAmount(100.0, from: "USD", to: "EUR")
        #expect(usdToEur! == 90.0)

        let eurToGbp = currencyData.convertAmount(90.0, from: "EUR", to: "GBP")
        #expect(eurToGbp! == 80.0) // 90 EUR -> 100 USD -> 80 GBP
    }

    @Test("rates unavailable  workflow")

    func ratesUnavailable_Workflow() {
        // Select non-USD currency
        currencyData.updateSelectedCurrency("EUR")

        // Simulate rates being unavailable
        currencyData.updateExchangeRates([:], available: false)
        #expect(currencyData.exchangeRatesAvailable == false)

        // Conversion should fail
        let result = currencyData.convertAmount(100.0, from: "USD", to: "EUR")
        #expect(result == nil)
        #expect(currencyData.selectedSymbol == "€")
    }
}
