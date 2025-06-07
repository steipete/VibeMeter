import Foundation
import Testing
@testable import VibeMeter

// MARK: - Test Data

private struct QueryItemTestCase: Sendable, CustomTestStringConvertible {
    let baseURL: String
    let items: [URLQueryItem]
    let expected: String
    let description: String

    init(_ baseURL: String, items: [URLQueryItem], expected: String, _ description: String) {
        self.baseURL = baseURL
        self.items = items
        self.expected = expected
        self.description = description
    }
    
    var testDescription: String {
        "\(description): \(baseURL) + \(items.count) item(s) → \(expected)"
    }
}

private struct EncodingTestCase: Sendable, CustomTestStringConvertible {
    let baseURL: String
    let paramName: String
    let paramValue: String
    let expected: String
    let description: String
    
    var testDescription: String {
        "\(description): \(paramName)=\(paramValue) → \(expected)"
    }
}

// MARK: - Main Test Suite

@Suite("URL Query Items Extension Tests", .tags(.unit, .fast))
@MainActor
struct URLQueryItemsTests {
    // MARK: - Basic Operations

    @Suite("Basic Operations")
    struct Basic {
        fileprivate static let basicTestCases: [QueryItemTestCase] = [
            // Empty cases
            QueryItemTestCase("https://example.com/path",
                              items: [],
                              expected: "https://example.com/path",
                              "empty array returns same URL"),

            // Adding to URL without query
            QueryItemTestCase("https://example.com/path",
                              items: [URLQueryItem(name: "key", value: "value")],
                              expected: "https://example.com/path?key=value",
                              "adds query to URL without query"),

            // Adding to URL with existing query
            QueryItemTestCase("https://example.com/path?existing=param",
                              items: [URLQueryItem(name: "new", value: "item")],
                              expected: "https://example.com/path?existing=param&new=item",
                              "appends to existing query"),

            // Multiple items
            QueryItemTestCase("https://example.com/api",
                              items: [
                                  URLQueryItem(name: "param1", value: "value1"),
                                  URLQueryItem(name: "param2", value: "value2"),
                                  URLQueryItem(name: "param3", value: "value3"),
                              ],
                              expected: "https://example.com/api?param1=value1&param2=value2&param3=value3",
                              "adds multiple items"),

            // Different schemes
            QueryItemTestCase("https://secure.example.com/api",
                              items: [URLQueryItem(name: "token", value: "secret123")],
                              expected: "https://secure.example.com/api?token=secret123",
                              "HTTPS scheme"),

            QueryItemTestCase("http://example.com/api",
                              items: [URLQueryItem(name: "key", value: "value")],
                              expected: "http://example.com/api?key=value",
                              "HTTP scheme"),

            // Path components
            QueryItemTestCase("https://example.com",
                              items: [URLQueryItem(name: "q", value: "search")],
                              expected: "https://example.com?q=search",
                              "URL without path"),

            QueryItemTestCase("https://example.com/",
                              items: [URLQueryItem(name: "q", value: "search")],
                              expected: "https://example.com/?q=search",
                              "URL with trailing slash"),

            QueryItemTestCase("https://example.com/path/to/resource",
                              items: [URLQueryItem(name: "id", value: "123")],
                              expected: "https://example.com/path/to/resource?id=123",
                              "deep path"),

            // Port numbers
            QueryItemTestCase("https://example.com:8080/api",
                              items: [URLQueryItem(name: "version", value: "2")],
                              expected: "https://example.com:8080/api?version=2",
                              "custom port"),

            // Fragments
            QueryItemTestCase("https://example.com/page#section",
                              items: [URLQueryItem(name: "ref", value: "nav")],
                              expected: "https://example.com/page?ref=nav#section",
                              "URL with fragment"),
        ]

        @Test("Basic query item operations", arguments: Basic.basicTestCases)
        fileprivate func basicQueryItemOperations(testCase: QueryItemTestCase) {
            // Given
            let url = URL(string: testCase.baseURL)!

            // When
            let result = url.appendingQueryItems(testCase.items)

            // Then
            #expect(result.absoluteString == testCase.expected)
        }

        @Test("Nil values in query items", arguments: [
            ("param", nil as String?, "param with nil value"),
            ("key", "value", "param with value")
        ])
        func nilValuesInQueryItems(name: String, value: String?, description _: String) {
            // Given
            let url = URL(string: "https://example.com")!
            let item = URLQueryItem(name: name, value: value)

            // When
            let result = url.appendingQueryItems([item])

            // Then
            if value == nil {
                #expect(result.absoluteString == "https://example.com?\(name)")
            } else {
                #expect(result.absoluteString == "https://example.com?\(name)=\(value!)")
            }
        }
    }

    // MARK: - Advanced Features

    @Suite("Advanced Features", .tags(.integration))
    struct Advanced {
        fileprivate static let encodingTestCases: [EncodingTestCase] = [
            // Special characters
            EncodingTestCase(baseURL: "https://example.com",
                             paramName: "text",
                             paramValue: "hello world",
                             expected: "https://example.com?text=hello%20world",
                             description: "spaces encoded"),

            EncodingTestCase(baseURL: "https://example.com",
                             paramName: "query",
                             paramValue: "test&value",
                             expected: "https://example.com?query=test%26value",
                             description: "ampersand encoded"),

            EncodingTestCase(baseURL: "https://example.com",
                             paramName: "eq",
                             paramValue: "a=b",
                             expected: "https://example.com?eq=a%3Db",
                             description: "equals sign encoded"),

            EncodingTestCase(baseURL: "https://example.com",
                             paramName: "special",
                             paramValue: "!@#$%^&*()",
                             expected: "https://example.com?special=!@%23$%25%5E%26*()",
                             description: "special characters"),

            // Unicode
            EncodingTestCase(baseURL: "https://example.com",
                             paramName: "emoji",
                             paramValue: "🚀",
                             expected: "https://example.com?emoji=%F0%9F%9A%80",
                             description: "emoji encoded"),

            EncodingTestCase(baseURL: "https://example.com",
                             paramName: "text",
                             paramValue: "こんにちは",
                             expected: "https://example.com?text=%E3%81%93%E3%82%93%E3%81%AB%E3%81%A1%E3%81%AF",
                             description: "Japanese text"),

            // URL special chars
            EncodingTestCase(baseURL: "https://example.com",
                             paramName: "path",
                             paramValue: "/test/path",
                             expected: "https://example.com?path=/test/path",
                             description: "slashes encoded"),

            EncodingTestCase(baseURL: "https://example.com",
                             paramName: "question",
                             paramValue: "what?",
                             expected: "https://example.com?question=what?",
                             description: "question mark encoded"),
        ]

