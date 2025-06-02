import Foundation
import WebKit

class LoginManager: NSObject {
    // Callbacks
    var onLoginSuccess: (() -> Void)?
    var onLoginFailure: ((Error) -> Void)?
    var onLoginDismiss: (() -> Void)? // When the login view is dismissed by any means

    private var webView: WebViewContract? // Use the updated WebViewContract
    private var loginWindow: NSWindow?
    private var isProcessingLogin = false // Prevent multiple simultaneous login attempts

    private let settingsManager: SettingsManager
    private let apiClient: CursorAPIClientProtocol // To fetch user/team info post-login
    private let keychainService: KeychainServicing // << New: Using the protocol

    private let authenticatorURL = URL(string: "https://authenticator.cursor.sh/") ?? URL(fileURLWithPath: "/")
    private let callbackURLPrefix = "https://www.cursor.com/api/auth/callback"
    private let cookieDomain = ".cursor.com"
    private let cookieName = "WorkosCursorSessionToken"

    // Factory method for creating WKWebView for production
    @MainActor
    static func createProductionWebView() -> WebViewContract {
        let webViewConfiguration = WKWebViewConfiguration()
        // webViewConfiguration.websiteDataStore = .nonPersistent() // Consider for cleaner sessions
        let wkWebViewInstance = WKWebView(frame: .zero, configuration: webViewConfiguration)
        return wkWebViewInstance
    }

    // Initializer with dependency injection
    @MainActor
    init(
        settingsManager: SettingsManager = .shared,
        apiClient: CursorAPIClientProtocol, // apiClient usually not .shared if it depends on session token
        keychainService: KeychainServicing = KeychainHelper.shared,
        webViewFactory: @escaping @MainActor () -> WebViewContract = LoginManager.createProductionWebView
    ) {
        self.settingsManager = settingsManager
        self.apiClient = apiClient
        self.keychainService = keychainService
        _webViewFactory = webViewFactory
        // self.webView is created on demand in showLoginWindow using the factory
        super.init()
    }

    // Stored factory
    private var _webViewFactory: @MainActor () -> WebViewContract

    func isLoggedIn() -> Bool {
        keychainService.getToken() != nil
    }

    func getAuthToken() -> String? {
        keychainService.getToken()
    }

    @MainActor
    func showLoginWindow() {
        if loginWindow != nil, loginWindow?.isVisible == true {
            loginWindow?.orderFrontRegardless()
            return
        }

        // Reset login processing flag for new session
        isProcessingLogin = false

        // Create webView using the factory
        let newWebView = _webViewFactory()
        webView = newWebView
        webView?.navigationDelegate = self

        // The webView is expected to be a NSView here.
        // This relies on the concrete type from factory (WKWebView or a mock that is NSView)
        guard let viewForWindow = webView?.view else {
            LoggingService.critical(
                "WebView from factory does not provide a view. Cannot show login window.",
                category: .login
            )
            onLoginFailure?(NSError(
                domain: "LoginManager",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "WebView setup error."]
            ))
            return
        }

        let contentViewController = NSViewController()
        contentViewController.view = viewForWindow
        viewForWindow.frame = NSRect(x: 0, y: 0, width: 480, height: 640)

        loginWindow = NSWindow(contentViewController: contentViewController)
        loginWindow?.title = "Login to Cursor"
        loginWindow?.styleMask = [.titled, .closable]
        loginWindow?.isReleasedWhenClosed = false
        loginWindow?.center()
        loginWindow?.delegate = self

        let request = URLRequest(url: authenticatorURL)
        _ = webView?.load(request) // WKNavigation can be ignored if not used
        loginWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        LoggingService.info("Login window presented.", category: .login)
    }

    @MainActor
    private func closeLoginWindow() {
        webView?.stopLoading()
        // webView?.navigationDelegate = nil // Delegate is self, avoid niling out if manager is still alive
        // self.webView = nil // Keep the webView until LoginManager is deallocated or explicitly reset
        loginWindow?.close()
        // loginWindow = nil // Let NSWindowDelegate handle this via windowWillClose if needed, or manage here
        LoggingService.info("Login window close requested.", category: .login)
        onLoginDismiss?() // Ensure dismiss is called
    }

    @MainActor
    func logOut() {
        if keychainService.deleteToken() {
            LoggingService.info("Auth token deleted from Keychain.", category: .login)
        } else {
            LoggingService.error("Failed to delete auth token from Keychain.", category: .login)
        }
        settingsManager.clearUserSessionData()
        // Any other state clearing for logout
        LoggingService.info("User logged out, session data cleared.", category: .login)
    }

    @MainActor
    private func handleSuccessfulLogin(token: String) {
        if keychainService.saveToken(token) {
            LoggingService.info("Auth token saved to Keychain.", category: .login)
            // Authentication successful, close window and let DataCoordinator handle data fetching
            closeLoginWindow()
            onLoginSuccess?()
        } else {
            LoggingService.error("Failed to save auth token to Keychain.", category: .login)
            closeLoginWindow()
            onLoginFailure?(NSError(
                domain: "LoginManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to save token."]
            ))
        }
    }
}

