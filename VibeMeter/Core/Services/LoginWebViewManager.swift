import AppKit
import Foundation
import os.log
import WebKit

/// Manages WebView windows and navigation for provider authentication.
@MainActor
final class LoginWebViewManager: NSObject {
    // MARK: - Types

    typealias LoginCompletionHandler = (ServiceProvider, Result<String, Error>) -> Void
    typealias LoginDismissHandler = (ServiceProvider) -> Void

    // MARK: - Private Properties

    private var webViews: [ServiceProvider: WKWebView] = [:]
    private var loginWindows: [ServiceProvider: NSWindow] = [:]
    private let logger = Logger(subsystem: "com.vibemeter", category: "LoginWebView")

    // MARK: - Callbacks

    var onLoginCompletion: LoginCompletionHandler?
    var onLoginDismiss: LoginDismissHandler?

    // MARK: - Public Methods

    /// Shows login window for a specific provider.
    func showLoginWindow(for provider: ServiceProvider) {
        logger.info("showLoginWindow called for \(provider.displayName)")

        // Check if login window is already visible
        if let existingWindow = loginWindows[provider], existingWindow.isVisible {
            logger.info("Login window already visible for \(provider.displayName), bringing to front")
            existingWindow.orderFrontRegardless()
            return
        }

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
        window.delegate = self
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

    /// Closes login window for a specific provider.
    func closeLoginWindow(for provider: ServiceProvider) {
        webViews[provider]?.stopLoading()
        loginWindows[provider]?.close()
        webViews[provider] = nil
        loginWindows[provider] = nil

        logger.info("Login window closed for \(provider.displayName)")
        onLoginDismiss?(provider)
    }

    /// Checks if a login window is currently visible for a provider.
    func isLoginWindowVisible(for provider: ServiceProvider) -> Bool {
        loginWindows[provider]?.isVisible ?? false
    }

    // MARK: - Private Methods

    private func getProvider(from window: NSWindow) -> ServiceProvider? {
        guard let identifier = window.identifier?.rawValue else { return nil }
        return ServiceProvider(rawValue: identifier)
    }

    private func getProvider(from webView: WKWebView) -> ServiceProvider? {
        webViews.first(where: { $0.value === webView })?.key
    }

    private func checkForSessionCookie(provider: ServiceProvider, webView: WKWebView) {
        webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { [weak self] cookies in
            guard let self else { return }

            let relevantCookies = cookies.filter { $0.domain.contains(provider.cookieDomain.dropFirst()) }
            self.logger.debug("Found \(relevantCookies.count) cookies for \(provider.displayName) domain")

            if let sessionCookie = cookies.first(where: {
                $0.name == provider.authCookieName && $0.domain.contains(provider.cookieDomain.dropFirst())
            }) {
                self.logger.info("Found \(provider.authCookieName) cookie for \(provider.displayName), login complete!")
                self.logger.debug("Cookie value length: \(sessionCookie.value.count)")

                Task { @MainActor in
                    self.onLoginCompletion?(provider, .success(sessionCookie.value))
                }
            } else {
                self.logger.debug("Session cookie not yet available for \(provider.displayName)")
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension LoginWebViewManager: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didCommit _: WKNavigation!) {
        guard let provider = getProvider(from: webView) else { return }

        let urlString = webView.url?.absoluteString ?? "unknown URL"
        logger.debug("Navigation committed for \(provider.displayName): \(urlString)")

        checkForSessionCookie(provider: provider, webView: webView)
    }

    func webView(_ webView: WKWebView, didFinish _: WKNavigation!) {
        guard let provider = getProvider(from: webView) else { return }

        let urlString = webView.url?.absoluteString ?? "unknown URL"
        logger.debug("Navigation finished for \(provider.displayName): \(urlString)")

        checkForSessionCookie(provider: provider, webView: webView)
    }

    func webView(_ webView: WKWebView, didFail _: WKNavigation!, withError error: Error) {
        guard let provider = getProvider(from: webView) else { return }

        logger.error("Navigation failed for \(provider.displayName): \(error.localizedDescription)")

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            logger.info("Navigation was cancelled for \(provider.displayName)")
            return
        }

        closeLoginWindow(for: provider)
        onLoginCompletion?(provider, .failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError error: Error) {
        guard let provider = getProvider(from: webView) else { return }

        logger.error("Provisional navigation failed for \(provider.displayName): \(error.localizedDescription)")

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            logger.info("Provisional navigation was cancelled for \(provider.displayName)")
            return
        }

        closeLoginWindow(for: provider)
        onLoginCompletion?(provider, .failure(error))
    }
}

// MARK: - NSWindowDelegate

extension LoginWebViewManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let provider = getProvider(from: window) else { return }

        logger.info("Login window closing for \(provider.displayName)")

        webViews[provider]?.stopLoading()
        webViews[provider] = nil
        loginWindows[provider] = nil

        onLoginDismiss?(provider)
    }
}
