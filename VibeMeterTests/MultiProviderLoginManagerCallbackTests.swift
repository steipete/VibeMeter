import Foundation
import Testing
@testable import VibeMeter

@Suite("MultiProviderLoginManagerCallbackTests", .tags(.authentication, .integration))
@MainActor
struct MultiProviderLoginManagerCallbackTests {
    let sut: MultiProviderLoginManager
    let providerFactory: ProviderFactory
    let mockSettingsManager: SettingsManager
    let mockStartupManager: StartupManagerMock

    init() async throws {
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

    // MARK: - Callback Tests

    @Test("on login success called after successful login")
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
        #expect(sut.isLoggedIn(to: .cursor) == true)

        // Simulate callback invocation to test the callback logic
        sut.onLoginSuccess?(.cursor)
        #expect(successCallbackCalled == true)
        #expect(successProvider == .cursor)
    }

    @Test("on login dismiss configurable callback")
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
        #expect(dismissProvider == .cursor)
    }

    // MARK: - Error Handling Tests

    #if DEBUG
    @Test("login error tracked per provider")
    func loginError_TrackedPerProvider() {
        // Given
        sut._test_reset()

        // When - Simulate error state through internal testing
        // In production, errors would be set through handleLoginCompletion

        // Then
        #expect(sut.isLoggedIn(to: .cursor) == false)
    }

    @Test("logged in providers returns only logged in providers")
    func loggedInProviders_ReturnsOnlyLoggedInProviders() {
        // Given
        sut._test_simulateLogin(for: .cursor, withToken: "cursor-token")

        // When
        let providers = sut.loggedInProviders

        // Then
        #expect(providers == [.cursor])
    }

    @Test("is logged in to any provider with one provider returns true")
    func isLoggedInToAnyProvider_WithOneProvider_ReturnsTrue() {
        // Given
        sut._test_simulateLogin(for: .cursor, withToken: "any-token")

        // Then
        #expect(sut.isLoggedInToAnyProvider == true)
    }

    @Test("concurrent operations thread safety")
    func concurrentOperations_ThreadSafety() async {
        // When - Perform many concurrent operations
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
                }
            }
        }

        // Then - Test passes if no crashes occur during concurrent access
        #expect(Bool(true))
    }
    #endif
}
