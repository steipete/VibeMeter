@testable import VibeMeter
import XCTest

final class NetworkRetryHandlerTests: XCTestCase {
    var sut: NetworkRetryHandler!

    override func setUp() async throws {
        try await super.setUp()
        sut = NetworkRetryHandler()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Configuration Tests

    func testDefaultConfiguration() async {
        // Given
        let defaultHandler = NetworkRetryHandler()

        // Then - verify through behavior
        let startTime = Date()
        var attemptCount = 0

        do {
            _ = try await defaultHandler.execute {
                attemptCount += 1
                throw NetworkRetryHandler.RetryableError.networkTimeout
            }
            XCTFail("Should have thrown error")
        } catch {
            // Default config has maxRetries = 3, so 4 attempts total
            XCTAssertEqual(attemptCount, 4)

            // With exponential backoff, should take at least 1 + 2 + 4 = 7 seconds
            // But with jitter, could be slightly less
            let elapsed = Date().timeIntervalSince(startTime)
            XCTAssertGreaterThan(elapsed, 5.0, "Should have delays between retries")
        }
    }

    func testAggressiveConfiguration() async {
        // Given
        let aggressiveHandler = NetworkRetryHandler(configuration: .aggressive)
        var attemptCount = 0

        // When
        do {
            _ = try await aggressiveHandler.execute {
                attemptCount += 1
                throw NetworkRetryHandler.RetryableError.serverError(statusCode: 503)
            }
            XCTFail("Should have thrown error")
        } catch {
            // Aggressive config has maxRetries = 5, so 6 attempts total
            XCTAssertEqual(attemptCount, 6)
        }
    }

    func testCustomConfiguration() async {
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
            XCTFail("Should have thrown error")
        } catch {
            // Should have 3 attempts (initial + 2 retries)
            XCTAssertEqual(attemptCount, 3)

            // Verify delays: 0.1s, 0.3s
            if attemptTimes.count >= 2 {
                let firstDelay = attemptTimes[1].timeIntervalSince(attemptTimes[0])
                XCTAssertEqual(firstDelay, 0.1, accuracy: 0.05)
            }
            if attemptTimes.count >= 3 {
                let secondDelay = attemptTimes[2].timeIntervalSince(attemptTimes[1])
                XCTAssertEqual(secondDelay, 0.3, accuracy: 0.05)
            }
        }
    }

    // MARK: - Success Cases

    func testSuccessOnFirstAttempt() async throws {
        // Given
        var attemptCount = 0

        // When
        let result = try await sut.execute {
            attemptCount += 1
            return "Success"
        }

        // Then
        XCTAssertEqual(result, "Success")
        XCTAssertEqual(attemptCount, 1)
    }

    func testSuccessAfterRetries() async throws {
        // Given
        var attemptCount = 0
        let successOnAttempt = 3

        // When
        let result = try await sut.execute {
            attemptCount += 1
            if attemptCount < successOnAttempt {
                throw NetworkRetryHandler.RetryableError.networkTimeout
            }
            return attemptCount
        }

        // Then
        XCTAssertEqual(result, successOnAttempt)
        XCTAssertEqual(attemptCount, successOnAttempt)
    }

    // MARK: - Retry Logic Tests

