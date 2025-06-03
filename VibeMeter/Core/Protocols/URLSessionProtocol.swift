import Foundation

/// Protocol abstraction for URLSession to enable testing.
///
/// This protocol allows for dependency injection of URLSession,
/// making it possible to mock network requests in unit tests.
/// The protocol only includes the modern async/await API.
public protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

// Make URLSession conform to the protocol
extension URLSession: URLSessionProtocol {}
