// swiftlint:disable file_length type_body_length nesting
import Foundation
import Testing
@testable import VibeMeter

/// Actor for thread-safe state tracking in tests
actor TestStateTracker {
    private(set) var attemptCount: Int = 0
    private(set) var attemptTimes: [Date] = []
    private(set) var delays: [TimeInterval] = []
    private(set) var startTimes: [Date] = []

    func incrementAttempt() {
        attemptCount += 1
    }

    func recordAttemptTime(_ time: Date = Date()) {
        attemptTimes.append(time)
    }

    func recordStartTime(_ time: Date = Date()) {
        startTimes.append(time)
        if startTimes.count > 1 {
            let delay = time.timeIntervalSince(startTimes[startTimes.count - 2])
            delays.append(delay)
        }
    }

    func reset() {
        attemptCount = 0
        attemptTimes.removeAll()
        delays.removeAll()
        startTimes.removeAll()
    }
}

@Suite("NetworkRetryHandler Tests", .tags(.network, .unit))
@MainActor
struct NetworkRetryHandlerTests {
    @Suite("Configuration Tests")
    struct ConfigurationTests {
        let sut: NetworkRetryHandler

        init() {
            sut = NetworkRetryHandler()
        }

        @Test("default configuration")
        func defaultConfiguration() async {
            // Given - Use test configuration with minimal delays
            let testConfig = NetworkRetryHandler.Configuration(
                maxRetries: 3,
                initialDelay: 0.01, // 10ms instead of 1s
                maxDelay: 0.1, // 100ms instead of 30s
                multiplier: 2.0,
                jitterFactor: 0.1)
            let defaultHandler = NetworkRetryHandler(configuration: testConfig)

            // Then - verify through behavior
            let startTime = Date()

            await #expect(throws: Error.self) { @Sendable in
                try await defaultHandler.execute {
                    throw NetworkRetryHandler.RetryableError.networkTimeout
                }
            }

            let elapsed = Date().timeIntervalSince(startTime)
            #expect(elapsed < 1.0) // Should complete quickly with test delays
        }

        @Test("aggressive configuration")
        func aggressiveConfiguration() async {
            // Given - Use test configuration based on aggressive but with minimal delays
            let testConfig = NetworkRetryHandler.Configuration(
                maxRetries: 5,
                initialDelay: 0.005, // 5ms instead of 0.5s
                maxDelay: 0.1, // 100ms instead of 60s
                multiplier: 1.5,
                jitterFactor: 0.2)
            let aggressiveHandler = NetworkRetryHandler(configuration: testConfig)

            // When
            await #expect(throws: Error.self) { @Sendable in
                try await aggressiveHandler.execute {
                    throw NetworkRetryHandler.RetryableError.serverError(statusCode: 503)
                }
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
            let tracker = TestStateTracker()

            // When/Then - Advanced error handling with payload inspection
            await #expect(throws: (any Error).self) {
                try await customHandler.execute { @Sendable in
                    await tracker.incrementAttempt()
                    await tracker.recordAttemptTime()
                    throw NetworkRetryHandler.RetryableError.connectionError
                }
            }

            // Verify attempts were made correctly
            let finalAttemptCount = await tracker.attemptCount
            let attemptTimes = await tracker.attemptTimes
            #expect(finalAttemptCount == 3) // Initial + 2 retries
            #expect(attemptTimes.count == 3)

