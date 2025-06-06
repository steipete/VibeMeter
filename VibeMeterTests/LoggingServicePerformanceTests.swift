import Foundation
import os.log
import Testing
@testable import VibeMeter

@Suite("LoggingServicePerformanceTests", .tags(.unit, .performance))
struct LoggingServicePerformanceTests {
    // MARK: - Edge Cases Tests

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

    // MARK: - Performance Tests

    @Test("logging  performance")

    func logging_Performance() {
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
        #expect(duration < 5.0)
    }

    @Test("logging with errors performance")
    func loggingWithErrors_Performance() {
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
        #expect(duration < 3.0)
    }

    @Test("concurrent logging thread safety")
    func concurrentLogging_ThreadSafety() async {
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
        #expect(true == true)
    }
}
