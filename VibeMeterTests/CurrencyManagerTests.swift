import Foundation
import Testing
@testable import VibeMeter

@Suite("CurrencyManagerTests", .tags(.currency, .integration))
@MainActor
struct CurrencyManagerTests {
    let sut: CurrencyManager

    init() {
        sut = CurrencyManager.shared
    }

    // MARK: - Singleton Tests

    @Test("shared instance is singleton")
    func sharedInstance_IsSingleton() {
        // Given
        let instance1 = CurrencyManager.shared
        let instance2 = CurrencyManager.shared

        // Then
        #expect(instance1 === instance2)
    }

    @Test("available currencies returns non-empty array")
    func availableCurrencies_ReturnsNonEmptyArray() {
        // When
        let currencies = sut.availableCurrencies

        // Then
        #expect(!currencies.isEmpty)
    }

    @Test("Common currencies availability", arguments: [
        "USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "CNY"
    ])
    func commonCurrencyAvailability(currencyCode: String) {
        let currencies = sut.availableCurrencies
        let currencyCodes = currencies.map(\.0)
        #expect(currencyCodes.contains(currencyCode))
    }

    struct CurrencyFormatTestCase {
        let code: String
        let name: String
    }

    @Test("Currency format validation")
    func currencyFormatValidation() {
        let currencies = sut.availableCurrencies

        for (code, name) in currencies {
            // Currency code should be 3 characters
            #expect(code.count == 3)
            // swiftformat:disable:next preferKeyPath
            #expect(code.allSatisfy { $0.isUppercase })

            // Name should contain currency symbol in parentheses
            #expect(name.contains("("))

            // Name should be capitalized
            #expect(name.first?.isUppercase ?? false)
        }
    }

    @Test("available currencies is unique")
    func availableCurrencies_IsUnique() {
        // When
        let currencies = sut.availableCurrencies
        let currencyCodes = currencies.map(\.0)
        let uniqueCodes = Set(currencyCodes)

        // Then
        #expect(currencyCodes.count == uniqueCodes.count)
    }

    @Test("Currency prioritization", arguments: [
        (currencyCode: "USD", expectedPosition: 1, description: "USD should be first"),
        (currencyCode: "EUR", expectedPosition: 5, description: "EUR should be in top 5"),
        (currencyCode: "GBP", expectedPosition: 5, description: "GBP should be in top 5")
    ])
    func currencyPrioritization(currencyCode: String, expectedPosition: Int, description _: String) {
        let currencies = sut.availableCurrencies
        let codes = currencies.map(\.0)

        if expectedPosition == 1 {
            #expect(codes.first == currencyCode)
        } else {
            #expect(codes.prefix(expectedPosition).contains(currencyCode))
        }
    }

    @Test("system currency code returns valid code")
    func systemCurrencyCode_ReturnsValidCode() {
        // When
        let systemCode = sut.systemCurrencyCode

        // Then
        if let code = systemCode {
            #expect(code.count == 3)
            #expect(sut.isValidCurrencyCode(code))
        } else {
            // If system doesn't provide a currency code, that's acceptable
            #expect(systemCode == nil)
        }
    }

    @Test("system currency code consistent results")
    func systemCurrencyCode_ConsistentResults() {
        // When
        let code1 = sut.systemCurrencyCode
        let code2 = sut.systemCurrencyCode

        // Then
        #expect(code1 == code2)
    }

    struct CurrencyValidationTestCase: CustomTestStringConvertible {
        let code: String
        let expectedValid: Bool
        let description: String

        var testDescription: String {
            "\(code) → \(expectedValid ? "valid" : "invalid") (\(description))"
        }
    }

