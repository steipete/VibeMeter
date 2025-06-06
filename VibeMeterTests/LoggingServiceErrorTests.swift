import os.log
import Testing
@testable import VibeMeter

@Suite("LoggingServiceErrorTests")
struct LoggingServiceErrorTests {
    // MARK: - Error Handling Tests

    @Test("log  with localized error  handles error description")

    func log_WithLocalizedError_HandlesErrorDescription() {
        // Given
        struct TestLocalizedError: LocalizedError {
            let errorDescription: String? = "Localized error description"
            let failureReason: String? = "Test failure reason"
        }
        let localizedError = TestLocalizedError()

        // When/Then - Should handle LocalizedError without crashing
        LoggingService.log("Test with localized error", error: localizedError)

        // Test passes if no exception is thrown
    }

    @Test("log  with ns error  handles description")

    func log_WithNSError_HandlesDescription() {
        // Given
        let nsError = NSError(domain: "TestDomain", code: 100, userInfo: [
            NSLocalizedDescriptionKey: "NSError description",
            NSLocalizedFailureReasonErrorKey: "Failure reason",
        ])

        // When/Then - Should handle NSError without crashing
        LoggingService.log("Test with NSError", error: nsError)

        // Test passes if no exception is thrown
    }

    @Test("log  with generic error  handles description")

    func log_WithGenericError_HandlesDescription() {
        // Given
        struct GenericError: Error {
            let description = "Generic error"
        }
        let genericError = GenericError()

        // When/Then - Should handle generic Error without crashing
        LoggingService.log("Test with generic error", error: genericError)

        // Test passes if no exception is thrown
    }

    @Test("log  with nil error  handles gracefully")

    func log_WithNilError_HandlesGracefully() {
        // When/Then - Should handle nil error gracefully
        LoggingService.log("Test with nil error", error: nil)

        // Test passes if no exception is thrown
    }

    // MARK: - API Category Enhanced Error Tests

    @Test("log api category  adds error details")

    func log_APICategory_AddsErrorDetails() {
        // Given
        let apiError = NSError(domain: "APIErrorDomain", code: 500, userInfo: [
            NSLocalizedDescriptionKey: "Server error",
            "additionalInfo": "Server overloaded",
        ])

        // When/Then - Should handle API errors with enhanced details
        LoggingService.log("API request failed", category: .api, error: apiError)

        // Test passes if no exception is thrown
    }

    @Test("log  exchange rate category  adds error details")

    func log_ExchangeRateCategory_AddsErrorDetails() {
        // Given
        let exchangeRateError = NSError(domain: "ExchangeRateDomain", code: 404, userInfo: [
            NSLocalizedDescriptionKey: "Currency not found",
            "currencyCode": "XYZ",
        ])

        // When/Then - Should handle exchange rate errors with enhanced details
        LoggingService.log("Exchange rate fetch failed", category: .exchangeRate, error: exchangeRateError)

        // Test passes if no exception is thrown
    }

    @Test("log  non api category  does not add extra details")

    func log_NonAPICategory_DoesNotAddExtraDetails() {
        // Given
        let uiError = NSError(domain: "UIDomain", code: 200, userInfo: [
            NSLocalizedDescriptionKey: "UI error",
            "viewController": "TestViewController",
        ])

        // When/Then - Should handle non-API errors normally (without extra details)
        LoggingService.log("UI error occurred", category: .ui, error: uiError)

        // Test passes if no exception is thrown
    }

    // MARK: - Error Detail Enhancement Tests

    @Test("error detail enhancement  localized error")

    func errorDetailEnhancement_LocalizedError() {
        // Given
        struct DetailedLocalizedError: LocalizedError {
            let errorDescription: String? = "Main error description"
            let failureReason: String? = "Detailed failure reason"
            let recoverySuggestion: String? = "Try again later"
        }
        let detailedError = DetailedLocalizedError()

        // When/Then - Should extract and use errorDescription
        LoggingService.error("Detailed localized error test", error: detailedError)

        // Test passes if no exception is thrown
    }

    @Test("error detail enhancement  non localized error")

    func errorDetailEnhancement_NonLocalizedError() {
        // Given
        struct SimpleError: Error {
            // No custom description
        }
        let simpleError = SimpleError()

        // When/Then - Should fall back to localizedDescription
        LoggingService.error("Simple error test", error: simpleError)

        // Test passes if no exception is thrown
    }
}
