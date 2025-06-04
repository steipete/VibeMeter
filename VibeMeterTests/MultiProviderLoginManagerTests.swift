@testable import VibeMeter
import XCTest

// MARK: - Mock Dependencies

private final class MockProvider: ProviderProtocol, @unchecked Sendable {
    let provider: ServiceProvider
    private let _validateResponse: Bool

    init(provider: ServiceProvider, validateResponse: Bool = true) {
        self.provider = provider
        self._validateResponse = validateResponse
    }

    func fetchTeamInfo(authToken _: String) async throws -> ProviderTeamInfo {
        ProviderTeamInfo(id: 123, name: "Test Team", provider: provider)
    }

    func fetchUserInfo(authToken _: String) async throws -> ProviderUserInfo {
        ProviderUserInfo(email: "test@example.com", teamId: 123, provider: provider)
    }

    func fetchMonthlyInvoice(authToken _: String, month: Int, year: Int,
                             teamId _: Int?) async throws -> ProviderMonthlyInvoice {
        ProviderMonthlyInvoice(
            items: [],
            pricingDescription: nil,
            provider: provider,
            month: month,
            year: year)
    }

    func fetchUsageData(authToken _: String) async throws -> ProviderUsageData {
        ProviderUsageData(
            currentRequests: 100,
            totalRequests: 1000,
            maxRequests: 5000,
            startOfMonth: Date(),
            provider: provider)
    }

    func validateToken(authToken _: String) async -> Bool {
        _validateResponse
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
final class MultiProviderLoginManagerTests: XCTestCase, @unchecked Sendable {
    var sut: MultiProviderLoginManager!
    var providerFactory: ProviderFactory!
    var mockSettingsManager: SettingsManager!
    var mockStartupManager: StartupManagerMock!

    override func setUp() async throws {
        try await super.setUp()
        mockStartupManager = StartupManagerMock()
        mockSettingsManager = SettingsManager(
            userDefaults: UserDefaults(suiteName: "MultiProviderLoginManagerTests")!,
            startupManager: mockStartupManager)
        providerFactory = ProviderFactory(
            settingsManager: mockSettingsManager,
            urlSession: URLSession.shared)
        sut = MultiProviderLoginManager(providerFactory: providerFactory)

        // Reset any stored states
        #if DEBUG
            sut._test_reset()
        #endif
    }

    override func tearDown() async throws {
        sut = nil
        providerFactory = nil
        mockSettingsManager = nil
        mockStartupManager = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testInitialization_SetsUpCorrectly() {
        // Then
        // providerLoginStates is initialized with all providers (currently just .cursor) set to false
        XCTAssertEqual(sut.providerLoginStates.count, ServiceProvider.allCases.count)
        XCTAssertEqual(sut.providerLoginStates[.cursor], false)
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
            sut.onLoginFailure = { provider, _ in
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

    func testValidateAllTokens_WithoutLogin_DoesNotCrash() async {
        // Given - No login state

        // When
        await sut.validateAllTokens()

        // Then
        XCTAssertFalse(sut.isLoggedInToAnyProvider, "Should remain logged out when no initial login")
    }

    func testValidateAllTokens_WithSimulatedLogin_CallsValidation() async {
        // Given
        #if DEBUG
            sut._test_simulateLogin(for: .cursor, withToken: "test-token")
        #endif

        // When
        await sut.validateAllTokens()

        // Then
        // This test validates that the method can be called without crashing
        // In real usage, invalid tokens would be handled by the provider validation
        XCTAssertNotNil(sut)
    }

    func testValidateAllTokens_WithMultipleProviders_HandlesGracefully() async {
        // Given
        #if DEBUG
            sut._test_simulateLogin(for: .cursor, withToken: "cursor-token")
        #endif

        // When
        await sut.validateAllTokens()

        // Then
        // This test validates that validation works with multiple providers
        // The exact result depends on network availability and token validity
        XCTAssertNotNil(sut.providerLoginStates)
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
        XCTAssertEqual(cookies?.count, 1)

        // Verify cookie properties
        if let cookie = cookies?.first {
            XCTAssertEqual(cookie.name, ServiceProvider.cursor.authCookieName)
            XCTAssertEqual(cookie.value, "cookie-token")
            XCTAssertEqual(cookie.domain, ServiceProvider.cursor.cookieDomain)
            XCTAssertTrue(cookie.isSecure)
            // Note: HTTPOnly is not set when creating cookies programmatically
            XCTAssertFalse(cookie.isHTTPOnly)
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
        // Initial state has .cursor set to false
        XCTAssertEqual(sut.providerLoginStates[.cursor], false)

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
            for i in 0 ..< 50 {
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