// MARK: - WKNavigationDelegate

extension LoginManager: WKNavigationDelegate {
    // In test, call these directly on LoginManager instance, passing the mockWebView instance as `webViewParam`
    // The first parameter of delegate methods is the WKWebView itself. For testing with a mock that isn't a WKWebView,
    // this can be tricky. We rely on the fact that LoginManager sets `self.webView` (our mock) and then uses it
    // internally.
    // The delegate methods here will be called by the *actual* WKWebView in production.
    // For tests, we call them on LoginManager and pass in our MockWebView cast to WKWebView (which will be nil if not
    // careful)
    // or pass the MockWebView cast as WebViewContract, and ensure the method signatures in LoginManager are flexible or
    // use the protocol type.

    // To simplify, we assume LoginManager's delegate methods are called with `self.webView` (which is a mock in tests)
    // and the methods can internally cast `self.webView` to specific mock types if needed or operate on the protocol.

    @MainActor
    func webView(_: WKWebView, didCommit _: WKNavigation!) {
        guard let currentWebView = webView else {
            LoggingService.debug("LoginManager.webView is nil in didCommit. Ignoring.", category: .login)
            return
        }

        let urlString = currentWebView.url?.absoluteString ?? "unknown URL"
        LoggingService.debug(
            "LoginManager (as WKNavigationDelegate) - didCommit navigation to: \(urlString)",
            category: .login
        )

        // Check for the session cookie on every URL change
        checkForSessionCookie()
    }

    @MainActor // Ensure delegate methods are called on main actor if they touch UI or main-actor properties
    func webView(_: WKWebView, didFinish _: WKNavigation!) {
        guard let currentWebView = webView else {
            LoggingService.debug("LoginManager.webView is nil in didFinish. Ignoring.", category: .login)
            return
        }

        let urlString = currentWebView.url?.absoluteString ?? "unknown URL"
        LoggingService.debug(
            "LoginManager (as WKNavigationDelegate) - didFinish navigation to: \(urlString)",
            category: .login
        )

        // Check for the session cookie on every URL change, not just callback URLs
        checkForSessionCookie()
    }

    @MainActor
    private func checkForSessionCookie() {
        guard let currentWebView = webView, !isProcessingLogin else { return }

        currentWebView.cookieStoreContract.getAllCookies { [weak self] cookies in
            guard let self, !self.isProcessingLogin else { return }

            if let sessionCookie = cookies.first(where: {
                $0.name == self.cookieName && $0.domain.contains(self.cookieDomain.dropFirst())
            }) {
                LoggingService.info("Found \(cookieName) cookie, login complete!", category: .login)
                isProcessingLogin = true
                Task { @MainActor in
                    self.handleSuccessfulLogin(token: sessionCookie.value)
                    self.isProcessingLogin = false
                }
            } else {
                LoggingService.debug(
                    "Session cookie not yet available. Available cookies: " +
                        "\(cookies.map { "\($0.name)@\($0.domain)" }.joined(separator: ", "))",
                    category: .login
                )
            }
        }
    }

    @MainActor
    func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        LoggingService.error(
            "LoginManager (as WKNavigationDelegate) - navigation failed: \(error.localizedDescription)",
            category: .login
        )
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            LoggingService.info("Navigation was cancelled.", category: .login)
            return
        }
        closeLoginWindow()
        onLoginFailure?(error)
    }

    @MainActor
    func webView(
        _: WKWebView,
        didFailProvisionalNavigation _: WKNavigation!,
        withError error: Error
    ) {
        LoggingService.error(
            "LoginManager (as WKNavigationDelegate) - provisional navigation failed: \(error.localizedDescription)",
            category: .login
        )
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            LoggingService.info("Provisional navigation was cancelled.", category: .login)
            return
        }
        closeLoginWindow()
        onLoginFailure?(error)
    }
}

// MARK: - NSWindowDelegate

extension LoginManager: NSWindowDelegate {
    @MainActor
    func windowWillClose(_: Notification) {
        LoggingService.info("Login window is closing by user action (NSWindowDelegate).", category: .login)
        // Avoid re-processing if closeLoginWindow already handled it or is in progress.
        if loginWindow != nil { // If loginWindow is already nil, means closeLoginWindow was called.
            webView?.stopLoading()
            // webView?.navigationDelegate = nil // Careful with self-delegation cycles
            webView = nil // Release the webview instance
            loginWindow = nil // Ensure it's nil now that it's closed
            onLoginDismiss?() // Call dismiss callback if not already called by closeLoginWindow
        }
    }
}
