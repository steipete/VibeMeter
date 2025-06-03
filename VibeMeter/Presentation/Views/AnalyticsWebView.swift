import SwiftUI
import WebKit

// MARK: - Analytics Web View

/// A SwiftUI wrapper for displaying the Cursor analytics webpage.
///
/// This view embeds a WKWebView to show https://www.cursor.com/analytics
/// and handles authentication by injecting the session token as a cookie.
struct AnalyticsWebView: NSViewRepresentable {
    let authToken: String?

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        // Inject authentication cookie if logged in
        if let token = authToken {
            var cookieProperties = [HTTPCookiePropertyKey: Any]()
            cookieProperties[.name] = "WorkosCursorSessionToken"
            cookieProperties[.value] = token
            cookieProperties[.domain] = ".cursor.com"
            cookieProperties[.path] = "/"
            cookieProperties[.secure] = true
            cookieProperties[.expires] = Date(timeIntervalSinceNow: 3600 * 24 * 30) // 30 days

            if let cookie = HTTPCookie(properties: cookieProperties) {
                webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
            }
        }

        // Load the analytics page
        if let url = URL(string: "https://www.cursor.com/analytics") {
            let request = URLRequest(url: url)
            webView.load(request)
        }

        return webView
    }

    func updateNSView(_: WKWebView, context _: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: AnalyticsWebView

        init(_ parent: AnalyticsWebView) {
            self.parent = parent
        }

        func webView(_: WKWebView, didFinish _: WKNavigation!) {
            // Optional: Handle navigation completion
        }

        func webView(_: WKWebView, didFail _: WKNavigation!, withError error: Error) {
            LoggingService.error("Analytics page failed to load: \(error.localizedDescription)", category: .ui)
        }
    }
}

// MARK: - Analytics Settings View

/// The analytics tab view in settings.
///
/// Displays the Cursor analytics webpage in an embedded web view,
/// allowing users to view their usage statistics directly within the app.
struct AnalyticsSettingsView: View {
    let userSession: MultiProviderUserSessionData
    let loginManager: MultiProviderLoginManager

    var body: some View {
        VStack(spacing: 0) {
            if userSession.isLoggedIn(to: .cursor) {
                // Show analytics web view with auth token
                AnalyticsWebView(authToken: loginManager.getAuthToken(for: .cursor))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Show login prompt
                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.hierarchical)

                    Text("Login Required")
                        .font(.title2)
                        .fontWeight(.medium)

                    Text("Please log in to Cursor to view your analytics")
                        .foregroundStyle(.secondary)

                    Button("Log In to Cursor") {
                        loginManager.showLoginWindow(for: .cursor)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
    }
}

// MARK: - Previews

#Preview("Analytics Web View") {
    AnalyticsWebView(authToken: nil)
        .frame(width: 800, height: 600)
}

#Preview("Analytics Settings - Not Logged In") {
    AnalyticsSettingsView(
        userSession: MultiProviderUserSessionData(),
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())
        )
    )
    .frame(width: 800, height: 600)
}

#Preview("Analytics Settings - Logged In") {
    let userSessionData = MultiProviderUserSessionData()
    userSessionData.handleLoginSuccess(
        for: .cursor,
        email: "user@example.com",
        teamName: "Example Team",
        teamId: 123
    )
    
    return AnalyticsSettingsView(
        userSession: userSessionData,
        loginManager: MultiProviderLoginManager(
            providerFactory: ProviderFactory(settingsManager: MockSettingsManager())
        )
    )
    .frame(width: 800, height: 600)
}

// MARK: - Mock Settings Manager for Preview

@MainActor
private class MockSettingsManager: SettingsManagerProtocol {
    var providerSessions: [ServiceProvider: ProviderSession] = [:]
    var selectedCurrencyCode: String = "USD"
    var warningLimitUSD: Double = 200
    var upperLimitUSD: Double = 500
    var refreshIntervalMinutes: Int = 5
    var launchAtLoginEnabled: Bool = false
    var showCostInMenuBar: Bool = true
    var showInDock: Bool = false
    var enabledProviders: Set<ServiceProvider> = [.cursor]
    
    func clearUserSessionData() {
        providerSessions.removeAll()
    }
    
    func clearUserSessionData(for provider: ServiceProvider) {
        providerSessions.removeValue(forKey: provider)
    }
    
    func getSession(for provider: ServiceProvider) -> ProviderSession? {
        providerSessions[provider]
    }
    
    func updateSession(for provider: ServiceProvider, session: ProviderSession) {
        providerSessions[provider] = session
    }
}
