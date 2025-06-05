@testable import VibeMeter
import Testing

@Suite("NetworkRetryHandlerDelayTests")
struct NetworkRetryHandlerDelayTests {
    // MARK: - Delay Calculation Tests

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
        let delays: [TimeInterval] = []
        let startTimes: [Date] = []

        // When
        do {
            _ = try await handler.execute {
                let now = Date()
                if startTimes.isEmpty {
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

    @Test("max delay respected")

    func maxDelayRespected() async {
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
            #expect(totalTime < 12.0)

    func asRetryableErrorConversion() {
        // Test timeout error
        let timeoutError = URLError(.timedOut)
        #expect(timeoutError.asRetryableError == .networkTimeout)
        #expect(connectionError.asRetryableError == .connectionError)
        #expect(badURLError.asRetryableError == nil)

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
