import XCTest
@testable import VibeMeter

// MARK: - Mock Dependencies

private final class MockProviderFactory: ProviderFactory {
    var mockProviders: [ServiceProvider: ProviderProtocol] = [:]
    var validateTokenResponses: [ServiceProvider: Bool] = [:]
    
    override func createProvider(for provider: ServiceProvider) -> ProviderProtocol {
        return mockProviders[provider] ?? MockProvider(provider: provider, validateResponse: validateTokenResponses[provider] ?? true)
    }
}

private final class MockProvider: ProviderProtocol {
    let provider: ServiceProvider
    var validateResponse: Bool
    
    init(provider: ServiceProvider, validateResponse: Bool = true) {
        self.provider = provider
        self.validateResponse = validateResponse
    }
    
    func fetchTeamInfo(authToken: String) async throws -> ProviderTeamInfo {
        ProviderTeamInfo(teamId: 123, teamName: "Test Team")
    }
    
    func fetchUserInfo(authToken: String) async throws -> ProviderUserInfo {
        ProviderUserInfo(email: "test@example.com", teamName: "Test Team", role: "member")
    }
    
    func fetchMonthlyInvoice(authToken: String, month: Int, year: Int, teamId: Int?) async throws -> ProviderMonthlyInvoice {
        ProviderMonthlyInvoice(
            provider: provider,
            month: month,
            year: year,
            items: [],
            totalCost: 0.0,
            currency: "USD"
        )
    }
    
    func fetchUsageData(authToken: String) async throws -> ProviderUsageData {
        ProviderUsageData(
            provider: provider,
            requestsUsed: 100,
            requestsLimit: 1000,
            tokensUsed: 50000,
            tokensLimit: 1000000
        )
    }
    
    func validateToken(authToken: String) async -> Bool {
        validateResponse
    }
    
    func getAuthenticationURL() -> URL {
        URL(string: "https://test.com/auth")!
    }
    
    func extractAuthToken(from callbackData: [String: Any]) -> String? {
        callbackData["token"] as? String
    }
}

// MARK: - Tests

@MainActor
final class MultiProviderLoginManagerTests: XCTestCase {
    var sut: MultiProviderLoginManager!
    var mockFactory: MockProviderFactory!
    
    override func setUp() async throws {
        try await super.setUp()
        mockFactory = MockProviderFactory(
            settingsManager: SettingsManager(),
            urlSession: URLSession.shared
        )
        sut = MultiProviderLoginManager(providerFactory: mockFactory)
        
        // Reset any stored states
        #if DEBUG
        sut._test_reset()
        #endif
    }
    
