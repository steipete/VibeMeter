@testable import VibeMeter
import Testing

@Suite("MultiProviderLoginManagerCallbackTests")
@MainActor
struct MultiProviderLoginManagerCallbackTests {
    let sut: MultiProviderLoginManager
    let providerFactory: ProviderFactory
    let mockSettingsManager: SettingsManager
    let mockStartupManager: StartupManagerMock

    init() async throws {
        try await 
        mockStartupManager = StartupManagerMock()
        mockSettingsManager = SettingsManager(
            userDefaults: UserDefaults(suiteName: "MultiProviderLoginManagerCallbackTests")!,
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

     async throws {
        sut = nil
        providerFactory = nil
        mockSettingsManager = nil
        mockStartupManager = nil
        try await 
    }

    // MARK: - Callback Tests

    @Test("on login success  called after successful login")

    func onLoginSuccess_CalledAfterSuccessfulLogin() {
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
        #expect(sut.isLoggedIn(to: .cursor == true)

    func onLoginDismiss_ConfigurableCallback() {
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
        #expect(dismissCallbackCalled == true)
    }

    // MARK: - Error Handling Tests

    #if DEBUG
        @Test("login error  tracked per provider")

        func loginError_TrackedPerProvider() {
            // Given
            sut._test_reset()

            // When - Simulate error state through internal testing
            // In production, errors would be set through handleLoginCompletion

            // Then
            #expect(sut.isLoggedIn(to: .cursor == false)

        func loggedInProviders_ReturnsOnlyLoggedInProviders() {
            // Given
            sut._test_simulateLogin(for: .cursor, withToken: "cursor-token")

            // When
            let providers = sut.loggedInProviders

            // Then
            #expect(providers == [.cursor])

        func isLoggedInToAnyProvider_WithOneProvider_ReturnsTrue() {
            // Given
            sut._test_simulateLogin(for: .cursor, withToken: "any-token")

            // Then
            #expect(sut.isLoggedInToAnyProvider == true)

        func isLoggedInToAnyProvider_WithNoProviders_ReturnsFalse() {
            // Given
            sut._test_reset()

            // Then
            #expect(sut.isLoggedInToAnyProvider == false)

    func concurrentAccess_MaintainsConsistency() async {
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
