@testable import VibeMeter
import XCTest

@MainActor
final class CurrencyConversionBasicTests: XCTestCase {
    // MARK: - Currency Conversion Tests

    func testConvert_WithValidRate_PerformsCorrectConversion() {
        // Given
        let amount = 100.0
        let rate = 0.85

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        XCTAssertEqual(result, 85.0, accuracy: 0.001, "Should convert 100 * 0.85 = 85")
    }

    func testConvert_WithNilRate_ReturnsOriginalAmount() {
        // Given
        let amount = 100.0
        let rate: Double? = nil

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        XCTAssertEqual(result, amount, "Should return original amount when rate is nil")
    }

    func testConvert_WithZeroRate_ReturnsOriginalAmount() {
        // Given
        let amount = 100.0
        let rate = 0.0

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        XCTAssertEqual(result, amount, "Should return original amount when rate is zero")
    }

    func testConvert_WithNegativeRate_ReturnsOriginalAmount() {
        // Given
        let amount = 100.0
        let rate = -0.5

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        XCTAssertEqual(result, amount, "Should return original amount when rate is negative")
    }

    func testConvert_WithVerySmallRate_PerformsConversion() {
        // Given
        let amount = 100.0
        let rate = 0.001

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        XCTAssertEqual(result, 0.1, accuracy: 0.001, "Should handle very small rates")
    }

    func testConvert_WithVeryLargeRate_PerformsConversion() {
        // Given
        let amount = 1.0
        let rate = 1000.0

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        XCTAssertEqual(result, 1000.0, accuracy: 0.001, "Should handle very large rates")
    }

    func testConvert_WithZeroAmount_ReturnsZero() {
        // Given
        let amount = 0.0
        let rate = 1.5

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        XCTAssertEqual(result, 0.0, "Should return zero when amount is zero")
    }

    func testConvert_WithNegativeAmount_HandlesCorrectly() {
        // Given
        let amount = -50.0
        let rate = 2.0

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        XCTAssertEqual(result, -100.0, accuracy: 0.001, "Should handle negative amounts correctly")
    }

    // MARK: - Monthly Limit Calculation Tests

    func testCalculateMonthlyLimit_BasicCalculation() {
        // Given
        let yearlyLimit = 1200.0

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)

        // Then
        XCTAssertEqual(result, 100.0, accuracy: 0.001, "Should calculate monthly limit as yearly/12")
    }

    func testCalculateMonthlyLimit_ZeroYearlyLimit() {
        // Given
        let yearlyLimit = 0.0

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)

        // Then
        XCTAssertEqual(result, 0.0, "Should handle zero yearly limit")
    }

    func testCalculateMonthlyLimit_NegativeYearlyLimit() {
        // Given
        let yearlyLimit = -1200.0

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)

        // Then
        XCTAssertEqual(result, -100.0, accuracy: 0.001, "Should handle negative yearly limit")
    }

    func testCalculateMonthlyLimit_FractionalYearlyLimit() {
        // Given
        let yearlyLimit = 100.5

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)

        // Then
        XCTAssertEqual(result, 8.375, accuracy: 0.001, "Should handle fractional yearly limits")
    }

    func testCalculateMonthlyLimit_VeryLargeYearlyLimit() {
        // Given
        let yearlyLimit = 1_000_000.0

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)

        // Then
        XCTAssertEqual(result, 83333.333333333333, accuracy: 0.001, "Should handle very large yearly limits")
    }

    func testCalculateMonthlyLimit_VerySmallYearlyLimit() {
        // Given
        let yearlyLimit = 0.12

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)

        // Then
        XCTAssertEqual(result, 0.01, accuracy: 0.001, "Should handle very small yearly limits")
    }

    func testCalculateMonthlyLimit_WithDifferentCalendar() {
        // Given
        let yearlyLimit = 1200.0
        let islamicCalendar = Calendar(identifier: .islamicCivil)

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit, using: islamicCalendar)

        // Then
        // The calculation should still be /12 regardless of calendar
        XCTAssertEqual(result, 100.0, accuracy: 0.001, "Should use same calculation regardless of calendar type")
    }
}