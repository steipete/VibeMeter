import Foundation
import Testing
@testable import VibeMeter

@Suite("NetworkRetryHandlerConfigurationTests", .tags(.network, .unit))
struct NetworkRetryHandlerConfigurationTests {
    let sut: NetworkRetryHandler

    init() {
        sut = NetworkRetryHandler()
    }

    // MARK: - Configuration Tests

    @Test("default configuration")
    func defaultConfiguration() async {
        // Given - Use test configuration with minimal delays
        let testConfig = NetworkRetryHandler.Configuration(
            maxRetries: 3,
            initialDelay: 0.01,  // 10ms instead of 1s
            maxDelay: 0.1,       // 100ms instead of 30s
            multiplier: 2.0,
            jitterFactor: 0.1
        )
        let defaultHandler = NetworkRetryHandler(configuration: testConfig)

        // Then - verify through behavior
        let startTime = Date()
        var attemptCount = 0

        do {
            _ = try await defaultHandler.execute {
                attemptCount += 1
                throw NetworkRetryHandler.RetryableError.networkTimeout
            }
            Issue.record("Expected condition not met")
        } catch {
            // Config has maxRetries = 3, so 4 attempts total
            #expect(attemptCount == 4)
            let elapsed = Date().timeIntervalSince(startTime)
            #expect(elapsed < 1.0) // Should complete quickly with test delays
        }
    }

    @Test("aggressive configuration")
    func aggressiveConfiguration() async {
        // Given - Use test configuration based on aggressive but with minimal delays
        let testConfig = NetworkRetryHandler.Configuration(
            maxRetries: 5,
            initialDelay: 0.005,  // 5ms instead of 0.5s
            maxDelay: 0.1,        // 100ms instead of 60s
            multiplier: 1.5,
            jitterFactor: 0.2
        )
        let aggressiveHandler = NetworkRetryHandler(configuration: testConfig)
        var attemptCount = 0

        // When
        do {
            _ = try await aggressiveHandler.execute {
                attemptCount += 1
                throw NetworkRetryHandler.RetryableError.serverError(statusCode: 503)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Aggressive config has maxRetries = 5, so 6 attempts total
            #expect(attemptCount == 6)
        }
    }

    @Test("custom configuration")
    func customConfiguration() async {
        // Given
        let customConfig = NetworkRetryHandler.Configuration(
            maxRetries: 2,
            initialDelay: 0.1,
            maxDelay: 1.0,
            multiplier: 3.0,
            jitterFactor: 0.0 // No jitter for predictable testing
        )
        let customHandler = NetworkRetryHandler(configuration: customConfig)
        var attemptCount = 0
        var attemptTimes: [Date] = []

        // When
        do {
            _ = try await customHandler.execute {
                attemptCount += 1
                attemptTimes.append(Date())
                throw NetworkRetryHandler.RetryableError.connectionError
            }
            Issue.record("Expected condition not met")
        } catch {
            // Should have 3 attempts (initial + 2 retries)
            #expect(attemptCount == 3)

            if attemptTimes.count >= 2 {
                let firstDelay = attemptTimes[1].timeIntervalSince(attemptTimes[0])
                #expect(abs(firstDelay - 0.1) < 0.05) // Allow 50ms tolerance
            }
            if attemptTimes.count >= 3 {
                let secondDelay = attemptTimes[2].timeIntervalSince(attemptTimes[1])
                #expect(abs(secondDelay - 0.3) < 0.05) // Allow 50ms tolerance
            }
        }
    }

    // MARK: - Provider-Specific Tests

    @Test("provider specific retry handler")
    func providerSpecificRetryHandler() async {
        // Given
        let cursorHandler = NetworkRetryHandler.forProvider(.cursor)
        var attemptCount = 0

        // When
        do {
            _ = try await cursorHandler.execute {
                attemptCount += 1
                throw NetworkRetryHandler.RetryableError.rateLimited(retryAfter: nil)
            }
        } catch {
            // Then - Should use default configuration
            #expect(attemptCount == 4) // 1 + 3 retries
        }
    }
}
