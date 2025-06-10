import AppKit
import Foundation
import KeychainAccess
import os.log
import UserNotifications
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
    
    /// Attempts automatic re-authentication for Cursor using stored credentials
    func attemptAutomaticReauthentication(for provider: ServiceProvider, completion: @escaping (Bool) -> Void) {
        guard provider == .cursor else {
            completion(false)
            return
        }
        
        Task { @MainActor in
            do {
                // Retrieve stored credentials
                let credentialKeychain = Keychain(service: "com.vibemeter.cursor.credentials")
                guard let email = try credentialKeychain.get("cursor_email"),
                      let password = try credentialKeychain.get("cursor_password") else {
                    logger.info("No stored credentials found for automatic re-authentication")
                    completion(false)
                    return
                }
                
                logger.info("Attempting automatic re-authentication for Cursor")
                
                // Create hidden WebView for automatic login
                let webViewConfiguration = WKWebViewConfiguration()
                let autoLoginScript = WKUserScript(
                    source: getAutoLoginScript(email: email, password: password),
                    injectionTime: .atDocumentEnd,
                    forMainFrameOnly: true
                )
                webViewConfiguration.userContentController.addUserScript(autoLoginScript)
                
                // Add CAPTCHA detection
                webViewConfiguration.userContentController.add(self, name: "captchaDetected")
                
                let webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
                webView.navigationDelegate = self
                self.webViews[provider] = webView
                
                // Load login page
                webView.load(URLRequest(url: provider.authenticationURL))
                
                // Set timeout for auto-login attempt
                Task {
                    try? await Task.sleep(for: .seconds(30))
                    if self.webViews[provider] != nil {
                        logger.warning("Auto-login timeout reached")
                        self.webViews[provider] = nil
                        completion(false)
                    }
                }
                
            } catch {
                logger.error("Failed to retrieve credentials for auto-login: \(error)")
                completion(false)
            }
        }
    }

    /// Shows login window for a specific provider.
    func showLoginWindow(for provider: ServiceProvider) {
        logger.info("showLoginWindow called for \(provider.displayName)")

        // Check if login window is already visible
        if let existingWindow = loginWindows[provider], existingWindow.isVisible {
            logger.info("Login window already visible for \(provider.displayName), bringing to front")
            existingWindow.orderFrontRegardless()
            return
        }

        // Create provider-specific WebView with JavaScript injection
        let webViewConfiguration = WKWebViewConfiguration()
        
        // Add user script to capture login credentials
        if provider == .cursor {
            let credentialCaptureScript = WKUserScript(
                source: getCursorCredentialCaptureScript(),
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
            webViewConfiguration.userContentController.addUserScript(credentialCaptureScript)
            
            // Add message handler for credential capture
            webViewConfiguration.userContentController.add(self, name: "credentialCapture")
        }
        
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

        // Clean up message handler
        if provider == .cursor {
            webViews[provider]?.configuration.userContentController.removeScriptMessageHandler(forName: "credentialCapture")
        }

        webViews[provider]?.stopLoading()
        webViews[provider] = nil
        loginWindows[provider] = nil

        onLoginDismiss?(provider)
    }
}

// MARK: - WKScriptMessageHandler

extension LoginWebViewManager: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        switch message.name {
        case "credentialCapture":
            handleCredentialCapture(message: message)
        case "captchaDetected":
            handleCaptchaDetected()
        default:
            break
        }
    }
    
    private func handleCredentialCapture(message: WKScriptMessage) {
        guard let messageBody = message.body as? [String: String],
              let email = messageBody["email"],
              let password = messageBody["password"] else {
            return
        }
        
        logger.info("Captured credentials for Cursor login")
        
        // Store credentials in keychain
        Task {
            do {
                let credentialKeychain = Keychain(service: "com.vibemeter.cursor.credentials")
                
                // Store email
                try credentialKeychain.set(email, key: "cursor_email")
                
                // Store password
                try credentialKeychain.set(password, key: "cursor_password")
                
                logger.info("Successfully stored Cursor credentials in keychain")
            } catch {
                logger.error("Failed to store Cursor credentials: \(error)")
            }
        }
    }
    
    private func handleCaptchaDetected() {
        logger.warning("CAPTCHA detected during automatic login")
        
        // Show notification that manual intervention is required
        Task { @MainActor in
            // Show notification using system notifications
            let content = UNMutableNotificationContent()
            content.title = "Cursor Login Requires Attention"
            content.body = "Please complete the CAPTCHA to continue."
            content.sound = .default
            
            let request = UNNotificationRequest(
                identifier: "cursor-captcha-required",
                content: content,
                trigger: nil
            )
            
            try? await UNUserNotificationCenter.current().add(request)
            
            // Show the login window for manual CAPTCHA completion
            showLoginWindow(for: .cursor)
        }
    }
}

