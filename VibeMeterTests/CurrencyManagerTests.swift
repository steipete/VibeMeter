@testable import VibeMeter
import XCTest

final class CurrencyManagerTests: XCTestCase {
    var sut: CurrencyManager!

    override func setUp() async throws {
        try await super.setUp()
        sut = CurrencyManager.shared
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Singleton Tests

    func testSharedInstance_IsSingleton() {
        // Given
        let instance1 = CurrencyManager.shared
        let instance2 = CurrencyManager.shared

        // Then
        XCTAssertTrue(instance1 === instance2, "CurrencyManager.shared should return the same instance")
    }

    // MARK: - Available Currencies Tests

    func testAvailableCurrencies_ReturnsNonEmptyArray() {
        // When
        let currencies = sut?.availableCurrencies ?? []

        // Then
        XCTAssertFalse(currencies.isEmpty, "Should return at least some currencies")
        XCTAssertGreaterThan(currencies.count, 50, "Should have a reasonable number of currencies")
    }

    func testAvailableCurrencies_ContainsCommonCurrencies() {
        // Given
        let expectedCommonCurrencies = ["USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "CNY"]

        // When
        let currencies = sut?.availableCurrencies ?? []
        let currencyCodes = currencies.map(\.0)

        // Then
        for currency in expectedCommonCurrencies {
            XCTAssertTrue(currencyCodes.contains(currency), "Should contain common currency: \(currency)")
        }
    }

    func testAvailableCurrencies_HasCorrectFormat() {
        // When
        let currencies = sut?.availableCurrencies ?? []

        // Then
        for (code, name) in currencies {
            // Currency code should be 3 characters
            XCTAssertEqual(code.count, 3, "Currency code '\(code)' should be 3 characters")
            XCTAssertTrue(code.allSatisfy(\.isUppercase), "Currency code '\(code)' should be uppercase")

            // Name should contain currency symbol in parentheses
            XCTAssertTrue(
                name.contains("(") && name.contains(")"),
                "Currency name '\(name)' should contain symbol in parentheses")

            // Name should be capitalized
            XCTAssertTrue(name.first?.isUppercase ?? false, "Currency name '\(name)' should start with uppercase")
        }
    }

    func testAvailableCurrencies_IsUnique() {
        // When
        let currencies = sut?.availableCurrencies ?? []
        let currencyCodes = currencies.map(\.0)
        let uniqueCodes = Set(currencyCodes)

        // Then
        XCTAssertEqual(currencyCodes.count, uniqueCodes.count, "Currency codes should be unique")
    }

    func testAvailableCurrencies_PrioritizesCommonCurrencies() {
        // When
        let currencies = sut?.availableCurrencies ?? []
        let first10Codes = Array(currencies.prefix(10)).map(\.0)

        // Then
        // USD should be first (most common)
        XCTAssertEqual(first10Codes.first, "USD", "USD should be the first currency")

        // EUR should be in top 5
        XCTAssertTrue(first10Codes.prefix(5).contains("EUR"), "EUR should be in top 5 currencies")

        // GBP should be in top 5
        XCTAssertTrue(first10Codes.prefix(5).contains("GBP"), "GBP should be in top 5 currencies")
    }

    func testAvailableCurrencies_SortsAlphabeticallyAfterCommon() {
        // When
        let currencies = sut?.availableCurrencies ?? []

        // Get currencies that are not in the common list
        let commonCurrencies = [
            "USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF", "CNY", "SEK", "NOK", "DKK", "PLN",
            "CZK", "HUF", "RON", "BGN", "HRK", "RUB", "UAH", "TRY", "INR", "KRW", "SGD", "HKD",
            "TWD", "THB", "MYR", "IDR", "PHP", "VND", "BRL", "MXN", "ARS", "CLP", "COP", "PEN",
            "UYU", "ZAR", "EGP", "MAD", "TND", "KES", "NGN", "GHS", "XOF", "XAF", "ILS", "SAR",
            "AED", "QAR", "KWD", "BHD", "OMR", "JOD", "LBP", "PKR", "BDT", "LKR", "NPR", "AFN",
            "IRR", "IQD", "SYP", "YER", "AZN", "AMD", "GEL", "KZT", "KGS", "TJS", "TMT", "UZS",
            "MNT", "LAK", "KHR", "MMK", "NZD",
        ]

        let uncommonCurrencies = currencies
            .filter { !commonCurrencies.contains($0.0) }
            .map(\.0)

        // Then - Uncommon currencies should be sorted alphabetically
        let sortedUncommon = uncommonCurrencies.sorted()
        XCTAssertEqual(uncommonCurrencies, sortedUncommon, "Uncommon currencies should be sorted alphabetically")
    }

    // MARK: - System Currency Tests

    func testSystemCurrencyCode_ReturnsValidCode() {
        // When
        let systemCode = sut?.systemCurrencyCode ?? "USD"

        // Then
        XCTAssertEqual(systemCode.count, 3, "System currency code should be 3 characters")
        XCTAssertTrue(systemCode.allSatisfy(\.isUppercase), "System currency code should be uppercase")
        XCTAssertTrue(sut?.isValidCurrencyCode(systemCode) ?? false, "System currency code should be valid")
    }

    func testSystemCurrencyCode_ConsistentResults() {
        // When
        let code1 = sut?.systemCurrencyCode ?? "USD"
        let code2 = sut?.systemCurrencyCode ?? "USD"

        // Then
        XCTAssertEqual(code1, code2, "System currency code should be consistent")
    }

    // MARK: - Currency Validation Tests

    func testIsValidCurrencyCode_ValidCodes_ReturnsTrue() {
        // Given
        let validCodes = ["USD", "EUR", "GBP", "JPY", "AUD", "CAD"]

        for code in validCodes {
            // When
            let isValid = sut?.isValidCurrencyCode(code) ?? false

            // Then
            XCTAssertTrue(isValid, "'\(code)' should be a valid currency code")
        }
    }

    func testIsValidCurrencyCode_InvalidCodes_ReturnsFalse() {
        // Given
        let invalidCodes = ["INVALID", "XYZ", "123", "", "us", "USD ", " USD"]

        for code in invalidCodes {
            // When
            let isValid = sut?.isValidCurrencyCode(code) ?? false

            // Then
            XCTAssertFalse(isValid, "'\(code)' should not be a valid currency code")
        }
    }

    func testIsValidCurrencyCode_CaseSensitive() {
        // Given
        let lowercaseCode = "usd"
        let mixedCaseCode = "Usd"

        // When
        let lowercaseValid = sut?.isValidCurrencyCode(lowercaseCode) ?? false
        let mixedCaseValid = sut?.isValidCurrencyCode(mixedCaseCode) ?? false
        let uppercaseValid = sut?.isValidCurrencyCode("USD") ?? false

        // Then
        XCTAssertTrue(uppercaseValid, "Uppercase USD should be valid")
        XCTAssertFalse(lowercaseValid, "Lowercase usd should not be valid")
        XCTAssertFalse(mixedCaseValid, "Mixed case Usd should not be valid")
    }

    // MARK: - Currency Name Formatting Tests

    func testAvailableCurrencies_NameCapitalization() {
        // When
        let currencies = sut?.availableCurrencies ?? []

        // Then
        for (code, name) in currencies {
            // Extract the currency name part (before the symbol in parentheses)
            if let symbolIndex = name.firstIndex(of: "(") {
                let currencyName = String(name[..<symbolIndex]).trimmingCharacters(in: .whitespaces)

                // First character should be uppercase
                XCTAssertTrue(currencyName.first?.isUppercase ?? false,
                              "Currency name for \(code) should start with uppercase: '\(currencyName)'")

                // Should not be all uppercase (unless it's an acronym)
                if currencyName.count > 1, !currencyName.contains(" ") {
                    let hasLowercase = currencyName.dropFirst().contains { $0.isLowercase }
                    // Allow some flexibility for acronyms and special cases
                    if currencyName.count > 3 {
                        XCTAssertTrue(hasLowercase,
                                      "Currency name for \(code) should not be all uppercase: '\(currencyName)'")
                    }
                }
            }
        }
    }

    func testAvailableCurrencies_SymbolExtraction() {
        // When
        let currencies = sut?.availableCurrencies ?? []

        // Then
        for (code, name) in currencies {
            // Should contain parentheses with symbol
            XCTAssertTrue(name.contains("("), "Currency name for \(code) should contain opening parenthesis")
            XCTAssertTrue(name.contains(")"), "Currency name for \(code) should contain closing parenthesis")

            // Extract symbol
            if let startIndex = name.firstIndex(of: "("),
               let endIndex = name.firstIndex(of: ")") {
                let symbol = String(name[name.index(after: startIndex) ..< endIndex])
                XCTAssertFalse(symbol.isEmpty, "Currency symbol for \(code) should not be empty")
                XCTAssertFalse(symbol.contains("("), "Currency symbol for \(code) should not contain parentheses")
                XCTAssertFalse(symbol.contains(")"), "Currency symbol for \(code) should not contain parentheses")
            }
        }
    }

    // MARK: - Locale Integration Tests

    func testAvailableCurrencies_UseSystemLocales() {
        // When
        let _ = sut?.availableCurrencies ?? []
        let availableLocales = Locale.availableIdentifiers

        // Then
        XCTAssertGreaterThan(availableLocales.count, 0, "Should have available locales")

        // Verify that currency extraction is working
        var foundValidCurrencies = 0
        for identifier in availableLocales.prefix(10) { // Test a subset for performance
            let locale = Locale(identifier: identifier)
            if let currencyCode = locale.currency?.identifier,
               currencyCode.count == 3 {
                foundValidCurrencies += 1
            }
        }

        XCTAssertGreaterThan(foundValidCurrencies, 0, "Should find valid currencies from locales")
    }

    // MARK: - Performance Tests

    func testAvailableCurrencies_Performance() {
        // When
        let startTime = Date()
        let currencies = sut?.availableCurrencies ?? []
        let duration = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertLessThan(duration, 2.0, "Currency enumeration should complete within 2 seconds")
        XCTAssertGreaterThan(currencies.count, 50, "Should return a reasonable number of currencies")
    }

    func testIsValidCurrencyCode_Performance() {
        // Given
        let testCodes = ["USD", "EUR", "GBP", "INVALID", "XYZ", "123"]

        // When
        let startTime = Date()
        for _ in 0 ..< 100 {
            for code in testCodes {
                _ = sut?.isValidCurrencyCode(code) ?? false
            }
        }
        let duration = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertLessThan(duration, 1.0, "Currency validation should be fast")
    }

    // MARK: - Stability Tests

    func testAvailableCurrencies_ConsistentResults() {
        // When
        let currencies1 = sut?.availableCurrencies ?? []
        let currencies2 = sut?.availableCurrencies ?? []

        // Then
        XCTAssertEqual(currencies1.count, currencies2.count, "Currency count should be consistent")

        for (index, currency1) in currencies1.enumerated() {
            let currency2 = currencies2[index]
            XCTAssertEqual(currency1.0, currency2.0, "Currency code should be consistent at index \(index)")
            XCTAssertEqual(currency1.1, currency2.1, "Currency name should be consistent at index \(index)")
        }
    }

    // MARK: - Edge Cases

    func testIsValidCurrencyCode_EmptyString() {
        // When
        let isValid = sut?.isValidCurrencyCode("") ?? false

        // Then
        XCTAssertFalse(isValid, "Empty string should not be valid currency code")
    }

    func testIsValidCurrencyCode_WhitespaceOnly() {
        // Given
        let whitespaceCodes = [" ", "\t", "\n", "   "]

        for code in whitespaceCodes {
            // When
            let isValid = sut?.isValidCurrencyCode(code) ?? false

            // Then
            XCTAssertFalse(isValid, "Whitespace-only string '\(code)' should not be valid")
        }
    }

    func testAvailableCurrencies_NoEmptyEntries() {
        // When
        let currencies = sut?.availableCurrencies ?? []

        // Then
        for (code, name) in currencies {
            XCTAssertFalse(code.isEmpty, "Currency code should not be empty")
            XCTAssertFalse(name.isEmpty, "Currency name should not be empty")
            XCTAssertFalse(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           "Currency code should not be whitespace only")
            XCTAssertFalse(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           "Currency name should not be whitespace only")
        }
    }

    // MARK: - Sendable Conformance Tests

    func testCurrencyManager_IsSendable() {
        // Then
        XCTAssertTrue(type(of: sut) is any Sendable.Type, "CurrencyManager should be Sendable")
    }

    func testConcurrentAccess_ThreadSafety() async {
        // Given
        let taskCount = 20

        // When - Perform concurrent reads
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0 ..< taskCount {
                group.addTask { [sut] in
                    let currencies = sut?.availableCurrencies ?? []
                    let _ = sut?.systemCurrencyCode ?? "USD"
                    let isValidUSD = sut?.isValidCurrencyCode("USD") ?? false

                    return !currencies.isEmpty && isValidUSD
                }
            }

            // Collect results
            var results: [Bool] = []
            for await result in group {
                results.append(result)
            }

            // Then
            XCTAssertEqual(results.count, taskCount, "All tasks should complete")
            XCTAssertTrue(results.allSatisfy(\.self), "All concurrent reads should succeed")
        }
    }
}