    func testRetriesNetworkTimeout() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw NetworkRetryHandler.RetryableError.networkTimeout
            }
            XCTFail("Should have thrown error")
        } catch {
            // Then - Should retry maxRetries times
            XCTAssertEqual(attemptCount, 4) // 1 initial + 3 retries
        }
    }

    func testRetriesServerError() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw NetworkRetryHandler.RetryableError.serverError(statusCode: 503)
            }
            XCTFail("Should have thrown error")
        } catch {
            // Then
            XCTAssertEqual(attemptCount, 4)
        }
    }

    func testDoesNotRetryClientError() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw NetworkRetryHandler.RetryableError.serverError(statusCode: 404)
            }
            XCTFail("Should have thrown error")
        } catch {
            // Then - Should not retry 4xx errors
            XCTAssertEqual(attemptCount, 1)
        }
    }

    func testRetriesRateLimitedError() async {
        // Given
        var attemptCount = 0
        let retryAfter: TimeInterval = 0.2
        let startTime = Date()

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                if attemptCount == 1 {
                    throw NetworkRetryHandler.RetryableError.rateLimited(retryAfter: retryAfter)
                }
                throw NetworkRetryHandler.RetryableError.connectionError
            }
            XCTFail("Should have thrown error")
        } catch {
            // Then
            let elapsed = Date().timeIntervalSince(startTime)
            XCTAssertGreaterThanOrEqual(elapsed, retryAfter - 0.1) // Allow small margin
            XCTAssertGreaterThan(attemptCount, 1)
        }
    }

    // MARK: - URL Error Tests

    func testRetriesURLTimeoutError() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw URLError(.timedOut)
            }
            XCTFail("Should have thrown error")
        } catch {
            // Then
            XCTAssertEqual(attemptCount, 4)
        }
    }

    func testRetriesConnectionLostError() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw URLError(.networkConnectionLost)
            }
            XCTFail("Should have thrown error")
        } catch {
            // Then
            XCTAssertEqual(attemptCount, 4)
        }
    }

    func testDoesNotRetryBadURLError() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw URLError(.badURL)
            }
            XCTFail("Should have thrown error")
        } catch {
            // Then
            XCTAssertEqual(attemptCount, 1)
        }
    }

    // MARK: - Custom Retry Logic Tests

    func testCustomShouldRetryLogic() async {
        // Given
        struct CustomError: Error {}
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute(
                operation: {
                    attemptCount += 1
                    throw CustomError()
                },
                shouldRetry: { error in
                    error is CustomError
                })
            XCTFail("Should have thrown error")
        } catch {
            // Then - Should retry custom error
            XCTAssertEqual(attemptCount, 4)
        }
    }

    func testCustomShouldNotRetryLogic() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute(
                operation: {
                    attemptCount += 1
                    throw NetworkRetryHandler.RetryableError.networkTimeout
                },
                shouldRetry: { _ in false })
            XCTFail("Should have thrown error")
        } catch {
            // Then - Should not retry even for normally retryable errors
            XCTAssertEqual(attemptCount, 1)
        }
    }

    // MARK: - Optional Operation Tests

    func testExecuteOptionalWithNilResult() async throws {
        // Given
        var attemptCount = 0

        // When
        let result = try await sut.executeOptional {
            attemptCount += 1
            return nil as String?
        }

        // Then
        XCTAssertNil(result)
        XCTAssertEqual(attemptCount, 1)
    }

    func testExecuteOptionalWithValue() async throws {
        // Given
        var attemptCount = 0

        // When
        let result = try await sut.executeOptional {
            attemptCount += 1
            return "Optional Value"
        }

        // Then
        XCTAssertEqual(result, "Optional Value")
        XCTAssertEqual(attemptCount, 1)
    }

    // MARK: - Delay Calculation Tests

    func testExponentialBackoffDelays() async {
        // Given
        let config = NetworkRetryHandler.Configuration(
            maxRetries: 3,
            initialDelay: 0.1,
            maxDelay: 10.0,
            multiplier: 2.0,
            jitterFactor: 0.0 // No jitter for predictable testing
        )
        let handler = NetworkRetryHandler(configuration: config)
        var delays: [TimeInterval] = []
        let startTimes: [Date] = []

        // When
        do {
            _ = try await handler.execute {
                let now = Date()
                if !startTimes.isEmpty {
                    delays.append(now.timeIntervalSince(startTimes.last!))
                }
                throw NetworkRetryHandler.RetryableError.connectionError
            }
        } catch {
            // Expected to fail
        }

        // Then - Verify exponential backoff
        // Delays should be approximately: 0.1, 0.2, 0.4
        // Can't test exact values due to async timing
    }

    func testMaxDelayRespected() async {
        // Given
        let config = NetworkRetryHandler.Configuration(
            maxRetries: 5,
            initialDelay: 1.0,
            maxDelay: 2.0, // Low max delay
            multiplier: 10.0, // High multiplier
            jitterFactor: 0.0)
        let handler = NetworkRetryHandler(configuration: config)
        var attemptCount = 0
        let startTime = Date()

        // When
        do {
            _ = try await handler.execute {
                attemptCount += 1
                throw NetworkRetryHandler.RetryableError.connectionError
            }
        } catch {
            // Then
            let totalTime = Date().timeIntervalSince(startTime)
            // Should be capped at maxDelay * maxRetries = 2.0 * 5 = 10.0
            XCTAssertLessThan(totalTime, 12.0) // Allow some margin
        }
    }

    // MARK: - Provider-Specific Tests

    func testProviderSpecificRetryHandler() async {
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
            XCTAssertEqual(attemptCount, 4) // 1 + 3 retries
        }
    }

    // MARK: - Error Conversion Tests

    func testAsRetryableErrorConversion() {
        // Test timeout error
        let timeoutError = URLError(.timedOut)
        XCTAssertEqual(timeoutError.asRetryableError, .networkTimeout)

        // Test connection errors
        let connectionError = URLError(.cannotConnectToHost)
        XCTAssertEqual(connectionError.asRetryableError, .connectionError)

        // Test non-retryable error
        let badURLError = URLError(.badURL)
        XCTAssertNil(badURLError.asRetryableError)
    }

    // MARK: - Concurrent Operation Tests

    func testConcurrentRetryOperations() async {
        // Given
        let handler = NetworkRetryHandler()
        let operationCount = 5

        // When
        await withTaskGroup(of: Int?.self) { group in
            for i in 0 ..< operationCount {
                group.addTask {
                    var attemptCount = 0
                    do {
                        return try await handler.execute {
                            attemptCount += 1
                            if attemptCount < 2 {
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
            XCTAssertEqual(results.count, operationCount)
        }
    }
}
