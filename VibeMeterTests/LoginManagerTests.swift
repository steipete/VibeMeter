@testable import VibeMeter
import WebKit // Needed for WKNavigationDelegate, HTTPCookie
import XCTest

@MainActor
class LoginManagerTests: XCTestCase, @unchecked Sendable {
    var loginManager: LoginManager!
    var mockSettingsManager: SettingsManager!
    var mockApiClient: CursorAPIClientMock!
    var mockURLSession: MockURLSession!
    var mockKeychainService: KeychainServiceMock!
    var mockWebView: MockWebView! // Using the NSView subclass version

    var testUserDefaults: UserDefaults!
    let testSuiteName = "com.vibemeter.tests.LoginManagerTests"

    override func setUp() {
        super.setUp()

        let suite = UserDefaults(suiteName: testSuiteName)
        suite?.removePersistentDomain(forName: testSuiteName)

        MainActor.assumeIsolated {
            testUserDefaults = suite
            // Order of setup can be important if there are inter-dependencies in init, though not strictly here.
            let mockStartupManager = StartupManagerMock()
            mockSettingsManager = SettingsManager(userDefaults: testUserDefaults, startupManager: mockStartupManager)
            SettingsManager
                ._test_setSharedInstance(userDefaults: testUserDefaults) // If LoginManager internally uses .shared

            mockKeychainService = KeychainServiceMock()
            // For LoginManager tests, we use the CursorAPIClientMock
            mockApiClient = CursorAPIClientMock()
            mockURLSession = MockURLSession()

            mockWebView = MockWebView() // This is now an NSView

            // Factory for LoginManager to produce our mockWebView
            let mockWebViewFactory: @MainActor () -> WebViewContract = {
                self.mockWebView // Return the instance we hold and can control
            }

            loginManager = LoginManager(
                settingsManager: mockSettingsManager,
                apiClient: mockApiClient,
                keychainService: mockKeychainService,
                webViewFactory: mockWebViewFactory
            )
        }
    }

    override func tearDown() {
        MainActor.assumeIsolated {
            loginManager = nil
            mockWebView = nil
            mockKeychainService = nil
            mockApiClient = nil
            mockSettingsManager = nil
            SettingsManager._test_clearSharedInstance()
            testUserDefaults.removePersistentDomain(forName: testSuiteName)
            testUserDefaults = nil
        }
        super.tearDown()
    }

    func testInitialStateIsLoggedOut() {
        XCTAssertFalse(loginManager.isLoggedIn(), "Should be logged out initially if keychain is empty.")
    }

    func testShowLoginWindowLoadsAuthenticatorURL() {
        loginManager.showLoginWindow()
        XCTAssertNotNil(mockWebView.loadRequestCalledWith, "load() should be called on the webview.")
        XCTAssertEqual(
            mockWebView.loadRequestCalledWith?.url,
            URL(string: "https://authenticator.cursor.sh/"),
            "Should load the authenticator URL."
        )
    }

    func testLogoutClearsTokenAndSessionData() {
        // Arrange: Simulate logged-in state
        _ = mockKeychainService.saveToken("testToken")
        mockSettingsManager.teamId = 123
        mockSettingsManager.userEmail = "test@example.com"

        // Act
        loginManager.logOut()

        // Assert
        XCTAssertTrue(mockKeychainService.deleteTokenCalled, "deleteToken should be called on keychain service.")
        XCTAssertNil(mockKeychainService.getToken(), "Token should be nil after logout.")
        XCTAssertNil(mockSettingsManager.teamId, "TeamID should be cleared from settings.")
        XCTAssertNil(mockSettingsManager.userEmail, "UserEmail should be cleared from settings.")
    }

    // MARK: - Login Flow Tests

    func testSuccessfulLoginFlow() async throws {
        let expectation = XCTestExpectation(description: "Login success callback triggered")
        loginManager.onLoginSuccess = { expectation.fulfill() }
        loginManager.onLoginFailure = { error in XCTFail("Login failed unexpectedly: \(error)") }

        // 1. Show Login Window (already tested that it loads correct URL)
        loginManager.showLoginWindow()

        // 2. Simulate WebView navigating to callback URL and finishing
        let callbackURL = URL(string: "https://www.cursor.com/api/auth/callback/somecode")!
        mockWebView.url = callbackURL // Simulate webview having this URL

        // 3. Simulate cookie store having the token
        let mockCookie = HTTPCookie(properties: [
            .domain: ".cursor.com",
            .path: "/",
            .name: "WorkosCursorSessionToken",
            .value: "valid-session-token",
            .secure: "TRUE",
            .expires: Date(timeIntervalSinceNow: 3600),
        ])!
        mockWebView.mockCookieStore.cookiesToReturn = [mockCookie]

        // 4. Mock API client responses for post-login calls
        mockApiClient.teamInfoToReturn = TeamInfo(id: 789, name: "Vibeville")

        // Configure mock for fetchUserInfo
        mockApiClient.userInfoToReturn = UserInfo(email: "user@vibeville.com", teamId: nil)
        // We need a way to queue responses in MockURLSession or re-configure it per call.
        // For simplicity, assume MockURLSession is reconfigured before the second call or it can queue.
        // Let's assume re-configuration: (This part is tricky without a good queuing mock session)
        // For this test, we will just set up the first call, and assume the second will also be mocked if
        // CursorAPIClient calls it.
        // A more robust MockURLSession would allow conditional responses based on URL or a queue.

        // Trigger the delegate method directly as system would
        // The `webViewParam` would be the actual WKWebView instance from the system.
        // For testing, we need a way to pass our `mockWebView` in a way that LoginManager can use its
        // `cookieStoreContract`.
        // The LoginManager.webView(didFinish:) now uses `self.webView` internally.
        // So, the parameter `webViewParam` is less critical if `self.webView` IS our mock.
        let dummyWKWebView =
            WKWebView() // Parameter for delegate method, not directly used by current LoginManager internal logic if
        // self.webView is the mock
        loginManager.webView(dummyWKWebView, didFinish: nil) // Pass nil for navigation as it's not used in this path

        await fulfillment(of: [expectation], timeout: 5.0)

        // Assertions after login success
        XCTAssertTrue(loginManager.isLoggedIn(), "LoginManager should report isLoggedIn = true")
        XCTAssertEqual(mockKeychainService.getToken(), "valid-session-token", "Token should be saved to keychain.")
        // Team ID and user email are NOT saved by LoginManager - that's DataCoordinator's job
        // LoginManager only saves the token and triggers the success callback
        XCTAssertTrue(mockWebView.mockCookieStore.getAllCookiesCallCount > 0, "getAllCookies should have been called.")
    }

