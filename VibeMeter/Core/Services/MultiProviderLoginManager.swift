import Combine
import Foundation
import os.log
import WebKit

// MARK: - Multi-Provider Login Manager

/// Manages authentication across multiple service providers simultaneously.
///
/// This manager handles login/logout for multiple cost tracking services
/// (Cursor, Anthropic, OpenAI, etc.) allowing users to be logged into
/// multiple providers at once for comprehensive cost tracking.
@MainActor
public final class MultiProviderLoginManager: NSObject, ObservableObject {
    // MARK: - Published Properties

    @Published
    public private(set) var providerLoginStates: [ServiceProvider: Bool] = [:]
    @Published
    public private(set) var loginErrors: [ServiceProvider: String] = [:]

    // MARK: - Callbacks

    public var onLoginSuccess: ((ServiceProvider) -> Void)?
    public var onLoginFailure: ((ServiceProvider, Error) -> Void)?
    public var onLoginDismiss: ((ServiceProvider) -> Void)?

    // MARK: - Private Properties

    private var webViews: [ServiceProvider: WKWebView] = [:]
    private var loginWindows: [ServiceProvider: NSWindow] = [:]
    private var isProcessingLogin: [ServiceProvider: Bool] = [:]
    private var keychainHelpers: [ServiceProvider: KeychainHelper] = [:]

    private let providerFactory: ProviderFactory
    private let logger = Logger(subsystem: "com.vibemeter", category: "MultiProviderLogin")

    // MARK: - Initialization

    public init(providerFactory: ProviderFactory) {
        self.providerFactory = providerFactory
        super.init()

        // Initialize login states for all available providers
        for provider in ServiceProvider.allCases {
            let keychain = KeychainHelper(service: provider.keychainService)
            keychainHelpers[provider] = keychain
            providerLoginStates[provider] = keychain.getToken() != nil
            isProcessingLogin[provider] = false
        }

        logger.info("MultiProviderLoginManager initialized for \(ServiceProvider.allCases.count) providers")
        
        // Log initial login states
        for provider in ServiceProvider.allCases {
            let isLoggedIn = providerLoginStates[provider, default: false]
            logger.info("\(provider.displayName) initial login state: \(isLoggedIn ? "logged in" : "not logged in")")
        }
    }

    // MARK: - Public API

    /// Checks if user is logged into a specific provider.
    public func isLoggedIn(to provider: ServiceProvider) -> Bool {
        providerLoginStates[provider, default: false]
    }

    /// Gets authentication token for a specific provider.
    public func getAuthToken(for provider: ServiceProvider) -> String? {
        keychainHelpers[provider]?.getToken()
    }

    /// Gets authentication cookies for a specific provider.
    public func getCookies(for provider: ServiceProvider) -> [HTTPCookie]? {
        guard let token = getAuthToken(for: provider) else { return nil }

        var cookieProperties = [HTTPCookiePropertyKey: Any]()
        cookieProperties[.name] = provider.authCookieName
        cookieProperties[.value] = token
        cookieProperties[.domain] = provider.cookieDomain
        cookieProperties[.path] = "/"
        cookieProperties[.secure] = true
        cookieProperties[.expires] = Date(timeIntervalSinceNow: 3600 * 24 * 30) // 30 days

        guard let cookie = HTTPCookie(properties: cookieProperties) else { return nil }
        return [cookie]
    }

