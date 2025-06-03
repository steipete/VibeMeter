import Foundation

extension URL {
    /// Appends query items to the URL.
    /// - Parameter items: Array of URLQueryItem to append
    /// - Returns: URL with appended query items, or original URL if components couldn't be created
    func appendingQueryItems(_ items: [URLQueryItem]) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }
        components.queryItems = (components.queryItems ?? []) + items
        return components.url ?? self
    }
}