// MARK: - JavaScript Injection

private extension LoginWebViewManager {
    func getCursorCredentialCaptureScript() -> String {
        """
        (function() {
            // Wait for the login form to be available
            function captureCredentials() {
                // Look for email/username and password fields
                const emailField = document.querySelector('input[type="email"], input[name="email"], input[name="username"], input[id="email"], input[id="username"]');
                const passwordField = document.querySelector('input[type="password"], input[name="password"], input[id="password"]');
                
                if (!emailField || !passwordField) {
                    // Retry after a short delay if fields not found
                    setTimeout(captureCredentials, 500);
                    return;
                }
                
                // Capture on form submission
                const form = emailField.closest('form') || passwordField.closest('form');
                if (form) {
                    form.addEventListener('submit', function(e) {
                        const email = emailField.value;
                        const password = passwordField.value;
                        
                        if (email && password) {
                            // Send credentials to native app
                            window.webkit.messageHandlers.credentialCapture.postMessage({
                                email: email,
                                password: password
                            });
                        }
                    }, true);
                }
                
                // Also capture on button clicks (in case form submission is prevented)
                const submitButtons = document.querySelectorAll('button[type="submit"], button:contains("Log in"), button:contains("Sign in")');
                submitButtons.forEach(button => {
                    button.addEventListener('click', function() {
                        setTimeout(() => {
                            const email = emailField.value;
                            const password = passwordField.value;
                            
                            if (email && password) {
                                window.webkit.messageHandlers.credentialCapture.postMessage({
                                    email: email,
                                    password: password
                                });
                            }
                        }, 100);
                    }, true);
                });
            }
            
            // Start capture process
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', captureCredentials);
            } else {
                captureCredentials();
            }
        })();
        """
    }
    
    func getAutoLoginScript(email: String, password: String) -> String {
        // Escape special characters in credentials
        let escapedEmail = email.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let escapedPassword = password.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        
        return """
        (function() {
            let loginAttempted = false;
            
            function attemptAutoLogin() {
                if (loginAttempted) return;
                
                // Check for CAPTCHA elements
                const captchaElements = document.querySelectorAll(
                    'div[class*="captcha"], iframe[src*="recaptcha"], div[id*="captcha"], .g-recaptcha'
                );
                
                if (captchaElements.length > 0) {
                    window.webkit.messageHandlers.captchaDetected.postMessage({});
                    return;
                }
                
                // Find email and password fields
                const emailField = document.querySelector('input[type="email"], input[name="email"], input[name="username"], input[id="email"], input[id="username"]');
                const passwordField = document.querySelector('input[type="password"], input[name="password"], input[id="password"]');
                
                if (!emailField || !passwordField) {
                    setTimeout(attemptAutoLogin, 500);
                    return;
                }
                
                // Fill in credentials
                emailField.value = '\(escapedEmail)';
                passwordField.value = '\(escapedPassword)';
                
                // Trigger input events to ensure form validation
                emailField.dispatchEvent(new Event('input', { bubbles: true }));
                emailField.dispatchEvent(new Event('change', { bubbles: true }));
                passwordField.dispatchEvent(new Event('input', { bubbles: true }));
                passwordField.dispatchEvent(new Event('change', { bubbles: true }));
                
                // Find and click submit button
                const submitButton = document.querySelector(
                    'button[type="submit"], button:contains("Log in"), button:contains("Sign in"), input[type="submit"]'
                );
                
                if (submitButton) {
                    loginAttempted = true;
                    setTimeout(() => {
                        submitButton.click();
                    }, 500);
                } else {
                    // Try form submission
                    const form = emailField.closest('form') || passwordField.closest('form');
                    if (form) {
                        loginAttempted = true;
                        setTimeout(() => {
                            form.submit();
                        }, 500);
                    }
                }
            }
            
            // Start auto-login process
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', attemptAutoLogin);
            } else {
                attemptAutoLogin();
            }
        })();
        """
    }
}
