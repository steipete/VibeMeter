@testable import VibeMeter
import Testing

@Suite("CurrencyManagerTests")
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

    @Test("available currencies contains common currencies")
    func availableCurrencies_ContainsCommonCurrencies() {
        // Given
        let expectedCommonCurrencies = ["USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "CNY"]

        // When
        let currencies = sut.availableCurrencies
        let currencyCodes = currencies.map(\.0)

        // Then
        for currency in expectedCommonCurrencies {
            #expect(currencyCodes.contains(currency))
        }
    }

    @Test("available currencies has correct format")
    func availableCurrencies_HasCorrectFormat() {
        // When
        let currencies = sut.availableCurrencies

        // Then
        for (code, name) in currencies {
            // Currency code should be 3 characters
            #expect(code.count == 3)
            #expect(code.allSatisfy(\.isUppercase))

            // Name should contain currency symbol in parentheses
            #expect(name.contains("("), "Currency name '\(name)' should contain symbol in parentheses")

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

    @Test("available currencies prioritizes common currencies")
    func availableCurrencies_PrioritizesCommonCurrencies() {
        // When
        let currencies = sut.availableCurrencies
        let first10Codes = Array(currencies.prefix(10)).map(\.0)

        // Then
        // USD should be first (most common)
        #expect(first10Codes.first == "USD")
        
        // EUR should be in top 5
        #expect(first10Codes.prefix(5).contains("EUR"), "EUR should be in top 5 currencies")

        // GBP should be in top 5
        #expect(first10Codes.prefix(5).contains("GBP"), "GBP should be in top 5 currencies")
    }

    @Test("system currency code returns valid code")
    func systemCurrencyCode_ReturnsValidCode() {
        // When
        let systemCode = sut.systemCurrencyCode

        // Then
        #expect(systemCode.count == 3)
        #expect(sut.isValidCurrencyCode(systemCode))
    }

    @Test("system currency code consistent results")
    func systemCurrencyCode_ConsistentResults() {
        // When
        let code1 = sut.systemCurrencyCode
        let code2 = sut.systemCurrencyCode

        // Then
        #expect(code1 == code2)
    }

    @Test("is valid currency code valid codes returns true")
    func isValidCurrencyCode_ValidCodes_ReturnsTrue() {
        // Given
        let validCodes = ["USD", "EUR", "GBP", "JPY", "AUD", "CAD"]

        for code in validCodes {
            // When
            let isValid = sut.isValidCurrencyCode(code)

            // Then
            #expect(isValid)
        }
    }

    @Test("is valid currency code invalid codes returns false")
    func isValidCurrencyCode_InvalidCodes_ReturnsFalse() {
        // Given
        let invalidCodes = ["INVALID", "XYZ", "123", "", "us", "USD ", " USD"]

        for code in invalidCodes {
            // When
            let isValid = sut.isValidCurrencyCode(code)

            // Then
            #expect(!isValid)
        }
    }

    @Test("is valid currency code case sensitive")
    func isValidCurrencyCode_CaseSensitive() {
        // Given
        let lowercaseCode = "usd"
        let mixedCaseCode = "Usd"

        // When
        let lowercaseValid = sut.isValidCurrencyCode(lowercaseCode)
        let mixedCaseValid = sut.isValidCurrencyCode(mixedCaseCode)
        let uppercaseValid = sut.isValidCurrencyCode("USD")

        // Then
        #expect(uppercaseValid)
        #expect(!lowercaseValid)
        #expect(!mixedCaseValid)
    }

    @Test("available currencies performance")
    func availableCurrencies_Performance() {
        // When
        let startTime = Date()
        let currencies = sut.availableCurrencies
        let duration = Date().timeIntervalSince(startTime)

        // Then
        #expect(!currencies.isEmpty)
        #expect(duration < 2.0)
    }

    @Test("is valid currency code performance")
    func isValidCurrencyCode_Performance() {
        // Given
        let testCodes = ["USD", "EUR", "GBP", "INVALID", "XYZ", "123"]

        // When
        let startTime = Date()
        for _ in 0..<100 {
            for code in testCodes {
                _ = sut.isValidCurrencyCode(code)
            }
        }
        let duration = Date().timeIntervalSince(startTime)

        // Then
        #expect(duration < 1.0)
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
        #expect(sut != nil)
    }

    @Test("concurrent access thread safety")
    func concurrentAccess_ThreadSafety() async {
        // Given
        let taskCount = 20

        // When - Perform concurrent reads
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<taskCount {
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