import Foundation
@testable import VibeMeter

// Mock URLSession for testing network requests
@MainActor
public final class MockURLSession: URLSessionProtocol, @unchecked Sendable {
    public var nextData: Data?
    public var nextResponse: URLResponse?
    public var nextError: Error?
    public var lastURL: URL?
    public var lastRequest: URLRequest?
    public var dataTaskCallCount = 0

    public init() {} // Public initializer

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        dataTaskCallCount += 1
        lastURL = request.url
        lastRequest = request

        if let error = nextError {
            throw error
        }

        guard let response = nextResponse else {
            throw NSError(
                domain: "MockURLSessionError",
                code: 1,
                userInfo: [
                    NSLocalizedDescriptionKey:
                        "MockURLSession requires a nextResponse to be set if no error is thrown.",
                ])
        }

        return (nextData ?? Data(), response)
    }
}
