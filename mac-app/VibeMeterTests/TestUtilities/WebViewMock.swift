import Foundation
import WebKit
@testable import VibeMeter

// The WebViewContract and HTTPCookieStoreContract protocols are now defined in 
// VibeMeter/WebViewContract.swift

// MARK: - Mock Cookie Store

public class MockHTTPCookieStore: HTTPCookieStoreContract {
    public var cookiesToReturn: [HTTPCookie] = []
    public var getAllCookiesCallCount = 0

    public init() {}

    public func getAllCookies(_ completionHandler: @escaping ([HTTPCookie]) -> Void) {
        getAllCookiesCallCount += 1
        completionHandler(cookiesToReturn)
    }

    public func reset() {
        cookiesToReturn = []
        getAllCookiesCallCount = 0
    }
}

// MARK: - Mock WebView (as NSView subclass)

@MainActor
public class MockWebView: NSView, WebViewContract {
    public var url: URL?
    public var navigationDelegate: WKNavigationDelegate?

    // Expose the mock cookie store for test setup
    public let mockCookieStore = MockHTTPCookieStore()
    public var cookieStoreContract: HTTPCookieStoreContract { mockCookieStore }
    public var view: NSView { self } // Returns itself as it's an NSView

    public var loadRequestCalledWith: URLRequest?
    public var stopLoadingCalled = false

    // Required NSView initializers
    override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        // fatalError("init(coder:) has not been implemented for MockWebView") // Or implement if needed
    }

    // Convenience init for tests
    public convenience init() {
        self.init(frame: .zero)
    }

    public func load(_ request: URLRequest) -> WKNavigation? {
        loadRequestCalledWith = request
        url = request.url
        return nil
    }

    public func stopLoading() {
        stopLoadingCalled = true
    }

    public func reset() {
        url = nil
        navigationDelegate = nil
        loadRequestCalledWith = nil
        stopLoadingCalled = false
        mockCookieStore.reset()
    }

    // WKWebView is an NSView. For the LoginManager to use MockWebView in place of a real WKWebView
    // when creating its NSWindow, MockWebView must also be an NSView.
    // This makes the mock more complex but necessary if we are injecting it at the NSView level.
    // However, LoginManager's showLoginWindow now takes a factory that returns WebViewContract.
    // The factory in tests will return this MockWebView. LoginManager then tries to cast it to NSView.
    // This will fail.
    // Solution: The test factory for MockWebView needs to return an object that IS an NSView AND implements WebViewContract.
    // This might mean MockWebView itself needs to inherit from NSView if it's directly used as the view.
    // OR, the factory provides a real WKWebView configured to use mock components (harder).

    // For the current LoginManager structure that casts `webView as? NSView`,
    // MockWebView needs to be an NSView for the test to pass that guard check.
    // This means `public class MockWebView: NSView, WebViewContract { ... }`
    // and implementing required NSView initializers. This significantly increases mock complexity.

    // Alternative simpler approach used by LoginManager refactor:
    // The showLoginWindow() should not cast to NSView directly but use the WebViewContract
    // and the `view` it holds should be provided by the contract (e.g. `var viewRepresentation: NSView { get }`)
    // For now, the current LoginManager test will need to provide a MockWebView that is also an NSView if it uses the
    // factory pattern as refactored.
    // Let's assume for tests, we can manage this (e.g. the test might bypass showing a real window).
}

// If MockWebView must be an NSView for tests:
/*
 @MainActor
 public class MockWebViewAsNSView: NSView, WebViewContract {
     public var url: URL?
     public var navigationDelegate: WKNavigationDelegate?
     public let mockCookieStore = MockHTTPCookieStore()
     public var cookieStoreContract: HTTPCookieStoreContract { mockCookieStore }
     public var loadRequestCalledWith: URLRequest?
     public var stopLoadingCalled = false

     public override init(frame frameRect: NSRect) {
         super.init(frame: frameRect)
     }

     required public init?(coder: NSCoder) {
         fatalError("init(coder:) has not been implemented")
     }

     public func load(_ request: URLRequest) -> WKNavigation? {
         loadRequestCalledWith = request
         self.url = request.url
         return nil
     }

     public func stopLoading() {
         stopLoadingCalled = true
     }

     public func reset() {
         url = nil
         navigationDelegate = nil
         loadRequestCalledWith = nil
         stopLoadingCalled = false
         mockCookieStore.reset()
     }
     */
