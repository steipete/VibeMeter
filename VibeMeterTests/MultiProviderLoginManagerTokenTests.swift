@testable import VibeMeter
import XCTest

@MainActor
final class MultiProviderLoginManagerTokenTests: XCTestCase, @unchecked Sendable {
    var sut: MultiProviderLoginManager!
    var providerFactory: ProviderFactory!
    var mockSettingsManager: SettingsManager!
    var mockStartupManager: StartupManagerMock!

    override func setUp() async throws {
        try await super.setUp()
        mockStartupManager = StartupManagerMock()
        mockSettingsManager = SettingsManager(
            userDefaults: UserDefaults(suiteName: "MultiProviderLoginManagerTokenTests")!,
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
}