        @Test("URL encoding of special characters", arguments: Advanced.encodingTestCases)
        fileprivate func urlEncodingOfSpecialCharacters(testCase: EncodingTestCase) {
            // Given
            let url = URL(string: testCase.baseURL)!
            let item = URLQueryItem(name: testCase.paramName, value: testCase.paramValue)

            // When
            let result = url.appendingQueryItems([item])

            // Then
            #expect(result.absoluteString == testCase.expected)
        }

        @Test("Query preservation with complex URLs")
        func queryPreservationWithComplexURLs() {
            // Given
            let complexURL = "https://api.example.com:8443/v2/users/123/posts?sort=date&order=desc#comments"
            let url = URL(string: complexURL)!
            let newItems = [
                URLQueryItem(name: "filter", value: "published"),
                URLQueryItem(name: "limit", value: "10"),
            ]

            // When
            let result = url.appendingQueryItems(newItems)

            // Then
            #expect(result
                .absoluteString ==
                "https://api.example.com:8443/v2/users/123/posts?sort=date&order=desc&filter=published&limit=10#comments")
            #expect(result.host == "api.example.com")
            #expect(result.port == 8443)
            #expect(result.path == "/v2/users/123/posts")
            #expect(result.fragment == "comments")
        }

        @Test("Large number of query items performance", .timeLimit(.minutes(1)))
        func largeNumberOfQueryItems() {
            // Given
            let url = URL(string: "https://example.com")!
            let items = (1 ... 1000).map { index in
                URLQueryItem(name: "param\(index)", value: "value\(index)")
            }

            // When
            let result = url.appendingQueryItems(items)

            // Then
            #expect(result.query != nil)
            let components = URLComponents(url: result, resolvingAgainstBaseURL: false)
            #expect(components?.queryItems?.count == 1000)
        }
    }

    // MARK: - Real World Scenarios

    @Suite("Real World Scenarios", .tags(.integration))
    struct RealWorld {
        @Test("API pagination parameters")
        func apiPaginationParameters() {
            // Given
            let baseURL = URL(string: "https://api.example.com/users")!
            let paginationParams = [
                URLQueryItem(name: "page", value: "2"),
                URLQueryItem(name: "per_page", value: "50"),
                URLQueryItem(name: "sort", value: "created_at"),
                URLQueryItem(name: "order", value: "desc"),
            ]

            // When
            let result = baseURL.appendingQueryItems(paginationParams)

            // Then
            #expect(result
                .absoluteString == "https://api.example.com/users?page=2&per_page=50&sort=created_at&order=desc")
        }

        @Test("OAuth redirect URI with state")
        func oauthRedirectURI() {
            // Given
            let redirectURL = URL(string: "https://app.example.com/auth/callback")!
            let oauthParams = [
                URLQueryItem(name: "code", value: "abc123xyz"),
                URLQueryItem(name: "state", value: "random-state-12345"),
                URLQueryItem(name: "scope", value: "read write"),
            ]

            // When
            let result = redirectURL.appendingQueryItems(oauthParams)

            // Then
            #expect(result
                .absoluteString ==
                "https://app.example.com/auth/callback?code=abc123xyz&state=random-state-12345&scope=read%20write")
        }

        @Test("Search with filters")
        func searchWithFilters() {
            // Given
            let searchURL = URL(string: "https://shop.example.com/products")!
            let searchParams = [
                URLQueryItem(name: "q", value: "laptop"),
                URLQueryItem(name: "category", value: "electronics"),
                URLQueryItem(name: "min_price", value: "500"),
                URLQueryItem(name: "max_price", value: "1500"),
                URLQueryItem(name: "in_stock", value: "true"),
            ]

            // When
            let result = searchURL.appendingQueryItems(searchParams)

            // Then
            let expectedURL =
                "https://shop.example.com/products?q=laptop&category=electronics&min_price=500&max_price=1500&in_stock=true"
            #expect(result.absoluteString == expectedURL)
        }

        @Test("Analytics tracking parameters")
        func analyticsTrackingParameters() {
            // Given
            let landingURL = URL(string: "https://example.com/landing")!
            let trackingParams = [
                URLQueryItem(name: "utm_source", value: "newsletter"),
                URLQueryItem(name: "utm_medium", value: "email"),
                URLQueryItem(name: "utm_campaign", value: "spring_sale_2024"),
                URLQueryItem(name: "utm_content", value: "header_cta"),
            ]

            // When
            let result = landingURL.appendingQueryItems(trackingParams)

            // Then
            #expect(result.absoluteString.contains("utm_source=newsletter"))
            #expect(result.absoluteString.contains("utm_medium=email"))
            #expect(result.absoluteString.contains("utm_campaign=spring_sale_2024"))
            #expect(result.absoluteString.contains("utm_content=header_cta"))
        }
    }
}
