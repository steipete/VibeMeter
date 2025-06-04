import os.log
@testable import VibeMeter
import XCTest

final class LoggingServiceCoreTests: XCTestCase {
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
}
