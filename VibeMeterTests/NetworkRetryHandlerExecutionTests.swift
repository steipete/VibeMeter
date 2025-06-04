@testable import VibeMeter
import XCTest

final class NetworkRetryHandlerExecutionTests: XCTestCase {
    var sut: NetworkRetryHandler!

    override func setUp() async throws {
        try await super.setUp()
        sut = NetworkRetryHandler()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
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
}