    func testLoginFlowCookieNotFound() async {
        // When no cookie is found, LoginManager doesn't call any callbacks - it just waits
        // This test verifies that no login occurs when cookie is missing

        loginManager.onLoginSuccess = { XCTFail("Login should not succeed without cookie.") }
        loginManager.onLoginFailure = { _ in XCTFail("Login should not fail - it should just wait.") }

        loginManager.showLoginWindow()
        let callbackURL = URL(string: "https://www.cursor.com/api/auth/callback/somecode")!
        mockWebView.url = callbackURL
        mockWebView.mockCookieStore.cookiesToReturn = [] // No cookie

        let dummyWKWebView = WKWebView()
        loginManager.webView(dummyWKWebView, didFinish: nil)

        // Give it a moment to process
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertFalse(loginManager.isLoggedIn(), "Should not be logged in.")
        XCTAssertNil(mockKeychainService.getToken(), "Token should not be saved.")
    }

    func testLoginFlowKeychainSaveFails() async {
        let expectation = XCTestExpectation(description: "Login failure callback triggered for keychain save fail")
        loginManager.onLoginFailure = { error in
            XCTAssertEqual((error as NSError).code, 1, "Error code should indicate token save failure.")
            expectation.fulfill()
        }
        mockKeychainService.saveTokenShouldSucceed = false // Make keychain save fail

        loginManager.showLoginWindow()
        let callbackURL = URL(string: "https://www.cursor.com/api/auth/callback/somecode")!
        mockWebView.url = callbackURL
        let mockCookie = HTTPCookie(properties: [
            .domain: ".cursor.com",
            .path: "/",
            .name: "WorkosCursorSessionToken",
            .value: "token",
        ])!
        mockWebView.mockCookieStore.cookiesToReturn = [mockCookie]

        // API calls will be mocked to succeed to isolate keychain failure
        mockApiClient.teamInfoToReturn = TeamInfo(id: 1, name: "T")
        mockApiClient.userInfoToReturn = UserInfo(email: "test@example.com", teamId: nil)

        let dummyWKWebView = WKWebView()
        loginManager.webView(dummyWKWebView, didFinish: nil)

        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertFalse(loginManager.isLoggedIn(), "Should not be logged in.")
    }

    // Removed testLoginFlowApiFetchTeamInfoFails - LoginManager doesn't make API calls
    // That's DataCoordinator's responsibility

    func testWebViewDidFailNavigation() async {
        let expectation = XCTestExpectation(description: "Login failure from webView didFail")
        loginManager.onLoginFailure = { _ in expectation.fulfill() }

        loginManager.showLoginWindow() // WebView is created here
        let navError = NSError(domain: "TestError", code: 123, userInfo: nil)
        let dummyWKWebView = WKWebView()
        loginManager.webView(dummyWKWebView, didFail: nil, withError: navError) // Simulate fail

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testWebViewDidFailProvisionalNavigation() async {
        let expectation = XCTestExpectation(description: "Login failure from webView didFailProvisionalNavigation")
        loginManager.onLoginFailure = { _ in expectation.fulfill() }

        loginManager.showLoginWindow()
        let navError = NSError(domain: "TestErrorProv", code: 456, userInfo: nil)
        let dummyWKWebView = WKWebView()
        loginManager.webView(dummyWKWebView, didFailProvisionalNavigation: nil, withError: navError) // Simulate fail

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testUserClosesLoginWindowCallsDismissCallback() {
        let expectation = XCTestExpectation(description: "onLoginDismiss callback triggered")
        loginManager.onLoginDismiss = { expectation.fulfill() }

        loginManager.showLoginWindow() // This creates and shows the loginWindow internally

        // Simulate the windowWillClose delegate call
        // We need access to the actual loginWindow created by LoginManager to pass as notification.object
        // This is a limitation if loginWindow is private and not exposed.
        // For now, we assume it's okay to pass nil or a dummy notification.
        // The important part is that the delegate method on LoginManager is called.
        let dummyNotification = Notification(name: NSWindow.willCloseNotification)
        loginManager.windowWillClose(dummyNotification) // Simulate window closing

        wait(for: [expectation], timeout: 1.0)
    }
}
