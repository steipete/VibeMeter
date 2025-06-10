import Foundation

extension URLRequest {
    /// Creates a URLRequest with standard VibeMeter configuration
    static func vibeMeter(
        url: URL,
        method: String = "GET",
        headers: [String: String] = [:],
        body: Data? = nil) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body

        // Apply headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        return request
    }

    /// Creates a JSON request with Content-Type header set
    static func vibeMeterJSON(
        url: URL,
        method: String = "POST",
        headers: [String: String] = [:],
        body: Data? = nil) -> URLRequest {
        var allHeaders = headers
        allHeaders["Content-Type"] = "application/json"

        return vibeMeter(url: url, method: method, headers: allHeaders, body: body)
    }

    /// Creates a request for web scraping with appropriate headers
    static func vibeMeterWebScraping(url: URL, userAgent: String? = nil) -> URLRequest {
        let headers: [String: String] = [
            "User-Agent": userAgent ??
                "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Safari/605.1.15",
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "en-US,en;q=0.9",
        ]

        return vibeMeter(url: url, headers: headers)
    }
}
