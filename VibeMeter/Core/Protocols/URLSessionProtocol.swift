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
/// URLSession conformance to URLSessionProtocol for production use.
///
/// This extension enables the standard URLSession to be used with the protocol,
/// allowing seamless switching between real network requests and test mocks.
extension URLSession: URLSessionProtocol {}
