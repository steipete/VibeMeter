import AppKit
import Foundation

/// Utility for opening provider dashboards with authenticated browser sessions.
///
/// This helper creates temporary HTML files that set authentication cookies
/// and redirect to the provider's dashboard, enabling seamless authenticated access.
enum BrowserAuthenticationHelper {
    /// Opens the Cursor dashboard with authentication token.
    ///
    /// Creates a temporary HTML file that sets the session cookie and redirects
    /// to the Cursor analytics dashboard.
    ///
    /// - Parameter authToken: The WorkosCursorSessionToken value
    /// - Returns: True if successful, false if fallback to unauthenticated URL is needed
    @discardableResult
    static func openCursorDashboardWithAuth(authToken: String) -> Bool {
        let htmlContent = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Redirecting to Cursor Dashboard...</title>
            <script>
                // Set the authentication cookie
                document.cookie = "WorkosCursorSessionToken=\(authToken); domain=.cursor.com; path=/";
                // Redirect to analytics
                window.location.href = "https://www.cursor.com/analytics";
            </script>
        </head>
        <body>
            <p>Redirecting to Cursor Dashboard...</p>
        </body>
        </html>
        """

        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("cursor_redirect.html")

        do {
            try htmlContent.write(to: tempFile, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(tempFile)
            return true
        } catch {
            return false
        }
    }

    /// Opens a URL using the default system browser.
    ///
    /// - Parameter url: The URL to open
    static func openURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
