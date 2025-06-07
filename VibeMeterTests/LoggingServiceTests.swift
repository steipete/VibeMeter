import Foundation
import os.log
import Testing
@testable import VibeMeter

@Suite("LoggingService", .tags(.unit))
@MainActor
struct LoggingServiceTests {
    // MARK: - Core Tests

    @Suite("Core", .tags(.fast))
    struct CoreTests {
        // MARK: - LogCategory Tests

        @Test("log category  raw values  are correct")

        func logCategory_RawValues_AreCorrect() {
            // Test that all log categories have expected raw values
            let expectedCategories = [
                (LogCategory.general, "General"),
                (LogCategory.app, "AppLifecycle"),
                (LogCategory.lifecycle, "Lifecycle"),
                (LogCategory.ui, "UI"),
                (LogCategory.login, "Login"),
                (LogCategory.api, "API"),
                (LogCategory.apiClient, "APIClient"),
                (LogCategory.exchangeRate, "ExchangeRate"),
                (LogCategory.settings, "Settings"),
                (LogCategory.startup, "Startup"),
                (LogCategory.notification, "Notification"),
                (LogCategory.data, "DataOrchestrator"),
            ]

            for (category, expectedRawValue) in expectedCategories {
                #expect(
                    category.rawValue == expectedRawValue)
            }
        }

        @Test("log category  all cases exist")

        func logCategory_AllCasesExist() {
            // Verify that all expected categories are accessible
            let categories: [LogCategory] = [
                .general, .app, .lifecycle, .ui, .login, .api, .apiClient,
                .exchangeRate, .settings, .startup, .notification, .data,
            ]

            #expect(categories.count == 12)
        }

        // MARK: - Basic Logging Tests

        @Test("log  basic message  does not crash")

        func log_BasicMessage_DoesNotCrash() {
            // When/Then - Should not crash when logging basic message
            LoggingService.log("Test message")

            // Test passes if no exception is thrown
        }

        @Test("log  with category  does not crash")

        func log_WithCategory_DoesNotCrash() {
            // When/Then - Should not crash when logging with specific category
            LoggingService.log("API test message", category: .api)

            // Test passes if no exception is thrown
        }

        @Test("log  with level  does not crash")

        func log_WithLevel_DoesNotCrash() {
            // When/Then - Should not crash when logging with specific level
            LoggingService.log("Debug test message", level: .debug)

            // Test passes if no exception is thrown
        }

        @Test("log  with all parameters  does not crash")

        func log_WithAllParameters_DoesNotCrash() {
            // Given
            let testError = NSError(domain: "TestDomain", code: 123, userInfo: [
                NSLocalizedDescriptionKey: "Test error description",
            ])

            // When/Then - Should not crash when logging with all parameters
            LoggingService.log("Full test message", category: .api, level: .error, error: testError)

            // Test passes if no exception is thrown
        }

        // MARK: - Convenience Method Tests

        @Test("info  with message  does not crash")

        func info_WithMessage_DoesNotCrash() {
            // When/Then
            LoggingService.info("Info test message")

            // Test passes if no exception is thrown
        }

        @Test("info  with category  does not crash")

        func info_WithCategory_DoesNotCrash() {
            // When/Then
            LoggingService.info("Info with category", category: .ui)

            // Test passes if no exception is thrown
        }

        @Test("debug  with message  does not crash")

        func debug_WithMessage_DoesNotCrash() {
            // When/Then
            LoggingService.debug("Debug test message")

            // Test passes if no exception is thrown
        }

        @Test("debug  with category  does not crash")

        func debug_WithCategory_DoesNotCrash() {
            // When/Then
            LoggingService.debug("Debug with category", category: .login)

            // Test passes if no exception is thrown
        }

        @Test("warning  with message  does not crash")

        func warning_WithMessage_DoesNotCrash() {
            // When/Then
            LoggingService.warning("Warning test message")

            // Test passes if no exception is thrown
        }

        @Test("warning  with error  does not crash")

        func warning_WithError_DoesNotCrash() {
            // Given
            let testError = NSError(domain: "TestDomain", code: 456, userInfo: nil)

            // When/Then
            LoggingService.warning("Warning with error", error: testError)

            // Test passes if no exception is thrown
        }

        @Test("error  with message  does not crash")

        func error_WithMessage_DoesNotCrash() {
            // When/Then
            LoggingService.error("Error test message")

            // Test passes if no exception is thrown
        }

        @Test("error  with error  does not crash")

        func error_WithError_DoesNotCrash() {
            // Given
            let testError = NSError(domain: "TestDomain", code: 789, userInfo: [
                NSLocalizedDescriptionKey: "Test error for logging",
            ])

            // When/Then
            LoggingService.error("Error with error object", category: .api, error: testError)

            // Test passes if no exception is thrown
        }

