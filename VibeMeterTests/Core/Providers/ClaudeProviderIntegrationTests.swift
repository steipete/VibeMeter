import XCTest
@testable import VibeMeter

@MainActor
final class ClaudeProviderIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    private lazy var mockSettingsManager = MockSettingsManager()
    private lazy var mockLogManager = ClaudeLogManagerMock()
    private lazy var provider = ClaudeProvider(
        settingsManager: mockSettingsManager,
        logManager: mockLogManager
    )
    
    // MARK: - User Info Tests
    
    func testFetchUserInfoWithAccess() async throws {
        // Given
        mockLogManager.setHasAccess(true)
        
        // When
        let userInfo = try await provider.fetchUserInfo(authToken: "dummy")
        
        // Then
        XCTAssertEqual(userInfo.provider, .claude)
        XCTAssertEqual(userInfo.email, NSUserName())
    }
    
    func testFetchUserInfoWithoutAccess() async {
        // Given
        mockLogManager.setHasAccess(false)
        
        // When/Then
        do {
            _ = try await provider.fetchUserInfo(authToken: "dummy")
            XCTFail("Should throw authentication error")
        } catch {
            if case let ProviderError.authenticationFailed(reason) = error {
                XCTAssertEqual(reason, "No folder access")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
    
    // MARK: - Usage Data Tests
    
    func testFetchUsageDataWithLowUsage() async throws {
        // Given
        mockLogManager.setHasAccess(true)
        mockLogManager.calculateFiveHourWindowResult = FiveHourWindow(
            used: 10.0,
            total: 100.0,
            resetDate: Date().addingTimeInterval(5 * 60 * 60),
            tokensUsed: 50_000,
            estimatedTokenLimit: 500_000
        )
        
        // When
        let usageData = try await provider.fetchUsageData(authToken: "dummy")
        
        // Then
        XCTAssertEqual(usageData.provider, .claude)
        XCTAssertEqual(usageData.currentRequests, 10) // Percentage
        XCTAssertEqual(usageData.totalRequests, 50_000) // Actual tokens
        XCTAssertEqual(usageData.maxRequests, 100) // Max percentage
    }
    
    func testFetchUsageDataWithHighUsage() async throws {
        // Given
        mockLogManager.setHasAccess(true)
        mockLogManager.calculateFiveHourWindowResult = FiveHourWindow(
            used: 85.5,
            total: 100.0,
            resetDate: Date().addingTimeInterval(5 * 60 * 60),
            tokensUsed: 427_500,
            estimatedTokenLimit: 500_000
        )
        
        // When
        let usageData = try await provider.fetchUsageData(authToken: "dummy")
        
        // Then
        XCTAssertEqual(usageData.currentRequests, 85) // Rounded percentage
        XCTAssertEqual(usageData.totalRequests, 427_500) // Actual tokens
    }
    
    func testFetchUsageDataWithNoUsage() async throws {
        // Given
        mockLogManager.setHasAccess(true)
        mockLogManager.calculateFiveHourWindowResult = FiveHourWindow(
            used: 0.0,
            total: 100.0,
            resetDate: Date().addingTimeInterval(5 * 60 * 60),
            tokensUsed: 0,
            estimatedTokenLimit: 500_000
        )
        
        // When
        let usageData = try await provider.fetchUsageData(authToken: "dummy")
        
        // Then
        XCTAssertEqual(usageData.currentRequests, 0)
        XCTAssertEqual(usageData.totalRequests, 0)
    }
    
    // MARK: - Monthly Invoice Tests
    
    func testFetchMonthlyInvoiceWithData() async throws {
        // Given
        mockLogManager.setHasAccess(true)
        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now) - 1 // 0-indexed
        let year = calendar.component(.year, from: now)
        
        // Create test entries
        let entries = [
            ClaudeLogEntry(
                timestamp: now.addingTimeInterval(-24 * 60 * 60), // Yesterday
                model: "claude-3-5-sonnet-latest",
                inputTokens: 10_000,
                outputTokens: 5_000
            ),
            ClaudeLogEntry(
                timestamp: now.addingTimeInterval(-48 * 60 * 60), // 2 days ago
                model: "claude-3-5-sonnet-latest",
                inputTokens: 20_000,
                outputTokens: 10_000
            )
        ]
        
        mockLogManager.setDailyUsage([
            calendar.startOfDay(for: now.addingTimeInterval(-24 * 60 * 60)): [entries[0]],
            calendar.startOfDay(for: now.addingTimeInterval(-48 * 60 * 60)): [entries[1]]
        ])
        
        // When
        let invoice = try await provider.fetchMonthlyInvoice(
            authToken: "dummy",
            month: month,
            year: year,
            teamId: nil
        )
        
        // Then
        XCTAssertEqual(invoice.provider, .claude)
        XCTAssertEqual(invoice.month, month)
        XCTAssertEqual(invoice.year, year)
        XCTAssertGreaterThan(invoice.items.count, 0)
        XCTAssertNotNil(invoice.pricingDescription)
        
        // Verify pricing description contains token counts
        let description = invoice.pricingDescription?.description ?? ""
        XCTAssertTrue(description.contains("input"))
        XCTAssertTrue(description.contains("output"))
    }
    
    func testFetchMonthlyInvoiceWithNoData() async throws {
        // Given
        mockLogManager.setHasAccess(true)
        mockLogManager.setDailyUsage([:])
        
        let now = Date()
        let calendar = Calendar.current
        let month = calendar.component(.month, from: now) - 1
        let year = calendar.component(.year, from: now)
        
        // When
        let invoice = try await provider.fetchMonthlyInvoice(
            authToken: "dummy",
            month: month,
            year: year,
            teamId: nil
        )
        
        // Then
        XCTAssertEqual(invoice.items.count, 0)
        XCTAssertEqual(invoice.pricingDescription?.description, "0 input ($0), 0 output ($0)")
    }
    
    // MARK: - Token Validation Tests
    
    func testValidateTokenWithAccess() async {
        // Given
        mockLogManager.setHasAccess(true)
        
        // When
        let isValid = await provider.validateToken(authToken: "dummy")
        
        // Then
        XCTAssertTrue(isValid)
    }
    
    func testValidateTokenWithoutAccess() async {
        // Given
        mockLogManager.setHasAccess(false)
        
        // When
        let isValid = await provider.validateToken(authToken: "dummy")
        
        // Then
        XCTAssertFalse(isValid)
    }
    
    // MARK: - File Access Tests
    
    func testRequestFileAccess() async {
        // Given
        mockLogManager.setHasAccess(false)
        mockLogManager.requestLogAccessResult = true
        
        // When
        let granted = await provider.requestFileAccess()
        
        // Then
        XCTAssertTrue(granted)
        XCTAssertTrue(mockLogManager.callCount(for: "requestLogAccess") > 0)
    }
    
    func testHasFileAccess() async {
        // Given
        mockLogManager.setHasAccess(true)
        
        // When
        let hasAccess = await provider.hasFileAccess()
        
        // Then
        XCTAssertTrue(hasAccess)
    }
    
    // MARK: - Performance Tests
    
    func testFetchUsageDataPerformance() async throws {
        // Given
        mockLogManager.setHasAccess(true)
        mockLogManager.calculateFiveHourWindowResult = FiveHourWindow(
            used: 50.0,
            total: 100.0,
            resetDate: Date().addingTimeInterval(5 * 60 * 60),
            tokensUsed: 250_000,
            estimatedTokenLimit: 500_000
        )
        
        // Measure performance
        let start = Date()
        _ = try await provider.fetchUsageData(authToken: "dummy")
        let elapsed = Date().timeIntervalSince(start)
        
        // Should be very fast since we're using cached data
        XCTAssertLessThan(elapsed, 0.1)
    }
}

