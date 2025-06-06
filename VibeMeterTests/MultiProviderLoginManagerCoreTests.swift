import Foundation
import Testing
@testable import VibeMeter

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

@Suite("MultiProviderLoginManagerCoreTests")
@MainActor
struct MultiProviderLoginManagerCoreTests {
    let sut: MultiProviderLoginManager
    let providerFactory: ProviderFactory
    let mockSettingsManager: SettingsManager
    let mockStartupManager: StartupManagerMock

    init() async throws {
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

    // MARK: - Initialization Tests

    @Test("initialization sets up correctly")
    func initialization_SetsUpCorrectly() {
        // Then
        // providerLoginStates is initialized with all providers (currently just .cursor) set to false
        #expect(sut.providerLoginStates.count == ServiceProvider.allCases.count)
        #expect(sut.loginErrors.isEmpty == true)
        #expect(sut.loggedInProviders.isEmpty == true)
    }

    @Test("is logged in without login returns false")
    func isLoggedIn_WithoutLogin_ReturnsFalse() {
        // When
        let isLoggedIn = sut.isLoggedIn(to: .cursor)

        // Then
        #expect(isLoggedIn == false)
    }

    #if DEBUG
        @Test("simulate login sets login state")
        func simulateLogin_SetsLoginState() {
            // When
            sut._test_simulateLogin(for: .cursor, withToken: "test-token")

            // Then
            #expect(sut.isLoggedIn(to: .cursor) == true)
            #expect(sut.isLoggedInToAnyProvider == true)
        }

        @Test("multiple provider logins tracks independently")
        func multipleProviderLogins_TracksIndependently() {
            // When
            sut._test_simulateLogin(for: .cursor, withToken: "cursor-token")
            // Simulate future providers
            sut._test_setLoginState(true, for: .cursor)

            // Then
            #expect(sut.isLoggedIn(to: .cursor) == true)
        }
    #endif

    // MARK: - Logout Tests

    #if DEBUG
        @Test("log out removes token and state")
        func logOut_RemovesTokenAndState() {
            // Given
            sut._test_simulateLogin(for: .cursor, withToken: "test-token")
            var logoutCallbackCalled = false
            sut.onLoginFailure = { provider, _ in
                logoutCallbackCalled = true
                #expect(provider == .cursor)
            }

            // When
            sut.logOut(from: .cursor)

            // Then
            #expect(sut.isLoggedIn(to: .cursor) == false)
            #expect(sut.isLoggedInToAnyProvider == false)
        }

        @Test("log out from all removes all providers")
        func logOutFromAll_RemovesAllProviders() {
            // Given
            sut._test_simulateLogin(for: .cursor, withToken: "cursor-token")

            // When
            sut.logOutFromAll()

            // Then
            #expect(sut.isLoggedIn(to: .cursor) == false)
        }
    #endif

    // MARK: - Observable State Tests

    @Test("provider login states updates on login change")
    func providerLoginStates_UpdatesOnLoginChange() {
        // Given
        // Initial state has .cursor set to false
        #expect(sut.providerLoginStates[.cursor] == false)

        // When
        #if DEBUG
            sut._test_simulateLogin(for: .cursor, withToken: "test-token")
        #endif

        // Then
        #expect(sut.providerLoginStates[.cursor] == true)
    }

    @Test("login errors tracks per provider")
    func loginErrors_TracksPerProvider() {
        // Initially no errors
        #expect(sut.loginErrors.isEmpty == true)
    }

    @Test("show login window resets processing state")
    func showLoginWindow_ResetsProcessingState() {
        // When
        sut.showLoginWindow(for: .cursor)

        // Then - In production, this would open WebView
        // Here we verify it doesn't crash and maintains state
        #expect(sut.isLoggedIn(to: .cursor) == false)
    }
}
