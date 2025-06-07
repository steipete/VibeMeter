import Foundation
import Testing
@testable import VibeMeter

@Suite("NetworkRetryHandlerExecutionTests", .tags(.network, .unit))
struct NetworkRetryHandlerExecutionTests {
    let sut: NetworkRetryHandler
    
    // Test configuration with minimal delays for fast execution
    static let testConfig = NetworkRetryHandler.Configuration(
        maxRetries: 3,
        initialDelay: 0.001,  // 1ms instead of 1s
        maxDelay: 0.01,       // 10ms instead of 30s
        multiplier: 2.0,
        jitterFactor: 0.1
    )

    init() async throws {
        sut = NetworkRetryHandler(configuration: Self.testConfig)
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
            // Then - Client errors (4xx) should not retry
            #expect(attemptCount == 1)
        }
    }

    @Test("retries rate limited error")
    func retriesRateLimitedError() async {
        // Given
        var attemptCount = 0
        let testHandler = NetworkRetryHandler(configuration: NetworkRetryHandler.Configuration(
            maxRetries: 2,
            initialDelay: 0.001,  // Use very short delay for tests
            maxDelay: 0.01,
            multiplier: 2.0,
            jitterFactor: 0.0  // No jitter for predictable test
        ))

        // When
        do {
            _ = try await testHandler.execute {
                attemptCount += 1
                throw NetworkRetryHandler.RetryableError.rateLimited(retryAfter: 0.001)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 3) // 1 initial + 2 retries
        }
    }

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
            #expect(attemptCount == 1) // No retries for non-retryable errors
        }
    }

    @Test("custom should retry logic")
    func customShouldRetryLogic() async {
        // Given
        var attemptCount = 0
        struct CustomError: Error {}

        // When
        do {
            _ = try await sut.execute(
                operation: {
                    attemptCount += 1
                    throw CustomError()
                },
                shouldRetry: { error in
                    // Custom logic: retry any CustomError
                    error is CustomError
                })
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 4) // Should retry based on custom logic
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
                shouldRetry: { _ in false }) // Never retry
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 1) // No retries due to custom logic
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
            return "Optional Value" as String?
        }

        // Then
        #expect(result == "Optional Value")
        #expect(attemptCount == 1)
    }

    // MARK: - Error Conversion Tests

    @Test("network error timeout")
    func networkErrorTimeout() async {
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
            #expect(attemptCount == 4) // Should retry network timeouts
            #expect(error is URLError)
        }
    }

    @Test("network error connection lost")
    func networkErrorConnectionLost() async {
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
            #expect(attemptCount == 4) // Should retry connection errors
        }
    }

    @Test("network error not connected")
    func networkErrorNotConnected() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw URLError(.notConnectedToInternet)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 4) // Should retry connection errors
        }
    }

    @Test("network error dns lookup failed")
    func networkErrorDNSLookupFailed() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw URLError(.cannotFindHost)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 4) // Should retry DNS errors
        }
    }

    @Test("network error cannot connect")
    func networkErrorCannotConnect() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw URLError(.cannotConnectToHost)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 4) // Should retry connection errors
        }
    }

    @Test("network error bad server response")
    func networkErrorBadServerResponse() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw URLError(.badServerResponse)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 4) // Should retry server errors
        }
    }

    @Test("network error zero byte resource")
    func networkErrorZeroByteResource() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw URLError(.zeroByteResource)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 4) // Should retry data errors
        }
    }

    @Test("network error cannot decode raw data")
    func networkErrorCannotDecodeRawData() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw URLError(.cannotDecodeRawData)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 4) // Should retry decoding errors
        }
    }

    @Test("network error cannot decode content data")
    func networkErrorCannotDecodeContentData() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw URLError(.cannotDecodeContentData)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 4) // Should retry decoding errors
        }
    }

    @Test("network error cannot parse response")
    func networkErrorCannotParseResponse() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw URLError(.cannotParseResponse)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 4) // Should retry parsing errors
        }
    }

    @Test("network error secure connection failed")
    func networkErrorSecureConnectionFailed() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw URLError(.secureConnectionFailed)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 4) // Should retry SSL errors
        }
    }

    @Test("network error server certificate invalid")
    func networkErrorServerCertificateInvalid() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw URLError(.serverCertificateNotYetValid)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 1) // Should not retry certificate errors
        }
    }

    @Test("network error service unavailable")
    func networkErrorServiceUnavailable() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                // HTTP 503 Service Unavailable
                throw NetworkRetryHandler.RetryableError.serverError(statusCode: 503)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 4) // Should retry 503 errors
        }
    }

    @Test("network error gateway timeout")
    func networkErrorGatewayTimeout() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                // HTTP 504 Gateway Timeout
                throw NetworkRetryHandler.RetryableError.serverError(statusCode: 504)
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 4) // Should retry gateway timeouts
        }
    }

    @Test("network error decoding error")
    func networkErrorDecodingError() async {
        // Given
        var attemptCount = 0
        struct DecodingError: Error {}

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw DecodingError()
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 1) // Should not retry generic decoding errors
        }
    }

    @Test("network error generic network failure")
    func networkErrorGenericNetworkFailure() async {
        // Given
        var attemptCount = 0

        // When
        do {
            _ = try await sut.execute {
                attemptCount += 1
                throw NetworkRetryHandler.RetryableError.connectionError
            }
            Issue.record("Expected condition not met")
        } catch {
            // Then
            #expect(attemptCount == 4) // Should retry generic network errors
        }
    }
}