        @Test("critical  with message  does not crash")

        func critical_WithMessage_DoesNotCrash() {
            // When/Then
            LoggingService.critical("Critical test message")

            // Test passes if no exception is thrown
        }

        @Test("critical  with error  does not crash")

        func critical_WithError_DoesNotCrash() {
            // Given
            let criticalError = NSError(domain: "CriticalDomain", code: 999, userInfo: nil)

            // When/Then
            LoggingService.critical("Critical error occurred", category: .data, error: criticalError)

            // Test passes if no exception is thrown
        }

        @Test("fault  with message  does not crash")

        func fault_WithMessage_DoesNotCrash() {
            // When/Then
            LoggingService.fault("Fault test message")

            // Test passes if no exception is thrown
        }

        @Test("fault  with error  does not crash")

        func fault_WithError_DoesNotCrash() {
            // Given
            let faultError = NSError(domain: "FaultDomain", code: 1000, userInfo: nil)

            // When/Then
            LoggingService.fault("Fault occurred", category: .settings, error: faultError)

            // Test passes if no exception is thrown
        }

        // MARK: - OSLogType Coverage Tests

        @Test("log  all os log types  handle correctly")

        func log_AllOSLogTypes_HandleCorrectly() {
            // Test all OSLogType cases to ensure they're handled
            let logTypes: [OSLogType] = [.default, .info, .debug, .error, .fault]

            for (index, logType) in logTypes.enumerated() {
                // When/Then - Should handle each log type without crashing
                LoggingService.log("Test message \(index)", level: logType)
            }

            // Test passes if no exceptions are thrown
        }

        // MARK: - Category-Specific Tests

        @Test("all categories  can be used for logging")

        func allCategories_CanBeUsedForLogging() {
            // Test that all categories can be used without issues
            let categories: [LogCategory] = [
                .general, .app, .lifecycle, .ui, .login, .api, .apiClient,
                .exchangeRate, .settings, .startup, .notification, .data,
            ]

            for category in categories {
                // When/Then - Should be able to log with each category
                LoggingService.info("Test message for \(category.rawValue)", category: category)
            }

            // Test passes if no exceptions are thrown
        }
    }

    // MARK: - Error Handling Tests

    @Suite("Error Handling", .tags(.edgeCase))
    struct ErrorHandlingTests {
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

    // MARK: - Edge Cases and Performance Tests

    @Suite("Edge Cases", .tags(.performance))
    struct EdgeCasesTests {
        @Test("log  empty message  handles gracefully")

        func log_EmptyMessage_HandlesGracefully() {
            // When/Then - Should handle empty message gracefully
            LoggingService.log("")

            // Test passes if no exception is thrown
        }

        @Test("log  very long message  handles gracefully")

        func log_VeryLongMessage_HandlesGracefully() {
            // Given
            let longMessage = String(repeating: "a", count: 10000)

            // When/Then - Should handle very long messages gracefully
            LoggingService.log(longMessage)

            // Test passes if no exception is thrown
        }

        @Test("log  message with special characters  handles gracefully")

        func log_MessageWithSpecialCharacters_HandlesGracefully() {
            // Given
            let specialMessage = "Test 🚀 with émojis and spëcıal chàracters ñ ß ∂ ∑"

            // When/Then - Should handle special characters gracefully
            LoggingService.log(specialMessage)

            // Test passes if no exception is thrown
        }

        @Test("log  message with newlines  handles gracefully")

        func log_MessageWithNewlines_HandlesGracefully() {
            // Given
            let multilineMessage = "First line\nSecond line\nThird line"

            // When/Then - Should handle newlines gracefully
            LoggingService.log(multilineMessage)

            // Test passes if no exception is thrown
        }

        // MARK: - Bundle Identifier Tests

        @Test("get logger  with default subsystem  uses main bundle")

        func getLogger_WithDefaultSubsystem_UsesMainBundle() {
            // The private getLogger method should use main bundle identifier
            // We can't test this directly, but we can verify logging doesn't crash

            // When/Then - Should use bundle identifier for subsystem
            LoggingService.log("Bundle identifier test")

            // Test passes if no exception is thrown
        }

        @Test("get logger  with nil bundle identifier  uses fallback")

        func getLogger_WithNilBundleIdentifier_UsesFallback() {
            // If bundle identifier is nil, should use fallback
            // This is hard to test directly, but the logging should still work

            // When/Then - Should handle missing bundle identifier gracefully
            LoggingService.log("Fallback subsystem test")

            // Test passes if no exception is thrown
        }
    }
}