    /// Shows login window for a specific provider.
    public func showLoginWindow(for provider: ServiceProvider) {
        logger.info("showLoginWindow called for \(provider.displayName)")
        
        // Check if login window is already visible
        if let existingWindow = loginWindows[provider], existingWindow.isVisible {
            logger.info("Login window already visible for \(provider.displayName), bringing to front")
            existingWindow.orderFrontRegardless()
            return
        }

        // Reset processing flag for new session
        isProcessingLogin[provider] = false
        clearError(for: provider)

        // Create provider-specific WebView
        let webViewConfiguration = WKWebViewConfiguration()
        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 480, height: 640), configuration: webViewConfiguration)
        webView.navigationDelegate = self
        webViews[provider] = webView

        let contentViewController = NSViewController()
        contentViewController.view = webView

        let window = NSWindow(contentViewController: contentViewController)
        window.title = "Login to \(provider.displayName)"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        loginWindows[provider] = window

        // Store provider in window's identifier for delegation
        window.identifier = NSUserInterfaceItemIdentifier(provider.rawValue)

        let authURL = provider.authenticationURL
        let request = URLRequest(url: authURL)
        webView.load(request)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        logger.info("Login window presented for \(provider.displayName) with URL: \(authURL)")
    }

    /// Logs out from a specific provider.
    public func logOut(from provider: ServiceProvider) {
        logger.info("logOut called for \(provider.displayName)")
        guard let keychain = keychainHelpers[provider] else {
            logger.error("No keychain helper found for \(provider.displayName)")
            return
        }

        if keychain.deleteToken() {
            logger.info("Auth token deleted for \(provider.displayName)")
        } else {
            logger.error("Failed to delete auth token for \(provider.displayName)")
        }

        providerLoginStates[provider] = false
        clearError(for: provider)

        logger.info("User logged out from \(provider.displayName)")

        // Notify that logout occurred
        logger.info("Calling onLoginFailure callback for \(provider.displayName) logout")
        let logoutError = NSError(
            domain: "MultiProviderLoginManager",
            code: 0,
            userInfo: [NSLocalizedDescriptionKey: "User logged out from \(provider.displayName)."])
        onLoginFailure?(provider, logoutError)
    }

    /// Logs out from all providers.
    public func logOutFromAll() {
        for provider in ServiceProvider.allCases {
            if isLoggedIn(to: provider) {
                logOut(from: provider)
            }
        }
        logger.info("User logged out from all providers")
    }

    /// Gets all providers the user is currently logged into.
    public var loggedInProviders: [ServiceProvider] {
        ServiceProvider.allCases.filter { isLoggedIn(to: $0) }
    }

    /// Checks if user is logged into any provider.
    public var isLoggedInToAnyProvider: Bool {
        !loggedInProviders.isEmpty
    }

    /// Validates tokens for all logged-in providers.
    public func validateAllTokens() async {
        await withTaskGroup(of: Void.self) { group in
            for provider in loggedInProviders {
                group.addTask {
                    await self.validateToken(for: provider)
                }
            }
        }
    }

    // MARK: - Private Methods

    private func closeLoginWindow(for provider: ServiceProvider) {
        webViews[provider]?.stopLoading()
        loginWindows[provider]?.close()
        webViews[provider] = nil
        loginWindows[provider] = nil

        logger.info("Login window closed for \(provider.displayName)")
        onLoginDismiss?(provider)
    }

    private func handleSuccessfulLogin(for provider: ServiceProvider, token: String) {
        logger.info("handleSuccessfulLogin called for \(provider.displayName)")
        guard let keychain = keychainHelpers[provider] else {
            logger.error("No keychain helper found for \(provider.displayName)")
            return
        }

        if keychain.saveToken(token) {
            logger.info("Auth token saved for \(provider.displayName)")
            providerLoginStates[provider] = true
            logger.info("Updated login state for \(provider.displayName) to: true")
            clearError(for: provider)
            closeLoginWindow(for: provider)
            logger.info("Calling onLoginSuccess callback for \(provider.displayName)")
            onLoginSuccess?(provider)
        } else {
            logger.error("Failed to save auth token for \(provider.displayName)")
            setError(for: provider, message: "Failed to save token")
            closeLoginWindow(for: provider)

            let error = NSError(
                domain: "MultiProviderLoginManager",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to save token for \(provider.displayName)."])
            onLoginFailure?(provider, error)
        }
    }

    private func setError(for provider: ServiceProvider, message: String) {
        loginErrors[provider] = message
    }

    private func clearError(for provider: ServiceProvider) {
        loginErrors.removeValue(forKey: provider)
    }

    private func validateToken(for provider: ServiceProvider) async {
        guard let token = getAuthToken(for: provider) else {
            providerLoginStates[provider] = false
            return
        }

        let providerClient = providerFactory.createProvider(for: provider)
        let isValid = await providerClient.validateToken(authToken: token)

        if !isValid {
            logger.warning("Token validation failed for \(provider.displayName)")
            logOut(from: provider)
        }
    }

    private func getProvider(from window: NSWindow) -> ServiceProvider? {
        guard let identifier = window.identifier?.rawValue else { return nil }
        return ServiceProvider(rawValue: identifier)
    }
}

// MARK: - WKNavigationDelegate

extension MultiProviderLoginManager: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didCommit _: WKNavigation!) {
        // Find which provider this webview belongs to
        guard let provider = webViews.first(where: { $0.value === webView })?.key else { return }

        let urlString = webView.url?.absoluteString ?? "unknown URL"
        logger.debug("Navigation committed for \(provider.displayName): \(urlString)")

        checkForSessionCookie(provider: provider, webView: webView)
    }

    public func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        // Find which provider this webview belongs to
        guard let provider = webViews.first(where: { $0.value === webView })?.key else { return }

        let urlString = webView.url?.absoluteString ?? "unknown URL"
        logger.debug("Navigation finished for \(provider.displayName): \(urlString)")

        checkForSessionCookie(provider: provider, webView: webView)
    }

    private func checkForSessionCookie(provider: ServiceProvider, webView: WKWebView) {
        guard isProcessingLogin[provider] != true else { return }

        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self, self.isProcessingLogin[provider] != true else { return }

            let relevantCookies = cookies.filter { $0.domain.contains(provider.cookieDomain.dropFirst()) }
            logger.debug("Found \(relevantCookies.count) cookies for \(provider.displayName) domain")
            
            if let sessionCookie = cookies.first(where: {
                $0.name == provider.authCookieName && $0.domain.contains(provider.cookieDomain.dropFirst())
            }) {
                logger.info("Found \(provider.authCookieName) cookie for \(provider.displayName), login complete!")
                logger.debug("Cookie value length: \(sessionCookie.value.count)")
                self.isProcessingLogin[provider] = true

                Task { @MainActor in
                    self.handleSuccessfulLogin(for: provider, token: sessionCookie.value)
                    self.isProcessingLogin[provider] = false
                }
            } else {
                logger.debug("Session cookie not yet available for \(provider.displayName)")
            }
        }
    }

    public func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        guard let provider = webViews.first(where: { $0.value === webView })?.key else { return }

        logger.error("Navigation failed for \(provider.displayName): \(error.localizedDescription)")

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            logger.info("Navigation was cancelled for \(provider.displayName)")
            return
        }

        closeLoginWindow(for: provider)
        onLoginFailure?(provider, error)
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        guard let provider = webViews.first(where: { $0.value === webView })?.key else { return }

        logger.error("Provisional navigation failed for \(provider.displayName): \(error.localizedDescription)")

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            logger.info("Provisional navigation was cancelled for \(provider.displayName)")
            return
        }

        closeLoginWindow(for: provider)
        onLoginFailure?(provider, error)
    }
}

// MARK: - NSWindowDelegate

extension MultiProviderLoginManager: NSWindowDelegate {
    public func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let provider = getProvider(from: window) else { return }

        logger.info("Login window closing for \(provider.displayName)")

        webViews[provider]?.stopLoading()
        webViews[provider] = nil
        loginWindows[provider] = nil

        onLoginDismiss?(provider)
    }
}
