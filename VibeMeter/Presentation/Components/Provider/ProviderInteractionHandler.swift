import Foundation

/// Handles provider-specific interactions like opening dashboard URLs.
///
/// This class manages provider-specific interaction logic including
/// authenticated browser sessions and fallback URL handling.
enum ProviderInteractionHandler {
    /// Opens the provider dashboard with authentication if available.
    @MainActor
    static func openProviderDashboard(
        for provider: ServiceProvider,
        loginManager: MultiProviderLoginManager?) {
        guard let loginManager,
              let authToken = loginManager.getAuthToken(for: provider) else {
            // Fallback to opening without auth
            BrowserAuthenticationHelper.openURL(provider.dashboardURL)
            return
        }

        // For providers that support authenticated browser sessions,
        // we can create a URL with the session token
        switch provider {
        case .cursor:
            if !BrowserAuthenticationHelper.openCursorDashboardWithAuth(authToken: authToken) {
                // Fallback to opening dashboard without auth
                BrowserAuthenticationHelper.openURL(provider.dashboardURL)
            }
        case .claude:
            // Claude doesn't use authentication tokens for dashboard
            BrowserAuthenticationHelper.openURL(provider.dashboardURL)
        }
    }
}
