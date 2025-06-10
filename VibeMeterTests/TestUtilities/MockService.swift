import Foundation
import Testing

// MARK: - Base Mock Protocol

/// Base protocol for creating consistent mock services
protocol MockService: Sendable {
    associatedtype CallType: Sendable

    /// Records of all calls made to this mock
    var calls: [CallType] { get set }

    /// Reset the mock to initial state
    mutating func reset()
}

extension MockService {
    /// Default reset implementation
    mutating func reset() {
        calls.removeAll()
    }

    /// Count of calls made
    var callCount: Int {
        calls.count
    }

    /// Check if any calls were made
    var wasCalled: Bool {
        !calls.isEmpty
    }
}

// MARK: - Actor-based Mock Service

/// Actor-based mock service for thread-safe mocking
actor ActorMockService<CallType: Sendable> {
    private var calls: [CallType] = []

    func recordCall(_ call: CallType) {
        calls.append(call)
    }

    func getCalls() -> [CallType] {
        calls
    }

    func getCallCount() -> Int {
        calls.count
    }

    func wasCalled() -> Bool {
        !calls.isEmpty
    }

    func reset() {
        calls.removeAll()
    }
}

// MARK: - Common Call Types

/// Generic method call with parameters
struct MethodCall<Parameters: Sendable>: Sendable {
    let method: String
    let parameters: Parameters
    let timestamp: Date = .init()
}

/// Simple method call without parameters
struct SimpleMethodCall: Sendable {
    let method: String
    let timestamp: Date = .init()
}

// MARK: - Mock Response Builder

/// Builder for configuring mock responses
@MainActor
final class MockResponseBuilder<Response: Sendable> {
    private var responses: [String: Response] = [:]
    private var defaultResponse: Response?
    private var throwableErrors: [String: Error] = [:]

    /// Set response for a specific method
    func setResponse(_ response: Response, for method: String) -> Self {
        responses[method] = response
        return self
    }

    /// Set default response for any method
    func setDefaultResponse(_ response: Response) -> Self {
        defaultResponse = response
        return self
    }

    /// Set error to throw for a specific method
    func setError(_ error: Error, for method: String) -> Self {
        throwableErrors[method] = error
        return self
    }

    /// Get response for method
    func response(for method: String) throws -> Response? {
        if let error = throwableErrors[method] {
            throw error
        }
        return responses[method] ?? defaultResponse
    }

    /// Reset all configurations
    func reset() {
        responses.removeAll()
        defaultResponse = nil
        throwableErrors.removeAll()
    }
}

// MARK: - Verification Helpers

/// Verification helpers for mock assertions
enum MockVerification {
    /// Verify a method was called exactly n times
    static func verify<T: MockService>(
        _ mock: T,
        method: String,
        callCount expectedCount: Int,
        sourceLocation: SourceLocation = #_sourceLocation) where T.CallType == SimpleMethodCall {
        let actualCount = mock.calls.count(where: { $0.method == method })
        #expect(actualCount == expectedCount,
                "Expected \(method) to be called \(expectedCount) times, but was called \(actualCount) times",
                sourceLocation: sourceLocation)
    }

    /// Verify a method was called at least once
    static func verifyWasCalled<T: MockService>(
        _ mock: T,
        method: String,
        sourceLocation: SourceLocation = #_sourceLocation) where T.CallType == SimpleMethodCall {
        let wasCalled = mock.calls.contains { $0.method == method }
        #expect(wasCalled, "\(method) was not called", sourceLocation: sourceLocation)
    }

    /// Verify no calls were made
    static func verifyNoInteractions(
        _ mock: some MockService,
        sourceLocation: SourceLocation = #_sourceLocation) {
        #expect(mock.calls.isEmpty,
                "Expected no interactions, but found \(mock.callCount) calls",
                sourceLocation: sourceLocation)
    }
}

// MARK: - Example Mock Implementation

/// Example mock service implementation
struct MockNetworkService: MockService {
    var calls: [MethodCall<URL>] = []
    private let responseBuilder = MockResponseBuilder<Data>()

    mutating func fetch(from url: URL) async throws -> Data {
        let call = MethodCall(method: "fetch", parameters: url)
        calls.append(call)

        guard let response = try await responseBuilder.response(for: "fetch") else {
            throw URLError(.badServerResponse)
        }
        return response
    }

    @MainActor
    mutating func configureResponse(_ data: Data, for method: String = "fetch") {
        responseBuilder.setResponse(data, for: method)
    }
}

// MARK: - Test Helpers

/// Helper to create type-safe mock expectations
struct MockExpectation<T: Sendable> {
    let value: T
    let matcher: (T) -> Bool

    init(value: T, matcher: @escaping (T) -> Bool = { _ in true }) {
        self.value = value
        self.matcher = matcher
    }
}

/// Protocol for resetable mocks
protocol ResetableMock {
    func reset()
}

/// Reset multiple mocks at once
func resetMocks(_ mocks: ResetableMock...) {
    mocks.forEach { $0.reset() }
}

// MARK: - Usage Example

/*
 Example usage in tests:

 ```swift
 @Test
 func testServiceCallsNetwork() async throws {
     var mockNetwork = MockNetworkService()
     let testData = "test".data(using: .utf8)!
     mockNetwork.configureResponse(testData)

     let service = MyService(network: mockNetwork)
     let result = await service.fetchData()

     MockVerification.verify(&mockNetwork, method: "fetch", callCount: 1)
     #expect(mockNetwork.calls.first?.parameters.absoluteString == "https://example.com")
 }
 ```
 */
