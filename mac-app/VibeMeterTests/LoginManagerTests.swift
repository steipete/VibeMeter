@testable import VibeMeter
import WebKit // Needed for WKNavigationDelegate, HTTPCookie
import XCTest

@MainActor // LoginManager and its interactions are often main-thread bound
class LoginManagerTests: XCTestCase {
    var loginManager: LoginManager!
    var mockSettingsManager: SettingsManager!
    var mockApiClient: CursorAPIClient!
    var mockKeychainService: KeychainServiceMock!
    var mockWebView: MockWebView! // Using the NSView subclass version

    var testUserDefaults: UserDefaults!
    let testSuiteName = "com.vibemeter.tests.LoginManagerTests"

    override func setUpWithError() throws {
        try super.setUpWithError()

        testUserDefaults = UserDefaults(suiteName: testSuiteName)
        testUserDefaults.removePersistentDomain(forName: testSuiteName)

        // Order of setup can be important if there are inter-dependencies in init, though not strictly here.
        mockSettingsManager = SettingsManager(userDefaults: testUserDefaults)
        SettingsManager
            ._test_setSharedInstance(userDefaults: testUserDefaults) // If LoginManager internally uses .shared

        mockKeychainService = KeychainServiceMock()
        // mockApiClient needs a URLSessionProtocol, can use MockURLSession if its methods are called.
        // For LoginManager tests, we mostly care about the *outcomes* of apiClient calls (success/failure),
        // so a simpler mock or pre-setting results on a more complex mockApiClient might be sufficient.
        // Here, we assume CursorAPIClient is injectable and its behavior can be controlled for these tests.
        let mockUrlSessionForApiClient = MockURLSession() // ApiClient needs one
        mockApiClient = CursorAPIClient(session: mockUrlSessionForApiClient, settingsManager: mockSettingsManager)

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

    override func tearDownWithError() throws {
        loginManager = nil
        mockWebView = nil
        mockKeychainService = nil
        mockApiClient = nil
        mockSettingsManager = nil
        SettingsManager._test_clearSharedInstance()
        testUserDefaults.removePersistentDomain(forName: testSuiteName)
        testUserDefaults = nil
        try super.tearDownWithError()
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
        mockWebView.cookieStore.cookiesToReturn = [mockCookie]

        // 4. Mock API client responses for post-login calls
        let teamInfoResponse = CursorAPIClient.TeamInfoResponse(teams: [CursorAPIClient.Team(
            id: 789,
            name: "Vibeville"
        )])
        (mockApiClient.session as! MockURLSession).nextData = try JSONEncoder().encode(teamInfoResponse)
        (mockApiClient.session as! MockURLSession).nextResponse = HTTPURLResponse(
            url: URL(string: "https://cursor.com/api/dashboard/teams")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )

        // Prepare for the second API call (fetchUserInfo)
        let userInfoResponse = CursorAPIClient.UserInfoResponse(email: "user@vibeville.com")
        let nextDataUserInfo = try JSONEncoder().encode(userInfoResponse)
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
        XCTAssertEqual(mockSettingsManager.teamId, 789, "Team ID should be saved.")
        // XCTAssertEqual(mockSettingsManager.userEmail, "user@vibeville.com", "User email should be saved.") // Needs
        // better multi-response mocking
        XCTAssertTrue(mockWebView.cookieStore.getAllCookiesCallCount > 0, "getAllCookies should have been called.")
    }

    func testLoginFlowCookieNotFound() async {
        let expectation = XCTestExpectation(description: "Login failure callback triggered for no cookie")
        loginManager.onLoginFailure = { error in
            XCTAssertEqual((error as NSError).code, 2, "Error code should indicate cookie not found.")
            expectation.fulfill()
        }
        loginManager.onLoginSuccess = { XCTFail("Login should have failed.") }

        loginManager.showLoginWindow()
        let callbackURL = URL(string: "https://www.cursor.com/api/auth/callback/somecode")!
        mockWebView.url = callbackURL
        mockWebView.cookieStore.cookiesToReturn = [] // No cookie

        let dummyWKWebView = WKWebView()
        loginManager.webView(dummyWKWebView, didFinish: nil)

        await fulfillment(of: [expectation], timeout: 2.0)
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
        mockWebView.cookieStore.cookiesToReturn = [mockCookie]

        // API calls will be mocked to succeed to isolate keychain failure
        let teamInfoResponse = CursorAPIClient.TeamInfoResponse(teams: [CursorAPIClient.Team(id: 1, name: "T")])
        (mockApiClient.session as! MockURLSession).nextData = try! JSONEncoder().encode(teamInfoResponse)
        (mockApiClient.session as! MockURLSession).nextResponse = HTTPURLResponse(
            url: URL(string: "https://cursor.com/api/dashboard/teams")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        // UserInfo fetch would also need mocking here

        let dummyWKWebView = WKWebView()
        loginManager.webView(dummyWKWebView, didFinish: nil)

        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertFalse(loginManager.isLoggedIn(), "Should not be logged in.")
    }

    func testLoginFlowApiFetchTeamInfoFails() async {
        let expectation = XCTestExpectation(description: "Login failure callback for API fail")
        loginManager.onLoginFailure = { error in
            if let apiError = error as? CursorAPIClient.APIError {
                if case .networkError = apiError { expectation.fulfill() }
                else { XCTFail("Expected networkError from API client but got \(apiError)") }
            } else {
                XCTFail("Error was not an APIError: \(error)")
            }
        }

        loginManager.showLoginWindow()
        let callbackURL = URL(string: "https://www.cursor.com/api/auth/callback/somecode")!
        mockWebView.url = callbackURL
        let mockCookie = HTTPCookie(properties: [
            .domain: ".cursor.com",
            .path: "/",
            .name: "WorkosCursorSessionToken",
            .value: "goodtoken",
        ])!
        mockWebView.cookieStore.cookiesToReturn = [mockCookie]

        // Mock API client to fail fetchTeamInfo
        (mockApiClient.session as! MockURLSession).nextResponse = HTTPURLResponse(
            url: URL(string: "https://cursor.com/api/dashboard/teams")!,
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
        )
        (mockApiClient.session as! MockURLSession).nextData = nil // Or error data

        let dummyWKWebView = WKWebView()
        loginManager.webView(dummyWKWebView, didFinish: nil)

        await fulfillment(of: [expectation], timeout: 2.0)
        // Token IS saved to keychain even if API calls fail post-login, as per current
        // LoginManager.handleSuccessfulLogin logic
        XCTAssertTrue(loginManager.isLoggedIn(), "Token should still be saved even if subsequent API calls fail.")
        XCTAssertEqual(mockKeychainService.getToken(), "goodtoken")
        XCTAssertNil(mockSettingsManager.teamId, "TeamID should be nil as API call failed.")
    }

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
