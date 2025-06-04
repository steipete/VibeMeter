@testable import VibeMeter
import XCTest

final class NetworkRetryHandlerConfigurationTests: XCTestCase {
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
}