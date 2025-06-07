import Foundation
import Testing
@testable import VibeMeter

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
                initialDelay: 0.01,  // 10ms instead of 1s
                maxDelay: 0.1,       // 100ms instead of 30s
                multiplier: 2.0,
                jitterFactor: 0.1
            )
            let defaultHandler = NetworkRetryHandler(configuration: testConfig)

            // Then - verify through behavior
            let startTime = Date()
            var attemptCount = 0

            #expect(throws: Error.self) {
                try await defaultHandler.execute {
                    attemptCount += 1
                    throw NetworkRetryHandler.RetryableError.networkTimeout
                }
            }
            
            // Config has maxRetries = 3, so 4 attempts total
            #expect(attemptCount == 4)
            let elapsed = Date().timeIntervalSince(startTime)
            #expect(elapsed < 1.0) // Should complete quickly with test delays
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
            #expect(throws: Error.self) {
                try await aggressiveHandler.execute {
                    attemptCount += 1
                    throw NetworkRetryHandler.RetryableError.serverError(statusCode: 503)
                }
            }
            
            // Then
            // Aggressive config has maxRetries = 5, so 6 attempts total
            #expect(attemptCount == 6)
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
            } catch {
                // Expected - should retry and then fail
            }
            
            // Then
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
            var delays: [TimeInterval] = []
            var startTimes: [Date] = []

            // When
            do {
                _ = try await handler.execute {
                    let now = Date()
                    startTimes.append(now)
                    if startTimes.count > 1 {
                        delays.append(now.timeIntervalSince(startTimes[startTimes.count - 2]))
                    }
                    throw NetworkRetryHandler.RetryableError.connectionError
                }
            } catch {
                // Expected to fail
            }

            // Then - Verify exponential backoff
            // Delays should be approximately: 0.1, 0.2, 0.4
            // Can't test exact values due to async timing, but verify increasing pattern
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
                initialDelay: 0.01,   // 10ms instead of 1s
                maxDelay: 0.02,       // 20ms instead of 2s
                multiplier: 10.0,     // High multiplier
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
                // Should be capped at maxDelay * maxRetries = 0.02 * 5 = 0.1
                #expect(totalTime < 0.2) // Allow some margin
                #expect(attemptCount == 6) // 1 initial + 5 retries
            }
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
            initialDelay: 0.001,  // 1ms instead of 1s
            maxDelay: 0.01,       // 10ms instead of 30s
            multiplier: 2.0,
            jitterFactor: 0.1
        )

        init() {
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
            } catch {
                // Expected - should retry and then fail
            }
            
            // Then - Should retry maxRetries times
            #expect(attemptCount == 4) // 1 initial + 3 retries
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
            } catch {
                // Expected - should retry and then fail
            }
            
            // Then
            #expect(attemptCount == 4) // 1 initial + 3 retries
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
            } catch {
                // Expected - client errors should not retry
            }
            
            // Then - Client errors (4xx) should not retry
            #expect(attemptCount == 1)
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
            } catch {
                // Expected - should retry and then fail
            }
            
            // Then
            #expect(attemptCount == 3) // 1 initial + 2 retries
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
            } catch {
                // Expected - should retry and then fail
            }
            
            // Then
            #expect(attemptCount == 4) // 1 initial + 3 retries
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
            } catch {
                // Expected - should retry and then fail
            }
            
            // Then
            #expect(attemptCount == 4) // 1 initial + 3 retries
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
            } catch {
                // Expected - should not retry bad URL errors
            }
            
            // Then
            #expect(attemptCount == 1) // No retries for non-retryable errors
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
            } catch {
                // Expected - should retry based on custom logic and then fail
            }
            
            // Then
            #expect(attemptCount == 4) // Should retry based on custom logic
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
            } catch {
                // Expected - should not retry due to custom logic
            }
            
            // Then
            #expect(attemptCount == 1) // No retries due to custom logic
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
            } catch {
                // Expected - should retry and then fail
                #expect(error is URLError)
            }
            
            // Then
            #expect(attemptCount == 4) // Should retry network timeouts
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
            } catch {
                // Expected - should retry and then fail
            }
            
            // Then
            #expect(attemptCount == 4) // Should retry connection errors
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
            } catch {
                // Expected - should retry and then fail
            }
            
            // Then
            #expect(attemptCount == 4) // Should retry connection errors
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
            } catch {
                // Expected - should retry and then fail
            }
            
            // Then
            #expect(attemptCount == 4) // Should retry DNS errors
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
            } catch {
                // Expected - should retry and then fail
            }
            
            // Then
            #expect(attemptCount == 4) // Should retry connection errors
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
            } catch {
                // Expected - should not retry bad server response
            }
            
            // Then
            #expect(attemptCount == 1) // badServerResponse is not retryable
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
            } catch {
                // Expected - should not retry zero byte resource error
            }
            
            // Then
            #expect(attemptCount == 1) // zeroByteResource is not retryable
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
            } catch {
                // Expected - should not retry decode error
            }
            
            // Then
            #expect(attemptCount == 1) // cannotDecodeRawData is not retryable
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
            } catch {
                // Expected - should not retry content decode error
            }
            
            // Then
            #expect(attemptCount == 1) // cannotDecodeContentData is not retryable
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
            } catch {
                // Expected - should not retry parse error
            }
            
            // Then
            #expect(attemptCount == 1) // cannotParseResponse is not retryable
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
            } catch {
                // Expected - should not retry security error
            }
            
            // Then
            #expect(attemptCount == 1) // secureConnectionFailed is not retryable
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
            } catch {
                // Expected - should not retry certificate error
            }
            
            // Then
            #expect(attemptCount == 1) // Should not retry certificate errors
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
            } catch {
                // Expected - should retry and then fail
            }
            
            // Then
            #expect(attemptCount == 4) // Should retry 503 errors
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
            } catch {
                // Expected - should retry and then fail
            }
            
            // Then
            #expect(attemptCount == 4) // Should retry gateway timeouts
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
            } catch {
                // Expected - should not retry decoding error
            }
            
            // Then
            #expect(attemptCount == 1) // Should not retry generic decoding errors
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
            } catch {
                // Expected - should retry and then fail
            }
            
            // Then
            #expect(attemptCount == 4) // Should retry generic network errors
        }
    }
}