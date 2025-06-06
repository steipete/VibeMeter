import Foundation
import Testing
@testable import VibeMeter

@Suite("NetworkRetryHandlerExecutionTests", .tags(.network, .unit))
struct NetworkRetryHandlerExecutionTests {
    let sut: NetworkRetryHandler

    init() async throws {
        sut = NetworkRetryHandler()
    }

    // MARK: - Success Cases

    @Test("success on first attempt")
    func successOnFirstAttempt() async throws {
        // Given
        var attemptCount = 0

        // When
        let result = try await sut.execute {
            attemptCount += 1
            return "Success"
        }

        // Then
        #expect(result == "Success")
        #expect(attemptCount == 1)
    }

    @Test("success after retries")
    func successAfterRetries() async throws {
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
        #expect(result == successOnAttempt)
        #expect(attemptCount == successOnAttempt)
    }

    // MARK: - Retry Logic Tests

    @Test("retries network timeout")
    func retriesNetworkTimeout() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw NetworkRetryHandler.RetryableError.networkTimeout
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then - Should retry maxRetries times
            #expect(attemptCount == 4) // 1 initial + 3 retries
        }
    }

    @Test("retries server error")
    func retriesServerError() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw NetworkRetryHandler.RetryableError.serverError(statusCode: 503)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 4) // 1 initial + 3 retries
        }
    }

    @Test("does not retry client error")
    func doesNotRetryClientError() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw NetworkRetryHandler.RetryableError.serverError(statusCode: 404)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then - Should not retry 4xx errors
            #expect(attemptCount == 1)
        }
    }

    @Test("retries rate limited error")
    func retriesRateLimitedError() async {
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
            Issue.record("Expected condition not met")
        } catch {
            // Then
            let elapsed = Date().timeIntervalSince(startTime)
            #expect(elapsed >= retryAfter - 0.1) // Allow some tolerance
            #expect(attemptCount > 1) // Should have retried at least once
        }
    }

    // MARK: - URL Error Tests

    @Test("retries url timeout error")
    func retriesURLTimeoutError() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw URLError(.timedOut)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 4) // 1 initial + 3 retries
        }
    }

    @Test("retries connection lost error")
    func retriesConnectionLostError() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw URLError(.networkConnectionLost)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 4) // 1 initial + 3 retries
        }
    }

    @Test("does not retry bad url error")
    func doesNotRetryBadURLError() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw URLError(.badURL)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 1) // Should not retry
        }
    }

    @Test("custom should retry logic")
    func customShouldRetryLogic() async {
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
            Issue.record("Expected condition not met")
        } catch {
            // Then - Should retry custom error
            #expect(attemptCount == 4) // 1 initial + 3 retries
        }
    }

    @Test("custom should not retry logic")
    func customShouldNotRetryLogic() async {
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
            Issue.record("Expected condition not met")
        } catch {
            // Then - Should not retry even for normally retryable errors
            #expect(attemptCount == 1)
        }
    }

    @Test("execute optional with nil result")
    func executeOptionalWithNilResult() async throws {
        // Given
        var attemptCount = 0

        // When
        let result = try await sut.executeOptional {
            attemptCount += 1
            return nil as String?
        }

        // Then
        #expect(result == nil)
        #expect(attemptCount == 1)
    }

    @Test("execute optional with value")
    func executeOptionalWithValue() async throws {
        // Given
        var attemptCount = 0

        // When
        let result = try await sut.executeOptional {
            attemptCount += 1
            return "Optional Value"
        }

        // Then
        #expect(result == "Optional Value")
        #expect(attemptCount == 1)
    }
}