            if attemptTimes.count >= 2 {
                let firstDelay = attemptTimes[1].timeIntervalSince(attemptTimes[0])
                #expect(abs(firstDelay - 0.1) < 0.05) // Allow 50ms tolerance
            }
            if attemptTimes.count >= 3 {
                let secondDelay = attemptTimes[2].timeIntervalSince(attemptTimes[1])
                #expect(abs(secondDelay - 0.3) < 0.05) // Allow 50ms tolerance
            }
        }

        @Test("provider specific retry handler")
        func providerSpecificRetryHandler() async {
            // Given
            let cursorHandler = NetworkRetryHandler.forProvider(.cursor)
            let tracker = TestStateTracker()

            // When
            await #expect(throws: NetworkRetryHandler.RetryableError.rateLimited(retryAfter: nil)) {
                try await cursorHandler.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw NetworkRetryHandler.RetryableError.rateLimited(retryAfter: nil)
                }
            }

            // Then - Should use default configuration
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 4) // 1 + 3 retries
        }
    }

    @Suite("Delay Tests")
    struct DelayTests {
        @Test("exponential backoff delays")
        func exponentialBackoffDelays() async {
            // Given
            let config = NetworkRetryHandler.Configuration(
                maxRetries: 3,
                initialDelay: 0.1,
                maxDelay: 10.0,
                multiplier: 2.0,
                jitterFactor: 0.0 // No jitter for predictable testing
            )
            let handler = NetworkRetryHandler(configuration: config)
            let tracker = TestStateTracker()

            // When
            await #expect(throws: (any Error).self) {
                try await handler.execute { @Sendable in
                    await tracker.recordStartTime()
                    throw NetworkRetryHandler.RetryableError.connectionError
                }
            }

            // Then - Verify exponential backoff
            // Delays should be approximately: 0.1, 0.2, 0.4
            // Can't test exact values due to async timing, but verify increasing pattern
            let delays = await tracker.delays
            #expect(delays.count >= 2)
            if delays.count >= 2 {
                #expect(delays[1] > delays[0]) // Second delay should be larger
            }
        }

        @Test("max delay respected")
        func maxDelayRespected() async {
            // Given - Use millisecond delays for faster tests
            let config = NetworkRetryHandler.Configuration(
                maxRetries: 5,
                initialDelay: 0.01, // 10ms instead of 1s
                maxDelay: 0.02, // 20ms instead of 2s
                multiplier: 10.0, // High multiplier
                jitterFactor: 0.0)
            let handler = NetworkRetryHandler(configuration: config)
            let tracker = TestStateTracker()
            let startTime = Date()

            // When
            await #expect(throws: (any Error).self) {
                try await handler.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw NetworkRetryHandler.RetryableError.connectionError
                }
            }

            // Then
            let totalTime = Date().timeIntervalSince(startTime)
            let finalAttemptCount = await tracker.attemptCount
            // Should be capped at maxDelay * maxRetries = 0.02 * 5 = 0.1
            #expect(totalTime < 0.2) // Allow some margin
            #expect(finalAttemptCount == 6) // 1 initial + 5 retries
        }

        @Test("retryable error conversion")
        func asRetryableErrorConversion() {
            // Test timeout error
            let timeoutError = URLError(.timedOut)
            #expect(timeoutError.asRetryableError == .networkTimeout)

            // Test connection error
            let connectionError = URLError(.notConnectedToInternet)
            #expect(connectionError.asRetryableError == .connectionError)

            // Test non-retryable error
            let badURLError = URLError(.badURL)
            #expect(badURLError.asRetryableError == nil)
        }

        @Test("concurrent retry operations")
        func concurrentRetryOperations() async {
            // Given
            let handler = NetworkRetryHandler()
            let operationCount = 5

            // When
            await withTaskGroup(of: Int?.self) { group in
                for i in 0 ..< operationCount {
                    group.addTask {
                        let tracker = TestStateTracker()
                        do {
                            return try await handler.execute { @Sendable in
                                await tracker.incrementAttempt()
                                let count = await tracker.attemptCount
                                if count < 2 {
                                    throw NetworkRetryHandler.RetryableError.networkTimeout
                                }
                                return i
                            }
                        } catch {
                            return nil
                        }
                    }
                }

                // Collect results
                var results: [Int] = []
                for await result in group {
                    if let value = result {
                        results.append(value)
                    }
                }

                // Then
                #expect(results.count == operationCount)
            }
        }
    }

    @Suite("Execution Tests")
    struct ExecutionTests {
        let sut: NetworkRetryHandler

        // Test configuration with minimal delays for fast execution
        static let testConfig = NetworkRetryHandler.Configuration(
            maxRetries: 3,
            initialDelay: 0.001, // 1ms instead of 1s
            maxDelay: 0.01, // 10ms instead of 30s
            multiplier: 2.0,
            jitterFactor: 0.1)

        init() {
            sut = NetworkRetryHandler(configuration: Self.testConfig)
        }

        // MARK: - Success Cases

        @Test("success on first attempt")
        func successOnFirstAttempt() async throws {
            // Given
            let tracker = TestStateTracker()

            // When
            let result = try await sut.execute { @Sendable in
                await tracker.incrementAttempt()
                return "Success"
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(result == "Success")
            #expect(finalAttemptCount == 1)
        }

        @Test("success after retries")
        func successAfterRetries() async throws {
            // Given
            let tracker = TestStateTracker()
            let successOnAttempt = 3

            // When
            let result = try await sut.execute { @Sendable in
                await tracker.incrementAttempt()
                let count = await tracker.attemptCount
                if count < successOnAttempt {
                    throw NetworkRetryHandler.RetryableError.networkTimeout
                }
                return count
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(result == successOnAttempt)
            #expect(finalAttemptCount == successOnAttempt)
        }

        // MARK: - Retry Logic Tests

        @Test("retries network timeout")
        func retriesNetworkTimeout() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw NetworkRetryHandler.RetryableError.networkTimeout
                }
            } catch {
                // Expected - should retry and then fail
            }

            // Then - Should retry maxRetries times
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 4) // 1 initial + 3 retries
        }

        @Test("retries server error")
        func retriesServerError() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw NetworkRetryHandler.RetryableError.serverError(statusCode: 503)
                }
            } catch {
                // Expected - should retry and then fail
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 4) // 1 initial + 3 retries
        }

        @Test("does not retry client error")
        func doesNotRetryClientError() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw NetworkRetryHandler.RetryableError.serverError(statusCode: 404)
                }
            } catch {
                // Expected - client errors should not retry
            }

            // Then - Client errors (4xx) should not retry
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 1)
        }

        @Test("retries rate limited error")
        func retriesRateLimitedError() async {
            // Given
            let tracker = TestStateTracker()
            let testHandler = NetworkRetryHandler(configuration: NetworkRetryHandler.Configuration(
                maxRetries: 2,
                initialDelay: 0.001, // Use very short delay for tests
                maxDelay: 0.01,
                multiplier: 2.0,
                jitterFactor: 0.0 // No jitter for predictable test
            ))

            // When
            do {
                _ = try await testHandler.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw NetworkRetryHandler.RetryableError.rateLimited(retryAfter: 0.001)
                }
            } catch {
                // Expected - should retry and then fail
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 3) // 1 initial + 2 retries
        }

        @Test("retries url timeout error")
        func retriesURLTimeoutError() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw URLError(.timedOut)
                }
            } catch {
                // Expected - should retry and then fail
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 4) // 1 initial + 3 retries
        }

        @Test("retries connection lost error")
        func retriesConnectionLostError() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw URLError(.networkConnectionLost)
                }
            } catch {
                // Expected - should retry and then fail
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 4) // 1 initial + 3 retries
        }

        @Test("does not retry bad url error")
        func doesNotRetryBadURLError() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw URLError(.badURL)
                }
            } catch {
                // Expected - should not retry bad URL errors
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 1) // No retries for non-retryable errors
        }

        @Test("custom should retry logic")
        func customShouldRetryLogic() async {
            // Given
            let tracker = TestStateTracker()
            struct CustomError: Error {}

            // When
            do {
                _ = try await sut.execute(
                    operation: { @Sendable in
                        await tracker.incrementAttempt()
                        throw CustomError()
                    },
                    shouldRetry: { error in
                        // Custom logic: retry any CustomError
                        error is CustomError
                    })
            } catch {
                // Expected - should retry based on custom logic and then fail
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 4) // Should retry based on custom logic
        }

        @Test("custom should not retry logic")
        func customShouldNotRetryLogic() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute(
                    operation: { @Sendable in
                        await tracker.incrementAttempt()
                        throw NetworkRetryHandler.RetryableError.networkTimeout
                    },
                    shouldRetry: { _ in false }) // Never retry
            } catch {
                // Expected - should not retry due to custom logic
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 1) // No retries due to custom logic
        }

        @Test("execute optional with nil result")
        func executeOptionalWithNilResult() async throws {
            // Given
            let tracker = TestStateTracker()

            // When
            let result = try await sut.executeOptional { @Sendable in
                await tracker.incrementAttempt()
                return nil as String?
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(result == nil)
            #expect(finalAttemptCount == 1)
        }

        @Test("execute optional with value")
        func executeOptionalWithValue() async throws {
            // Given
            let tracker = TestStateTracker()

            // When
            let result = try await sut.executeOptional { @Sendable in
                await tracker.incrementAttempt()
                return "Optional Value" as String?
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(result == "Optional Value")
            #expect(finalAttemptCount == 1)
        }

        // MARK: - Error Conversion Tests

        @Test("network error timeout")
        func networkErrorTimeout() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw URLError(.timedOut)
                }
            } catch {
                // Expected - should retry and then fail
                #expect(error is URLError)
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 4) // Should retry network timeouts
        }

        @Test("network error connection lost")
        func networkErrorConnectionLost() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw URLError(.networkConnectionLost)
                }
            } catch {
                // Expected - should retry and then fail
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 4) // Should retry connection errors
        }

        @Test("network error not connected")
        func networkErrorNotConnected() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw URLError(.notConnectedToInternet)
                }
            } catch {
                // Expected - should retry and then fail
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 4) // Should retry connection errors
        }

        @Test("network error dns lookup failed")
        func networkErrorDNSLookupFailed() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw URLError(.cannotFindHost)
                }
            } catch {
                // Expected - should retry and then fail
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 4) // Should retry DNS errors
        }

        @Test("network error cannot connect")
        func networkErrorCannotConnect() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw URLError(.cannotConnectToHost)
                }
            } catch {
                // Expected - should retry and then fail
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 4) // Should retry connection errors
        }

        @Test("network error bad server response")
        func networkErrorBadServerResponse() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw URLError(.badServerResponse)
                }
            } catch {
                // Expected - should not retry bad server response
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 1) // badServerResponse is not retryable
        }

        @Test("network error zero byte resource")
        func networkErrorZeroByteResource() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw URLError(.zeroByteResource)
                }
            } catch {
                // Expected - should not retry zero byte resource error
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 1) // zeroByteResource is not retryable
        }

        @Test("network error cannot decode raw data")
        func networkErrorCannotDecodeRawData() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw URLError(.cannotDecodeRawData)
                }
            } catch {
                // Expected - should not retry decode error
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 1) // cannotDecodeRawData is not retryable
        }

        @Test("network error cannot decode content data")
        func networkErrorCannotDecodeContentData() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw URLError(.cannotDecodeContentData)
                }
            } catch {
                // Expected - should not retry content decode error
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 1) // cannotDecodeContentData is not retryable
        }

        @Test("network error cannot parse response")
        func networkErrorCannotParseResponse() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw URLError(.cannotParseResponse)
                }
            } catch {
                // Expected - should not retry parse error
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 1) // cannotParseResponse is not retryable
        }

        @Test("network error secure connection failed")
        func networkErrorSecureConnectionFailed() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw URLError(.secureConnectionFailed)
                }
            } catch {
                // Expected - should not retry security error
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 1) // secureConnectionFailed is not retryable
        }

        @Test("network error server certificate invalid")
        func networkErrorServerCertificateInvalid() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw URLError(.serverCertificateNotYetValid)
                }
            } catch {
                // Expected - should not retry certificate error
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 1) // Should not retry certificate errors
        }

        @Test("network error service unavailable")
        func networkErrorServiceUnavailable() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    // HTTP 503 Service Unavailable
                    throw NetworkRetryHandler.RetryableError.serverError(statusCode: 503)
                }
            } catch {
                // Expected - should retry and then fail
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 4) // Should retry 503 errors
        }

        @Test("network error gateway timeout")
        func networkErrorGatewayTimeout() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    // HTTP 504 Gateway Timeout
                    throw NetworkRetryHandler.RetryableError.serverError(statusCode: 504)
                }
            } catch {
                // Expected - should retry and then fail
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 4) // Should retry gateway timeouts
        }

        @Test("network error decoding error")
        func networkErrorDecodingError() async {
            // Given
            let tracker = TestStateTracker()
            struct DecodingError: Error {}

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw DecodingError()
                }
            } catch {
                // Expected - should not retry decoding error
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 1) // Should not retry generic decoding errors
        }

        @Test("network error generic network failure")
        func networkErrorGenericNetworkFailure() async {
            // Given
            let tracker = TestStateTracker()

            // When
            do {
                _ = try await sut.execute { @Sendable in
                    await tracker.incrementAttempt()
                    throw NetworkRetryHandler.RetryableError.connectionError
                }
            } catch {
                // Expected - should retry and then fail
            }

            // Then
            let finalAttemptCount = await tracker.attemptCount
            #expect(finalAttemptCount == 4) // Should retry generic network errors
        }
    }
}