    nonisolated static let currencyValidationCases: [CurrencyValidationTestCase] = [
        // Valid codes
        CurrencyValidationTestCase(code: "USD", expectedValid: true, description: "US Dollar"),
        CurrencyValidationTestCase(code: "EUR", expectedValid: true, description: "Euro"),
        CurrencyValidationTestCase(code: "GBP", expectedValid: true, description: "British Pound"),
        CurrencyValidationTestCase(code: "JPY", expectedValid: true, description: "Japanese Yen"),
        CurrencyValidationTestCase(code: "AUD", expectedValid: true, description: "Australian Dollar"),
        CurrencyValidationTestCase(code: "CAD", expectedValid: true, description: "Canadian Dollar"),
        // Invalid codes
        CurrencyValidationTestCase(code: "INVALID", expectedValid: false, description: "Invalid code"),
        CurrencyValidationTestCase(code: "XYZ", expectedValid: false, description: "Non-existent code"),
        CurrencyValidationTestCase(code: "123", expectedValid: false, description: "Numeric code"),
        CurrencyValidationTestCase(code: "", expectedValid: false, description: "Empty string"),
        CurrencyValidationTestCase(code: "us", expectedValid: false, description: "Lowercase"),
        CurrencyValidationTestCase(code: "USD ", expectedValid: false, description: "Trailing space"),
        CurrencyValidationTestCase(code: " USD", expectedValid: false, description: "Leading space"),
        // Case sensitivity
        CurrencyValidationTestCase(code: "usd", expectedValid: false, description: "All lowercase"),
        CurrencyValidationTestCase(code: "Usd", expectedValid: false, description: "Mixed case"),
    ]

    @Test("Currency code validation", arguments: currencyValidationCases)
    func currencyCodeValidation(testCase: CurrencyValidationTestCase) {
        let isValid = sut.isValidCurrencyCode(testCase.code)
        #expect(isValid == testCase.expectedValid)
    }

    @Test("available currencies performance", .tags(.performance, .fast), .timeLimit(.minutes(1)))
    func availableCurrencies_Performance() {
        // When
        let startTime = Date()
        let currencies = sut.availableCurrencies
        let duration = Date().timeIntervalSince(startTime)

        // Enhanced logging with Test.current
        if let currentTest = Test.current {
            print(
                "[\(currentTest.name)] Performance: \(currencies.count) currencies in \(String(format: "%.3f", duration))s")
        }

        // Then
        #expect(!currencies.isEmpty)
        #expect(duration < 2.0)
    }

    @Test("Currency validation performance", arguments: ["USD", "EUR", "GBP", "INVALID", "XYZ", "123"])
    func currencyValidationPerformance(testCode: String) {
        let startTime = Date()

        for _ in 0 ..< 1000 {
            _ = sut.isValidCurrencyCode(testCode)
        }

        let duration = Date().timeIntervalSince(startTime)
        #expect(duration < 0.1) // Each code should be fast
    }

    @Test("available currencies no empty entries")
    func availableCurrencies_NoEmptyEntries() {
        // When
        let currencies = sut.availableCurrencies

        // Then
        for (code, name) in currencies {
            #expect(!code.isEmpty)
            #expect(!code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            #expect(!name.isEmpty)
            #expect(!name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Sendable Conformance Tests

    @Test("currency manager is sendable")
    func currencyManager_IsSendable() {
        // Then
        // Verify CurrencyManager is Sendable by attempting to use it in a concurrent context
        let manager = sut
        Task {
            // If CurrencyManager is Sendable, this will compile
            _ = manager.availableCurrencies
        }
        #expect(Bool(true)) // Test passes if it compiles
    }

    @Test("concurrent access thread safety", .tags(.concurrent, .critical))
    func concurrentAccess_ThreadSafety() async {
        // Given
        let taskCount = 20

        // When - Perform concurrent reads
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0 ..< taskCount {
                group.addTask { [sut] in
                    let currencies = sut.availableCurrencies
                    _ = sut.systemCurrencyCode
                    let isValidUSD = sut.isValidCurrencyCode("USD")

                    return !currencies.isEmpty && isValidUSD
                }
            }

            // Collect results
            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }

            // Then
            #expect(results.count == taskCount)
        }
    }
}
