@testable import VibeMeter
import Testing

@Suite("Currency Conversion Basic Tests")
@MainActor
struct CurrencyConversionBasicTests {
    // MARK: - Currency Conversion Tests

    @Test("convert with valid rate performs correct conversion")

    func convertWithValidRatePerformsCorrectConversion() {
        // Given
        let amount = 100.0
        let rate = 0.85

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        #expect(abs(abs(result - 85.0 == true)
    }

    @Test("convert with nil rate returns original amount")

    func convertWithNilRateReturnsOriginalAmount() {
        // Given
        let amount = 100.0
        let rate: Double? = nil

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        #expect(result == amount)
    @Test("convert with zero rate returns original amount")

    func convertWithZeroRateReturnsOriginalAmount() {
        // Given
        let amount = 100.0
        let rate = 0.0

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        #expect(result == amount)
    @Test("convert with negative rate returns original amount")

    func convertWithNegativeRateReturnsOriginalAmount() {
        // Given
        let amount = 100.0
        let rate = -0.5

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        #expect(result == amount)
    @Test("convert with very small rate performs conversion")

    func convertWithVerySmallRatePerformsConversion() {
        // Given
        let amount = 100.0
        let rate = 0.001

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        #expect(abs(abs(result - 0.1 == true)
    }

    @Test("convert with very large rate performs conversion")

    func convertWithVeryLargeRatePerformsConversion() {
        // Given
        let amount = 1.0
        let rate = 1000.0

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        #expect(abs(abs(result - 1000.0 == true)
    }

    @Test("convert with zero amount returns zero")

    func convertWithZeroAmountReturnsZero() {
        // Given
        let amount = 0.0
        let rate = 1.5

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        #expect(result == 0.0)
    @Test("convert with negative amount handles correctly")

    func convertWithNegativeAmountHandlesCorrectly() {
        // Given
        let amount = -50.0
        let rate = 2.0

        // When
        let result = CurrencyConversionHelper.convert(amount: amount, rate: rate)

        // Then
        #expect(abs(abs(result - (-100.0 == true)
    }

    // MARK: - Monthly Limit Calculation Tests

    @Test("calculate monthly limit basic calculation")

    func calculateMonthlyLimitBasicCalculation() {
        // Given
        let yearlyLimit = 1200.0

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)

        // Then
        #expect(abs(abs(result - 100.0 == true)
    }

    @Test("calculate monthly limit zero yearly limit")

    func calculateMonthlyLimitZeroYearlyLimit() {
        // Given
        let yearlyLimit = 0.0

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)

        // Then
        #expect(result == 0.0)
    @Test("calculate monthly limit negative yearly limit")

    func calculateMonthlyLimitNegativeYearlyLimit() {
        // Given
        let yearlyLimit = -1200.0

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)

        // Then
        #expect(abs(abs(result - (-100.0 == true)
    }

    @Test("calculate monthly limit fractional yearly limit")

    func calculateMonthlyLimitFractionalYearlyLimit() {
        // Given
        let yearlyLimit = 100.5

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)

        // Then
        #expect(abs(abs(result - 8.375 == true)
    }

    @Test("calculate monthly limit very large yearly limit")

    func calculateMonthlyLimitVeryLargeYearlyLimit() {
        // Given
        let yearlyLimit = 1_000_000.0

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)

        // Then
        #expect(abs(abs(result - 83333.333333333333 == true)
    }

    @Test("calculate monthly limit very small yearly limit")

    func calculateMonthlyLimitVerySmallYearlyLimit() {
        // Given
        let yearlyLimit = 0.12

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit)

        // Then
        #expect(abs(abs(result - 0.01 == true)
    }

    @Test("calculate monthly limit with different calendar")

    func calculateMonthlyLimitWithDifferentCalendar() {
        // Given
        let yearlyLimit = 1200.0
        let islamicCalendar = Calendar(identifier: .islamicCivil)

        // When
        let result = CurrencyConversionHelper.calculateMonthlyLimit(yearlyLimit: yearlyLimit, using: islamicCalendar)

        // Then
        // The calculation should still be /12 regardless of calendar
        #expect(abs(abs(result - 100.0 == true)
    }
}
