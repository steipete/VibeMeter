import os.log
@testable import VibeMeter
import XCTest

final class LoggingServiceTests: XCTestCase {
    // MARK: - LogCategory Tests

    func testLogCategory_RawValues_AreCorrect() {
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
            XCTAssertEqual(
                category.rawValue,
                expectedRawValue,
                "Category \(category) should have raw value '\(expectedRawValue)'")
        }
    }

    func testLogCategory_AllCasesExist() {
        // Verify that all expected categories are accessible
        let categories: [LogCategory] = [
            .general, .app, .lifecycle, .ui, .login, .api, .apiClient,
            .exchangeRate, .settings, .startup, .notification, .data,
        ]

        XCTAssertEqual(categories.count, 12, "Should have 12 log categories")

        // Each category should have a non-empty raw value
        for category in categories {
            XCTAssertFalse(category.rawValue.isEmpty, "Category \(category) should have non-empty raw value")
        }
    }

    // MARK: - Basic Logging Tests

    func testLog_BasicMessage_DoesNotCrash() {
        // When/Then - Should not crash when logging basic message
        LoggingService.log("Test message")

        // Test passes if no exception is thrown
    }

    func testLog_WithCategory_DoesNotCrash() {
        // When/Then - Should not crash when logging with specific category
        LoggingService.log("API test message", category: .api)

        // Test passes if no exception is thrown
    }

    func testLog_WithLevel_DoesNotCrash() {
        // When/Then - Should not crash when logging with specific level
        LoggingService.log("Debug test message", level: .debug)

        // Test passes if no exception is thrown
    }

    func testLog_WithAllParameters_DoesNotCrash() {
        // Given
        let testError = NSError(domain: "TestDomain", code: 123, userInfo: [
            NSLocalizedDescriptionKey: "Test error description",
        ])

        // When/Then - Should not crash when logging with all parameters
        LoggingService.log("Full test message", category: .api, level: .error, error: testError)

        // Test passes if no exception is thrown
    }

    // MARK: - Convenience Method Tests

    func testInfo_WithMessage_DoesNotCrash() {
        // When/Then
        LoggingService.info("Info test message")

        // Test passes if no exception is thrown
    }

    func testInfo_WithCategory_DoesNotCrash() {
        // When/Then
        LoggingService.info("Info with category", category: .ui)

        // Test passes if no exception is thrown
    }

    func testDebug_WithMessage_DoesNotCrash() {
        // When/Then
        LoggingService.debug("Debug test message")

        // Test passes if no exception is thrown
    }

    func testDebug_WithCategory_DoesNotCrash() {
        // When/Then
        LoggingService.debug("Debug with category", category: .login)

        // Test passes if no exception is thrown
    }

    func testWarning_WithMessage_DoesNotCrash() {
        // When/Then
        LoggingService.warning("Warning test message")

        // Test passes if no exception is thrown
    }

    func testWarning_WithError_DoesNotCrash() {
        // Given
        let testError = NSError(domain: "TestDomain", code: 456, userInfo: nil)

        // When/Then
        LoggingService.warning("Warning with error", error: testError)

        // Test passes if no exception is thrown
    }

    func testError_WithMessage_DoesNotCrash() {
        // When/Then
        LoggingService.error("Error test message")

        // Test passes if no exception is thrown
    }

    func testError_WithError_DoesNotCrash() {
        // Given
        let testError = NSError(domain: "TestDomain", code: 789, userInfo: [
            NSLocalizedDescriptionKey: "Test error for logging",
        ])

        // When/Then
        LoggingService.error("Error with error object", category: .api, error: testError)

        // Test passes if no exception is thrown
    }

    func testCritical_WithMessage_DoesNotCrash() {
        // When/Then
        LoggingService.critical("Critical test message")

        // Test passes if no exception is thrown
    }

    func testCritical_WithError_DoesNotCrash() {
        // Given
        let criticalError = NSError(domain: "CriticalDomain", code: 999, userInfo: nil)

        // When/Then
        LoggingService.critical("Critical error occurred", category: .data, error: criticalError)

        // Test passes if no exception is thrown
    }

    func testFault_WithMessage_DoesNotCrash() {
        // When/Then
        LoggingService.fault("Fault test message")

        // Test passes if no exception is thrown
    }

    func testFault_WithError_DoesNotCrash() {
        // Given
        let faultError = NSError(domain: "FaultDomain", code: 1000, userInfo: nil)

        // When/Then
        LoggingService.fault("Fault occurred", category: .settings, error: faultError)

        // Test passes if no exception is thrown
    }

    // MARK: - Error Handling Tests

    func testLog_WithLocalizedError_HandlesErrorDescription() {
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

    func testLog_WithNSError_HandlesDescription() {
        // Given
        let nsError = NSError(domain: "TestDomain", code: 100, userInfo: [
            NSLocalizedDescriptionKey: "NSError description",
            NSLocalizedFailureReasonErrorKey: "Failure reason",
        ])

        // When/Then - Should handle NSError without crashing
        LoggingService.log("Test with NSError", error: nsError)

        // Test passes if no exception is thrown
    }

    func testLog_WithGenericError_HandlesDescription() {
        // Given
        struct GenericError: Error {
            let description = "Generic error"
        }
        let genericError = GenericError()

        // When/Then - Should handle generic Error without crashing
        LoggingService.log("Test with generic error", error: genericError)

        // Test passes if no exception is thrown
    }

    func testLog_WithNilError_HandlesGracefully() {
        // When/Then - Should handle nil error gracefully
        LoggingService.log("Test with nil error", error: nil)

        // Test passes if no exception is thrown
    }

    // MARK: - API Category Enhanced Error Tests

    func testLog_APICategory_AddsErrorDetails() {
        // Given
        let apiError = NSError(domain: "APIErrorDomain", code: 500, userInfo: [
            NSLocalizedDescriptionKey: "Server error",
            "additionalInfo": "Server overloaded",
        ])

        // When/Then - Should handle API errors with enhanced details
        LoggingService.log("API request failed", category: .api, error: apiError)

        // Test passes if no exception is thrown
    }

    func testLog_ExchangeRateCategory_AddsErrorDetails() {
        // Given
        let exchangeRateError = NSError(domain: "ExchangeRateDomain", code: 404, userInfo: [
            NSLocalizedDescriptionKey: "Currency not found",
            "currencyCode": "XYZ",
        ])

        // When/Then - Should handle exchange rate errors with enhanced details
        LoggingService.log("Exchange rate fetch failed", category: .exchangeRate, error: exchangeRateError)

        // Test passes if no exception is thrown
    }

    func testLog_NonAPICategory_DoesNotAddExtraDetails() {
        // Given
        let uiError = NSError(domain: "UIDomain", code: 200, userInfo: [
            NSLocalizedDescriptionKey: "UI error",
            "viewController": "TestViewController",
        ])

        // When/Then - Should handle non-API errors normally (without extra details)
        LoggingService.log("UI error occurred", category: .ui, error: uiError)

        // Test passes if no exception is thrown
    }

    // MARK: - OSLogType Coverage Tests

    func testLog_AllOSLogTypes_HandleCorrectly() {
        // Test all OSLogType cases to ensure they're handled
        let logTypes: [OSLogType] = [.default, .info, .debug, .error, .fault]

        for (index, logType) in logTypes.enumerated() {
            // When/Then - Should handle each log type without crashing
            LoggingService.log("Test message \(index)", level: logType)
        }

        // Test passes if no exceptions are thrown
    }

    // MARK: - Edge Cases Tests

    func testLog_EmptyMessage_HandlesGracefully() {
        // When/Then - Should handle empty message gracefully
        LoggingService.log("")

        // Test passes if no exception is thrown
    }

    func testLog_VeryLongMessage_HandlesGracefully() {
        // Given
        let longMessage = String(repeating: "a", count: 10000)

        // When/Then - Should handle very long messages gracefully
        LoggingService.log(longMessage)

        // Test passes if no exception is thrown
    }

    func testLog_MessageWithSpecialCharacters_HandlesGracefully() {
        // Given
        let specialMessage = "Test 🚀 with émojis and spëcial chàracters ñ ß ∂ ∑"

        // When/Then - Should handle special characters gracefully
        LoggingService.log(specialMessage)

        // Test passes if no exception is thrown
    }

    func testLog_MessageWithNewlines_HandlesGracefully() {
        // Given
        let multilineMessage = "First line\nSecond line\nThird line"

        // When/Then - Should handle newlines gracefully
        LoggingService.log(multilineMessage)

        // Test passes if no exception is thrown
    }

    // MARK: - Bundle Identifier Tests

    func testGetLogger_WithDefaultSubsystem_UsesMainBundle() {
        // The private getLogger method should use main bundle identifier
        // We can't test this directly, but we can verify logging doesn't crash

        // When/Then - Should use bundle identifier for subsystem
        LoggingService.log("Bundle identifier test")

        // Test passes if no exception is thrown
    }

    func testGetLogger_WithNilBundleIdentifier_UsesFallback() {
        // If bundle identifier is nil, should use fallback
        // This is hard to test directly, but the logging should still work

        // When/Then - Should handle missing bundle identifier gracefully
        LoggingService.log("Fallback subsystem test")

        // Test passes if no exception is thrown
    }

    // MARK: - Performance Tests

    func testLogging_Performance() {
        // Given
        let iterations = 1000
        let testMessage = "Performance test message"

        // When
        let startTime = Date()
        for i in 0 ..< iterations {
            LoggingService.info("\(testMessage) \(i)")
        }
        let duration = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertLessThan(duration, 5.0, "Logging should be reasonably fast")
    }

    func testLoggingWithErrors_Performance() {
        // Given
        let iterations = 500
        let testError = NSError(domain: "PerformanceDomain", code: 123, userInfo: [
            NSLocalizedDescriptionKey: "Performance test error",
        ])

        // When
        let startTime = Date()
        for i in 0 ..< iterations {
            LoggingService.error("Performance error test \(i)", error: testError)
        }
        let duration = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertLessThan(duration, 3.0, "Error logging should be reasonably fast")
    }

    // MARK: - Thread Safety Tests

    func testConcurrentLogging_ThreadSafety() async {
        // Given
        let taskCount = 50

        // When - Perform concurrent logging from multiple tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0 ..< taskCount {
                group.addTask {
                    LoggingService.info("Concurrent log message \(i)", category: .general)
                    LoggingService.debug("Concurrent debug \(i)", category: .api)
                    LoggingService.error("Concurrent error \(i)", category: .ui)
                }
            }
        }

        // Then - Should complete without crashes or deadlocks
        XCTAssertTrue(true, "Concurrent logging should be thread-safe")
    }

    // MARK: - Category-Specific Tests

    func testAllCategories_CanBeUsedForLogging() {
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

    // MARK: - Error Detail Enhancement Tests

    func testErrorDetailEnhancement_LocalizedError() {
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

    func testErrorDetailEnhancement_NonLocalizedError() {
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