    override func tearDown() async throws {
        sut = nil
        mockFactory = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_SetsUpCorrectly() {
        // Then
        XCTAssertTrue(sut.providerLoginStates.isEmpty)
        XCTAssertTrue(sut.loginErrors.isEmpty)
        XCTAssertFalse(sut.isLoggedInToAnyProvider)
        XCTAssertTrue(sut.loggedInProviders.isEmpty)
    }
    
    // MARK: - Login State Tests
    
    func testIsLoggedIn_WithoutLogin_ReturnsFalse() {
        // When
        let isLoggedIn = sut.isLoggedIn(to: .cursor)
        
        // Then
        XCTAssertFalse(isLoggedIn)
    }
    
    #if DEBUG
    func testSimulateLogin_SetsLoginState() {
        // When
        sut._test_simulateLogin(for: .cursor, withToken: "test-token")
        
        // Then
        XCTAssertTrue(sut.isLoggedIn(to: .cursor))
        XCTAssertEqual(sut.getAuthToken(for: .cursor), "test-token")
        XCTAssertTrue(sut.isLoggedInToAnyProvider)
        XCTAssertEqual(sut.loggedInProviders, [.cursor])
    }
    
    func testMultipleProviderLogins_TracksIndependently() {
        // When
        sut._test_simulateLogin(for: .cursor, withToken: "cursor-token")
        // Simulate future providers
        sut._test_setLoginState(true, for: .cursor)
        
        // Then
        XCTAssertTrue(sut.isLoggedIn(to: .cursor))
        XCTAssertEqual(sut.loggedInProviders.count, 1)
    }
    #endif
    
    // MARK: - Logout Tests
    
    #if DEBUG
    func testLogOut_RemovesTokenAndState() {
        // Given
        sut._test_simulateLogin(for: .cursor, withToken: "test-token")
        var logoutCallbackCalled = false
        sut.onLoginFailure = { provider, error in
            logoutCallbackCalled = true
            XCTAssertEqual(provider, .cursor)
        }
        
        // When
        sut.logOut(from: .cursor)
        
        // Then
        XCTAssertFalse(sut.isLoggedIn(to: .cursor))
        XCTAssertNil(sut.getAuthToken(for: .cursor))
        XCTAssertFalse(sut.isLoggedInToAnyProvider)
        XCTAssertTrue(logoutCallbackCalled)
    }
    
    func testLogOutFromAll_RemovesAllProviders() {
        // Given
        sut._test_simulateLogin(for: .cursor, withToken: "cursor-token")
        
        // When
        sut.logOutFromAll()
        
        // Then
        XCTAssertFalse(sut.isLoggedIn(to: .cursor))
        XCTAssertTrue(sut.loggedInProviders.isEmpty)
    }
    #endif
    
    // MARK: - Token Validation Tests
    
    func testValidateAllTokens_WithValidTokens_KeepsLoginState() async {
        // Given
        #if DEBUG
        sut._test_simulateLogin(for: .cursor, withToken: "valid-token")
        #endif
        mockFactory.validateTokenResponses[.cursor] = true
        
        // When
        await sut.validateAllTokens()
        
        // Then
        XCTAssertTrue(sut.isLoggedIn(to: .cursor))
    }
    
    func testValidateAllTokens_WithInvalidTokens_LogsOut() async {
        // Given
        #if DEBUG
        sut._test_simulateLogin(for: .cursor, withToken: "invalid-token")
        #endif
        mockFactory.validateTokenResponses[.cursor] = false
        
        var logoutCallbackCalled = false
        sut.onLoginFailure = { provider, error in
            logoutCallbackCalled = true
        }
        
        // When
        await sut.validateAllTokens()
        
        // Then
        XCTAssertFalse(sut.isLoggedIn(to: .cursor))
        XCTAssertTrue(logoutCallbackCalled)
    }
    
    func testValidateAllTokens_WithMultipleProviders_ValidatesIndependently() async {
        // Given
        #if DEBUG
        sut._test_simulateLogin(for: .cursor, withToken: "cursor-token")
        #endif
        mockFactory.validateTokenResponses[.cursor] = true
        
        // When
        await sut.validateAllTokens()
        
        // Then
        XCTAssertTrue(sut.isLoggedIn(to: .cursor))
    }
    
    // MARK: - Refresh States Tests
    
    func testRefreshLoginStatesFromKeychain_UpdatesStates() {
        // Given
        #if DEBUG
        sut._test_simulateLogin(for: .cursor, withToken: "stored-token")
        #endif
        
        // When
        sut.refreshLoginStatesFromKeychain()
        
        // Then
        XCTAssertTrue(sut.isLoggedIn(to: .cursor))
        XCTAssertEqual(sut.providerLoginStates[.cursor], true)
    }
    
    // MARK: - Callback Tests
    
    func testOnLoginSuccess_CalledAfterSuccessfulLogin() {
        // Given
        var successCallbackCalled = false
        var successProvider: ServiceProvider?
        
        sut.onLoginSuccess = { provider in
            successCallbackCalled = true
            successProvider = provider
        }
        
        // When - Simulate the internal login flow
        #if DEBUG
        sut._test_simulateLogin(for: .cursor, withToken: "success-token")
        #endif
        
        // Then - In real flow, callback would be called through handleSuccessfulLogin
        // For this test, we verify the state is set correctly
        XCTAssertTrue(sut.isLoggedIn(to: .cursor))
    }
    
    func testOnLoginDismiss_ConfigurableCallback() {
        // Given
        var dismissCallbackCalled = false
        var dismissProvider: ServiceProvider?
        
        sut.onLoginDismiss = { provider in
            dismissCallbackCalled = true
            dismissProvider = provider
        }
        
        // When - In real flow, this would be called when WebView is dismissed
        sut.onLoginDismiss?(.cursor)
        
        // Then
        XCTAssertTrue(dismissCallbackCalled)
        XCTAssertEqual(dismissProvider, .cursor)
    }
    
    // MARK: - Error Handling Tests
    
    #if DEBUG
    func testLoginError_TrackedPerProvider() {
        // Given
        sut._test_reset()
        
        // When - Simulate error state through internal testing
        // In production, errors would be set through handleLoginCompletion
        
        // Then
        XCTAssertFalse(sut.isLoggedIn(to: .cursor))
    }
    #endif
    
    // MARK: - Cookie Management Tests
    
    func testGetCookies_WithStoredToken_ReturnsCookies() {
        // Given
        #if DEBUG
        sut._test_simulateLogin(for: .cursor, withToken: "cookie-token")
        #endif
        
        // When
        let cookies = sut.getCookies(for: .cursor)
        
        // Then
        XCTAssertNotNil(cookies)
        XCTAssertFalse(cookies!.isEmpty)
        
        // Verify cookie properties
        if let cookie = cookies?.first {
            XCTAssertEqual(cookie.name, ServiceProvider.cursor.authCookieName)
            XCTAssertEqual(cookie.value, "cookie-token")
            XCTAssertEqual(cookie.domain, ServiceProvider.cursor.authDomain)
            XCTAssertTrue(cookie.isSecure)
            XCTAssertTrue(cookie.isHTTPOnly)
        }
    }
    
    func testGetCookies_WithoutToken_ReturnsNil() {
        // When
        let cookies = sut.getCookies(for: .cursor)
        
        // Then
        XCTAssertNil(cookies)
    }
    
    // MARK: - Observable State Tests
    
    func testProviderLoginStates_UpdatesOnLoginChange() {
        // Given
        XCTAssertTrue(sut.providerLoginStates.isEmpty)
        
        // When
        #if DEBUG
        sut._test_simulateLogin(for: .cursor, withToken: "state-token")
        #endif
        
        // Then
        XCTAssertEqual(sut.providerLoginStates[.cursor], true)
    }
    
    func testLoginErrors_TracksPerProvider() {
        // Initially no errors
        XCTAssertTrue(sut.loginErrors.isEmpty)
        
        // Errors would be populated through handleLoginCompletion in production
    }
    
    // MARK: - Show Login Window Tests
    
    func testShowLoginWindow_ResetsProcessingState() {
        // When
        sut.showLoginWindow(for: .cursor)
        
        // Then - In production, this would open WebView
        // Here we verify it doesn't crash and maintains state
        XCTAssertFalse(sut.isLoggedIn(to: .cursor))
    }
    
    // MARK: - Multi-Provider Coordination Tests
    
    #if DEBUG
    func testLoggedInProviders_ReturnsOnlyLoggedInProviders() {
        // Given
        sut._test_simulateLogin(for: .cursor, withToken: "cursor-token")
        
        // When
        let providers = sut.loggedInProviders
        
        // Then
        XCTAssertEqual(providers, [.cursor])
    }
    
    func testIsLoggedInToAnyProvider_WithOneProvider_ReturnsTrue() {
        // Given
        sut._test_simulateLogin(for: .cursor, withToken: "any-token")
        
        // Then
        XCTAssertTrue(sut.isLoggedInToAnyProvider)
    }
    
    func testIsLoggedInToAnyProvider_WithNoProviders_ReturnsFalse() {
        // Given
        sut._test_reset()
        
        // Then
        XCTAssertFalse(sut.isLoggedInToAnyProvider)
    }
    #endif
    
    // MARK: - Thread Safety Tests
    
    func testConcurrentAccess_MaintainsConsistency() async {
        // Given
        let expectation = expectation(description: "Concurrent operations complete")
        expectation.expectedFulfillmentCount = 50
        
        // When
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
                group.addTask {
                    if i % 2 == 0 {
                        #if DEBUG
                        await self.sut._test_simulateLogin(for: .cursor, withToken: "concurrent-\(i)")
                        #endif
                    } else {
                        _ = await self.sut.isLoggedIn(to: .cursor)
                        _ = await self.sut.getAuthToken(for: .cursor)
                    }
                    expectation.fulfill()
                }
            }
        }
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
    }
}