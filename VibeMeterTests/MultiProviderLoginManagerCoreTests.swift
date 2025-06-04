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
final class MultiProviderLoginManagerCoreTests: XCTestCase, @unchecked Sendable {
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
}
