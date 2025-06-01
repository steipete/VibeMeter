import Foundation
import WebKit

// Protocol for WebView to allow mocking in tests
@MainActor
public protocol WebViewContract {
    var url: URL? { get }
    var navigationDelegate: WKNavigationDelegate? { get set }
    var cookieStoreContract: HTTPCookieStoreContract { get }
    var view: NSView { get } // The underlying NSView representation

    func load(_ request: URLRequest) -> WKNavigation?
    func stopLoading()
}

// Make WKWebView conform to WebViewContract
extension WKWebView: WebViewContract {
    @MainActor
    public var cookieStoreContract: HTTPCookieStoreContract {
        configuration.websiteDataStore.httpCookieStore
    }

    @MainActor
    public var view: NSView {
        self // WKWebView is an NSView
    }
}

// Protocol for WKHTTPCookieStore
@MainActor
public protocol HTTPCookieStoreContract {
    func getAllCookies(_ completionHandler: @escaping @MainActor @Sendable ([HTTPCookie]) -> Void)
    // Add other methods if LoginManager uses them (e.g., setCookie, deleteCookie)
}

extension WKHTTPCookieStore: HTTPCookieStoreContract {}
